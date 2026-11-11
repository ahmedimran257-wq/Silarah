// SILARAH - Email Verification Screen
// Supabase email OTP with the existing six-box spring OTP UI.
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/email_address_validation.dart';
import '../../../core/services/legal_consent_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../core/widgets/animations/silarah_motion.dart';
import '../../../core/widgets/inputs/silarah_text_field.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../l10n/generated/app_localizations.dart';

enum EmailAuthMode { signIn, signUp }

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    this.mode = EmailAuthMode.signIn,
  });

  final EmailAuthMode mode;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  late EmailAuthMode _mode;
  bool _otpSent = false;
  int _resendSecs = 60;
  int _otpResetNonce = 0;
  Timer? _resendTimer;

  String get _email => EmailAddressValidation.normalize(_emailCtrl.text);

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _emailCtrl.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_onEmailChanged);
    _emailCtrl.dispose();
    _emailFocus.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _onEmailChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _sendOtp() {
    HapticFeedback.lightImpact();
    final authMode = _mode == EmailAuthMode.signUp ? 'signup' : 'signin';
    context.read<AuthCubit>().sendOtp(_email, mode: authMode);
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSecs > 0) {
          _resendSecs--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _changeEmail() {
    if (_mode == EmailAuthMode.signUp) {
      // A legal acceptance is bound to the first email it is used with, so a
      // different address needs a new acceptance.
      unawaited(LegalConsentService.instance.clearPendingTransaction());
      _showError('To use a different email, please accept the terms again.');
      _returnToLegalAcceptance();
      return;
    }
    setState(() {
      _otpSent = false;
    });
    _resendTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _emailFocus.requestFocus(),
    );
  }

  void _returnToLegalAcceptance() {
    _resendTimer?.cancel();
    context.go(AppRoutes.legal);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: UiText(
          message,
          style: TextStyle(
            color: AppColors.readableOn(AppColors.softCoral),
          ),
        ),
        backgroundColor: AppColors.softCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Creating a profile needs a legal acceptance, which someone arriving from
  /// Sign in has not given yet.
  Future<void> _requestMode(EmailAuthMode mode) async {
    if (mode == EmailAuthMode.signUp) {
      final hasConsent =
          await LegalConsentService.instance.hasPendingOnboardingConsents();
      if (!mounted) return;
      if (!hasConsent) {
        _returnToLegalAcceptance();
        return;
      }
    }
    _switchMode(mode);
  }

  void _switchMode(EmailAuthMode mode, {bool focusEmail = true}) {
    _resendTimer?.cancel();
    setState(() {
      _mode = mode;
      _otpSent = false;
      _otpResetNonce++;
      _resendSecs = 60;
    });
    if (focusEmail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emailFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          setState(() {
            _otpSent = true;
            _resendSecs = 60;
          });
          _emailFocus.unfocus();
          _startResendTimer();
        }
        if (state is AuthUnauthenticated && state.notice != null && _otpSent) {
          _switchMode(_mode, focusEmail: false);
        }
        if (state is AuthError) {
          // Validation and consent messages say nothing about whether an
          // account exists. Every other send failure stays generic.
          final visibleMessage = _otpSent || state.kind != AuthErrorKind.general
              ? state.message
              : 'We could not send a verification code. Check the address or try again shortly.';
          if (_otpSent) {
            setState(() => _otpResetNonce++);
          }
          _showError(visibleMessage);
          if (state.kind == AuthErrorKind.legalConsentRequired) {
            _returnToLegalAcceptance();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _QuietAuthCanvas(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _BackBtn(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: SilarahContentSwap(
                    child: _otpSent
                        ? _OtpView(
                            key: const ValueKey('otp'),
                            email: _email,
                            resendSecs: _resendSecs,
                            resetNonce: _otpResetNonce,
                            onResend: _resendSecs == 0
                                ? () => context.read<AuthCubit>().resendOtp()
                                : null,
                            onChangeEmail: _changeEmail,
                          )
                        : _EmailView(
                            key: const ValueKey('email'),
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            mode: _mode,
                            onModeChanged: _requestMode,
                            onSend: _sendOtp,
                            isComplete: true,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietAuthCanvas extends StatelessWidget {
  const _QuietAuthCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // Opaque, so whatever sits behind the route cannot show through.
            Color.alphaBlend(
              AppColors.midnightPlum.withValues(alpha: .34),
              AppColors.obsidianNight,
            ),
            AppColors.obsidianNight,
            AppColors.obsidianNight,
          ],
          stops: const [0, .24, 1],
        ),
      ),
      child: CustomPaint(
        painter: _AuthBotanicalEdgePainter(
          color: AppColors.champagneGold,
        ),
        child: child,
      ),
    );
  }
}

class _AuthBotanicalEdgePainter extends CustomPainter {
  const _AuthBotanicalEdgePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = .75
      ..color = color.withValues(alpha: .075);

    final upperStem = Path()
      ..moveTo(size.width + 18, 34)
      ..cubicTo(
        size.width * .88,
        54,
        size.width * .90,
        142,
        size.width * .76,
        176,
      );
    final lowerStem = Path()
      ..moveTo(-18, size.height - 18)
      ..cubicTo(
        size.width * .10,
        size.height - 60,
        size.width * .08,
        size.height - 132,
        size.width * .20,
        size.height - 170,
      );
    canvas
      ..drawPath(upperStem, paint)
      ..drawPath(lowerStem, paint);

    _leaf(canvas, Offset(size.width * .90, 92), -2.35, paint);
    _leaf(canvas, Offset(size.width * .84, 145), -2.55, paint);
    _leaf(canvas, Offset(size.width * .10, size.height - 85), .55, paint);
  }

  void _leaf(Canvas canvas, Offset center, double angle, Paint paint) {
    canvas.save();
    canvas
      ..translate(center.dx, center.dy)
      ..rotate(angle);
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(11, -7, 20, 0)
      ..quadraticBezierTo(11, 7, 0, 0);
    canvas.drawPath(leaf, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuthBotanicalEdgePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _EmailView extends StatelessWidget {
  const _EmailView({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.mode,
    required this.onModeChanged,
    required this.onSend,
    required this.isComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final EmailAuthMode mode;
  final ValueChanged<EmailAuthMode> onModeChanged;
  final VoidCallback onSend;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final isSignIn = mode == EmailAuthMode.signIn;
    final title = isSignIn ? 'Welcome back' : 'Create your Silarah profile';
    final subtitle = isSignIn
        ? 'Enter your email and we will send a 6-digit verification code.'
        : 'Use your real email. We will send a 6-digit verification code.';
    final ctaLabel = isSignIn ? 'Send sign-in code' : 'Send verification code';
    final switchLabel = isSignIn
        ? 'New to Silarah? Create profile'
        : 'Already registered? Sign in';
    final nextMode = isSignIn ? EmailAuthMode.signUp : EmailAuthMode.signIn;

    return _KeyboardSafeScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SilarahEntrance(
                  child: SilarahContentSwap(
                    child: UiText(
                      title,
                      key: ValueKey('email-title-$title'),
                      style: AppTypography.screenTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SilarahEntrance(
                  delay: const Duration(milliseconds: 45),
                  child: SilarahContentSwap(
                    child: UiText(
                      subtitle,
                      key: ValueKey('email-subtitle-$subtitle'),
                      style: AppTypography.bodyMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SilarahEntrance(
              delay: const Duration(milliseconds: 90),
              child: _EmailInput(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: isComplete ? onSend : null,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: SilarahEntrance(
              delay: const Duration(milliseconds: 140),
              child: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SilarahPrimaryButton(
                      label: ctaLabel,
                      isLoading: state is AuthLoading,
                      enabled: isComplete,
                      haptic: false,
                      onTap:
                          isComplete && state is! AuthLoading ? onSend : null,
                    ),
                    const SizedBox(height: 14),
                    SilarahPressable(
                      onTap: () => onModeChanged(nextMode),
                      enabled: state is! AuthLoading,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: UiText(
                                switchLabel,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.fade,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.champagneGold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.space6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: AppColors.champagneGold,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyboardSafeScroll extends StatelessWidget {
  const _KeyboardSafeScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}

class _EmailInput extends StatelessWidget {
  const _EmailInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SilarahTextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      onSubmitted: (_) => onSubmitted?.call(),
      hint: 'name@example.com',
      semanticLabel: l10n.settings_label_email,
      prefixIcon: Icons.alternate_email_rounded,
    );
  }
}

class _OtpView extends StatefulWidget {
  const _OtpView({
    super.key,
    required this.email,
    required this.resendSecs,
    required this.resetNonce,
    required this.onResend,
    required this.onChangeEmail,
  });

  final String email;
  final int resendSecs;
  final int resetNonce;
  final VoidCallback? onResend;
  final VoidCallback onChangeEmail;

  @override
  State<_OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<_OtpView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _titleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(_titleFade);
    _subtitleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 0.8, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _KeyboardSafeScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleFade,
                    child: UiText(
                      l10n.auth_title_enterCode,
                      style: AppTypography.screenTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: _subtitleFade,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: l10n.auth_label_sentCodeTo,
                          style: AppTypography.bodyMuted,
                        ),
                        TextSpan(
                          text: widget.email,
                          style: AppTypography.bodyMuted.copyWith(
                            color: AppColors.champagneGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _OtpBoxes(
            resetNonce: widget.resetNonce,
            onCompleted: (code) {
              HapticFeedback.mediumImpact();
              context.read<AuthCubit>().verifyOtp(code);
            },
          ),
          const SizedBox(height: 36),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              if (state is! AuthLoading) return const SizedBox.shrink();
              return const SilarahPulseLoader(size: 28);
            },
          ),
          const SizedBox(height: 20),
          SilarahPressable(
            onTap: widget.onResend,
            enabled: widget.onResend != null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: UiText(
                  key: ValueKey(widget.resendSecs == 0 ? 'active' : 'waiting'),
                  widget.resendSecs > 0
                      ? l10n.auth_label_resendCodeIn(widget.resendSecs)
                      : l10n.auth_label_resendCode,
                  style: AppTypography.bodyMuted.copyWith(
                    color: widget.resendSecs == 0
                        ? AppColors.champagneGold
                        : AppColors.slateMist,
                    fontWeight: widget.resendSecs == 0
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: UiText(
              'No code yet? Check your Spam or Junk folder.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.slateMist,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SilarahPressable(
            onTap: widget.onChangeEmail,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              child: UiText(
                context.uiCopy('Change email'),
                style: AppTypography.caption.copyWith(
                  color: AppColors.slateMist,
                  decoration: TextDecoration.none,
                  decorationColor: AppColors.slateMist,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({
    required this.resetNonce,
    required this.onCompleted,
  });

  final int resetNonce;
  final ValueChanged<String> onCompleted;

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> with WidgetsBindingObserver {
  static const _length = 6;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _otp = '';
  bool _completionSubmitted = false;
  Timer? _keyboardTimer;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onInput);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openKeyboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardTimer?.cancel();
    _completionTimer?.cancel();
    _controller.removeListener(_onInput);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _OtpBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetNonce != oldWidget.resetNonce) {
      _completionSubmitted = false;
      _controller.clear();
      if (mounted) setState(() => _otp = '');
      _openKeyboard(reconnect: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Android can resume with the FocusNode still focused but with its text
      // input connection closed after the user checks OTP in another app.
      _openKeyboard(reconnect: true);
    }
  }

  void _openKeyboard({bool reconnect = false}) {
    if (!mounted) return;
    if (reconnect) {
      _focusNode.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }

    _keyboardTimer?.cancel();
    _keyboardTimer = Timer(Duration(milliseconds: reconnect ? 90 : 0), () {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_focusNode);
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _onInput() {
    final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
    final clamped =
        digits.length > _length ? digits.substring(0, _length) : digits;

    if (clamped == _otp) return;

    final prev = _otp;
    if (clamped.length < _length) {
      _completionSubmitted = false;
    }
    setState(() => _otp = clamped);

    if (clamped.length > prev.length) {
      HapticFeedback.lightImpact();
    }

    if (_controller.text != clamped) {
      _controller.value = TextEditingValue(
        text: clamped,
        selection: TextSelection.collapsed(offset: clamped.length),
      );
    }

    if (clamped.length == _length && !_completionSubmitted) {
      _completionSubmitted = true;
      _completionTimer?.cancel();
      _completionTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) widget.onCompleted(clamped);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openKeyboard(reconnect: true),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            // Six fixed boxes are wider than the smallest phones allow.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_length, (i) {
                  final hasDigit = i < _otp.length;
                  final isActive = i == _otp.length;
                  return Padding(
                    padding: EdgeInsets.only(right: i < _length - 1 ? 10 : 0),
                    child: _OtpBox(
                      digit: hasDigit ? _otp[i] : null,
                      isActive: isActive,
                      delay: i * 50,
                    ),
                  );
                }),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.01,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: false,
                showCursor: false,
                onTapOutside: (_) => _focusNode.unfocus(),
                maxLength: _length,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_length),
                ],
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                  height: 1,
                ),
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.digit,
    required this.isActive,
    this.delay = 0,
  });

  final String? digit;
  final bool isActive;
  final int delay;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryScale;
  late final Animation<double> _entryFade;
  AnimationController? _digitUpdateCtrl;
  Animation<double>? _digitUpdateScale;
  Animation<double>? _digitUpdateFade;
  Timer? _entryTimer;
  String? _prevDigit;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _entryScale = Tween<double>(begin: .975, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: AppCurves.reveal),
    );
    _entryFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _entryTimer = Timer(Duration(milliseconds: 50 + widget.delay), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _OtpBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.digit != null && widget.digit != _prevDigit) {
      _animateDigitUpdate();
    }
    _prevDigit = widget.digit;
  }

  void _animateDigitUpdate() {
    _digitUpdateCtrl?.dispose();
    _digitUpdateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _digitUpdateScale = Tween<double>(begin: .96, end: 1.0).animate(
      CurvedAnimation(parent: _digitUpdateCtrl!, curve: AppCurves.tactile),
    );
    _digitUpdateFade = CurvedAnimation(
      parent: _digitUpdateCtrl!,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _digitUpdateCtrl!.forward();
  }

  @override
  void dispose() {
    _entryTimer?.cancel();
    _entryCtrl.dispose();
    _digitUpdateCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDigit = widget.digit != null;
    final Widget digitWidget;
    if (hasDigit && _digitUpdateScale != null && _digitUpdateFade != null) {
      digitWidget = ScaleTransition(
        scale: _digitUpdateScale!,
        child: FadeTransition(
          opacity: _digitUpdateFade!,
          child: _DigitText(widget.digit!),
        ),
      );
    } else if (hasDigit) {
      digitWidget = _DigitText(widget.digit!);
    } else if (widget.isActive) {
      digitWidget = const _Cursor();
    } else {
      digitWidget = const SizedBox.shrink();
    }

    return ScaleTransition(
      scale: _entryScale,
      child: FadeTransition(
        opacity: _entryFade,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 58,
          decoration: BoxDecoration(
            color: hasDigit
                ? AppColors.champagneGold.withValues(alpha: 0.08)
                : AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.champagneGold
                  : hasDigit
                      ? AppColors.champagneGold.withValues(alpha: 0.45)
                      : AppColors.cardBorder,
              width: widget.isActive ? 2.0 : 1.5,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: AppColors.champagneGold.withValues(alpha: 0.12),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Center(child: digitWidget),
        ),
      ),
    );
  }
}

class _DigitText extends StatelessWidget {
  const _DigitText(this.digit);

  final String digit;

  @override
  Widget build(BuildContext context) {
    return UiText(
      digit,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.pearlWhite,
        letterSpacing: 0,
      ),
    );
  }
}

class _Cursor extends StatefulWidget {
  const _Cursor();

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.champagneGold,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  const _BackBtn({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_new_rounded,
          color: AppColors.pearlWhite,
          size: 16,
        ),
      ),
    );
  }
}
