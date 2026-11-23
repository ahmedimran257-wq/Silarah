// Microphone rationale before the system prompt (spec 8), asked only when the
// member starts or answers a call.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/platform_action_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../l10n/ui_copy.dart';
import '../call_platform.dart';

const _rationaleSeenKey = 'silarah_call_mic_rationale_v1';
const _bluetoothAskedKey = 'silarah_call_bluetooth_asked_v1';

/// Why Silarah asks for nearby devices (Android 12+): Bluetooth headsets.
const bluetoothRationaleCopy =
    'Silarah may also ask to find nearby devices, so calls can use your Bluetooth headset. Calls work without it.';

/// True when the microphone may be used for the call.
Future<bool> ensureCallMicrophone(BuildContext context) async {
  final platform = CallPlatform.instance;
  var status = await platform.microphoneStatus();
  if (status == MicrophoneStatus.granted) {
    // Bluetooth headsets need their own permission on Android 12+. Ask for
    // it once, the first time the microphone is already allowed.
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_bluetoothAskedKey) ?? false) && await platform.bluetoothNeeded()) {
      await prefs.setBool(_bluetoothAskedKey, true);
      if (!context.mounted) return true;
      // Why first (spec 12.9); declining never stops the call.
      final proceed = await showSilarahBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _SheetFrame(
          icon: Icons.bluetooth_audio_rounded,
          title: 'Use your Bluetooth headset',
          body: bluetoothRationaleCopy,
          primary: 'Continue',
          onPrimary: () => Navigator.of(sheetContext).pop(true),
          secondary: 'Not now',
          onSecondary: () => Navigator.of(sheetContext).pop(false),
        ),
      );
      if (proceed == true) await platform.requestMicrophone();
    }
    return true;
  }
  if (!context.mounted) return false;
  if (status == MicrophoneStatus.permanentlyDenied) {
    await _showSettingsSheet(context);
    return await platform.microphoneStatus() == MicrophoneStatus.granted;
  }
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(_rationaleSeenKey) ?? false)) {
    if (!context.mounted) return false;
    final proceed = await showSilarahBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _RationaleSheet(),
    );
    if (proceed != true) return false;
    await prefs.setBool(_rationaleSeenKey, true);
  }
  // This request also asks for Bluetooth on Android 12+.
  await prefs.setBool(_bluetoothAskedKey, true);
  status = await platform.requestMicrophone();
  if (status == MicrophoneStatus.granted) return true;
  if (status == MicrophoneStatus.permanentlyDenied && context.mounted) {
    await _showSettingsSheet(context);
  }
  return false;
}

Future<void> _showSettingsSheet(BuildContext context) async {
  await showSilarahBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _SheetFrame(
      icon: Icons.mic_off_rounded,
      title: 'Microphone access is off',
      body: 'Turn on the microphone for Silarah in Settings to make and answer calls.',
      primary: 'Open Settings',
      onPrimary: () async {
        Navigator.of(sheetContext).pop();
        await PlatformActionService.instance.openAppSettings();
      },
    ),
  );
}

class _RationaleSheet extends StatelessWidget {
  const _RationaleSheet();

  @override
  Widget build(BuildContext context) => _SheetFrame(
        icon: Icons.mic_none_rounded,
        title: 'Allow your microphone',
        body:
            'Silarah uses your microphone only during a call you start or answer. Calls are never recorded.',
        note: bluetoothRationaleCopy,
        primary: 'Continue',
        onPrimary: () => Navigator.of(context).pop(true),
        secondary: 'Not now',
        onSecondary: () => Navigator.of(context).pop(false),
      );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.icon,
    required this.title,
    required this.body,
    required this.primary,
    required this.onPrimary,
    this.note,
    this.secondary,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? note;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.goldBorder)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.champagneGold),
          const SizedBox(height: AppDimensions.space16),
          UiText(title, textAlign: TextAlign.center, style: AppTypography.screenTitle),
          const SizedBox(height: AppDimensions.space8),
          UiText(body,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.slateMist)),
          if (note != null) ...[
            const SizedBox(height: AppDimensions.space8),
            UiText(note!,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
          ],
          const SizedBox(height: AppDimensions.space24),
          SilarahPrimaryButton(label: context.uiCopy(primary), onTap: onPrimary),
          if (secondary != null) ...[
            const SizedBox(height: AppDimensions.space8),
            TextButton(
              onPressed: onSecondary,
              child: UiText(secondary!, style: AppTypography.button.copyWith(color: AppColors.slateMist)),
            ),
          ],
        ],
      ),
    );
  }
}
