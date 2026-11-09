import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/wali_mode_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../core/widgets/buttons/silarah_secondary_button.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../l10n/ui_copy.dart';

class GuardianConnectScreen extends StatefulWidget {
  const GuardianConnectScreen({super.key});

  @override
  State<GuardianConnectScreen> createState() => _GuardianConnectScreenState();
}

class _GuardianConnectScreenState extends State<GuardianConnectScreen> {
  static const _guardianCodeExample = 'A1B2C3D4E5';
  final _codeController = TextEditingController();
  bool _loading = true;
  bool _invitationAccepted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _restoreCode() async {
    final code = await WaliModeService.instance.pendingInvitation();
    if (!mounted) return;
    setState(() {
      _codeController.text = code ?? '';
      _loading = false;
    });
  }

  String? _validatedCode() {
    final code = _codeController.text.trim().toUpperCase();
    if (!RegExp(r'^[A-F0-9]{10}$').hasMatch(code)) {
      setState(() {
        _error = 'Enter the complete 10-character Guardian invitation code.';
      });
      return null;
    }
    return code;
  }

  Future<void> _continueToAuth({required bool signup}) async {
    final code = _validatedCode();
    if (code == null) return;
    await WaliModeService.instance.rememberPendingInvitation(code);
    if (!mounted) return;
    context.push(
      signup ? AppRoutes.legal : '${AppRoutes.email}?mode=signin',
    );
  }

  Future<void> _acceptInvitation() async {
    final code = _validatedCode();
    if (code == null || _loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await WaliModeService.instance.rememberPendingInvitation(code);
      await WaliModeService.instance.acceptInvitation(code);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().contains('guardian_email_mismatch')
            ? 'Sign in with the verified email address selected by the member.'
            : 'The invitation could not be accepted. Confirm the code, email account, and expiry date.';
      });
      return;
    }
    _invitationAccepted = true;
    await _finishAcceptedInvitation();
  }

  /// The code works once, so after a successful accept only the account
  /// refresh may be retried; accepting again would report a false failure.
  Future<void> _finishAcceptedInvitation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await WaliModeService.instance.clearPendingInvitation();
      if (!mounted) return;
      await context.read<AuthCubit>().refreshAuthenticatedProfile();
      if (!mounted) return;
      context.go(AppRoutes.guardianDashboard);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Your invitation was accepted, but we could not refresh your account. Check your connection and try again.';
      });
    }
  }

  Future<void> _continueWithoutGuardian() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await WaliModeService.instance.clearPendingInvitation();
      if (!mounted) return;
      await context.read<AuthCubit>().refreshAuthenticatedProfile();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'We could not refresh your account. Check your connection and try again.';
      });
      return;
    }
    if (!mounted) return;
    final auth = context.read<AuthCubit>().state;
    if (auth is AuthAuthenticated && auth.isOnboardingComplete) {
      context.go(AppRoutes.home);
    } else if (auth is AuthAuthenticated) {
      context.go(onboardingPathForStep(auth.onboardingStep));
    } else {
      context.go(AppRoutes.splash);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final authenticated = auth is AuthAuthenticated;
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.uiCopy('Back'),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(authenticated ? AppRoutes.home : AppRoutes.splash),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.pearlWhite,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.space24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceGlass,
                      border: Border.all(color: AppColors.champagneGold),
                    ),
                    child: Icon(
                      Icons.family_restroom_rounded,
                      color: AppColors.champagneGold,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 24),
                  UiText(
                    context.uiCopy('Connect as a Guardian'),
                    style: AppTypography.screenTitle,
                  ),
                  const SizedBox(height: 10),
                  UiText(
                    context.uiCopy(
                      'Enter the private code shared by the member. You must be signed in with the verified email address selected for this invitation.',
                    ),
                    style: AppTypography.bodyMuted,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    enabled: !_loading,
                    maxLength: 10,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Fa-f0-9]')),
                      UpperCaseTextFormatter(),
                    ],
                    style: AppTypography.userName.copyWith(letterSpacing: 3),
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: context.uiCopy('Guardian invitation code'),
                      hintText: _guardianCodeExample,
                      errorText:
                          _error == null ? null : context.uiCopy(_error!),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: 22),
                  if (_loading)
                    const Center(child: SilarahPulseLoader(size: 30))
                  else if (_invitationAccepted)
                    SilarahPrimaryButton(
                      label: context.uiCopy('Try again'),
                      onTap: _finishAcceptedInvitation,
                    )
                  else if (authenticated)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SilarahPrimaryButton(
                          label: context.uiCopy('Accept invitation'),
                          onTap: _acceptInvitation,
                        ),
                        const SizedBox(height: 12),
                        SilarahSecondaryButton(
                          label: context.uiCopy('Continue without Guardian'),
                          onTap: _continueWithoutGuardian,
                        ),
                      ],
                    )
                  else ...[
                    SilarahPrimaryButton(
                      label: context.uiCopy('Create Guardian account'),
                      onTap: () => _continueToAuth(signup: true),
                    ),
                    const SizedBox(height: 12),
                    SilarahSecondaryButton(
                      label: context.uiCopy('Sign in to accept'),
                      onTap: () => _continueToAuth(signup: false),
                    ),
                  ],
                  const SizedBox(height: 20),
                  UiText(
                    context.uiCopy(
                      'The code expires after 7 days and works once. It can only be accepted by the invited verified email account.',
                    ),
                    textAlign: TextAlign.center,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
