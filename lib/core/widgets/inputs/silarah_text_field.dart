// SILARAH Input System
// Single-shell glass fields with animated focus, no nested theme outline.
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import 'silarah_field_frame.dart';

class SilarahTextField extends StatefulWidget {
  const SilarahTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.semanticLabel,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.showCounter = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? semanticLabel;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool showCounter;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  State<SilarahTextField> createState() => _SilarahTextFieldState();
}

class _SilarahTextFieldState extends State<SilarahTextField> {
  FocusNode? _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _focusNode.addListener(_handleFocusChange);
    _isFocused = _focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant SilarahTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;

    (oldWidget.focusNode ?? _internalFocusNode)
        ?.removeListener(_handleFocusChange);

    if (oldWidget.focusNode == null && widget.focusNode != null) {
      _internalFocusNode?.dispose();
      _internalFocusNode = null;
    } else if (oldWidget.focusNode != null && widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }

    _focusNode.addListener(_handleFocusChange);
    _isFocused = _focusNode.hasFocus;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    final focused = _focusNode.hasFocus;
    if (focused && !_isFocused) {
      HapticFeedback.selectionClick();
    }
    setState(() => _isFocused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final isInteractive = widget.enabled && !widget.readOnly;
    final isActive = widget.enabled && _isFocused;
    final minHeight = widget.maxLines != null && widget.maxLines! > 1
        ? AppDimensions.inputHeight + AppDimensions.space40
        : AppDimensions.inputHeight;

    final supportText = hasError ? widget.errorText : widget.helperText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SilarahFieldFrame(
          focused: isActive,
          enabled: widget.enabled,
          hasError: hasError,
          minHeight: minHeight,
          child: Semantics(
            textField: true,
            label: (widget.semanticLabel ?? widget.label ?? widget.hint) == null
                ? null
                : context.uiCopy(
                    (widget.semanticLabel ?? widget.label ?? widget.hint)!,
                  ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              onTap: widget.onTap,
              onTapOutside: (_) => _focusNode.unfocus(),
              maxLength: widget.maxLength,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              autofocus: widget.autofocus,
              inputFormatters: widget.inputFormatters,
              textCapitalization: widget.textCapitalization,
              autocorrect: widget.autocorrect,
              enableSuggestions: widget.enableSuggestions,
              keyboardAppearance: Brightness.dark,
              style: AppTypography.inputText.copyWith(
                color: widget.enabled
                    ? AppColors.pearlWhite
                    : AppColors.pearlWhite.withValues(alpha: 0.42),
              ),
              cursorColor: AppColors.champagneGold,
              cursorWidth: 1.5,
              buildCounter: widget.showCounter
                  ? null
                  : (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
              decoration: InputDecoration(
                hintText: (widget.hint ?? widget.label) == null
                    ? null
                    : context.uiCopy((widget.hint ?? widget.label)!),
                hintStyle: AppTypography.inputLabel.copyWith(
                  color: AppColors.slateMist.withValues(
                    alpha: isInteractive ? 0.78 : 0.42,
                  ),
                ),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                prefixIcon: widget.prefixIcon != null
                    ? Icon(
                        widget.prefixIcon,
                        color: isActive
                            ? AppColors.champagneGold
                            : AppColors.slateMist,
                        size: AppDimensions.iconSizeMedium,
                      )
                    : null,
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: AppDimensions.inputHeight,
                ),
                suffixIcon: widget.suffixIcon,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: widget.prefixIcon == null
                      ? AppDimensions.space16
                      : AppDimensions.space8,
                  vertical: widget.maxLines != null && widget.maxLines! > 1
                      ? AppDimensions.space16
                      : 18.0,
                ),
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
              ? Duration.zero
              : AppDimensions.durationTransition,
          child: supportText == null || supportText.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  key:
                      ValueKey('${hasError ? 'error' : 'helper'}:$supportText'),
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDimensions.space4,
                    top: AppDimensions.space6,
                  ),
                  child: UiText(
                    supportText,
                    style: AppTypography.caption.copyWith(
                      color:
                          hasError ? AppColors.softCoral : AppColors.slateMist,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// OTP Input Field
// Six individual boxes with auto-advance.
class SilarahOtpField extends StatefulWidget {
  const SilarahOtpField({
    super.key,
    required this.onCompleted,
    this.length = 6,
    this.onChanged,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<SilarahOtpField> createState() => _SilarahOtpFieldState();
}

class _SilarahOtpFieldState extends State<SilarahOtpField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<FocusNode> _keyboardFocusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _keyboardFocusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyboardFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitEntered(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < widget.length && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      if (digits.length >= widget.length) {
        FocusScope.of(context).unfocus();
        _notifyCompletion();
      } else {
        _focusNodes[digits.length.clamp(0, widget.length - 1)].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty) {
      HapticFeedback.selectionClick();
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
        _notifyCompletion();
      }
    }
    widget.onChanged?.call(_buildOtpString());
  }

  void _onKeyPressed(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  void _notifyCompletion() {
    final otp = _buildOtpString();
    if (otp.length == widget.length) {
      widget.onCompleted(otp);
    }
  }

  String _buildOtpString() => _controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: 44,
          child: KeyboardListener(
            focusNode: _keyboardFocusNodes[index],
            onKeyEvent: (event) => _onKeyPressed(index, event),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              onTapOutside: (_) => _focusNodes[index].unfocus(),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              style: AppTypography.userName.copyWith(
                color: AppColors.champagneGold,
              ),
              cursorColor: AppColors.champagneGold,
              onChanged: (v) => _onDigitEntered(index, v),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: ' ',
                filled: true,
                fillColor: AppColors.surfacePanelTop.withValues(alpha: 0.56),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  borderSide: BorderSide(
                    color: AppColors.cardBorder,
                    width: AppDimensions.borderThin,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  borderSide: BorderSide(
                    color: AppColors.champagneGold,
                    width: AppDimensions.borderThin,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
