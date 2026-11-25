// Settings > Calls: Ring / Silent / Calls off (each says exactly what
// happens, and what a caller sees), missed-call notifications, call minutes,
// "How calling works", and the two Android helpers (lock-screen calls on
// Android 14+, auto-start on some phone makers). Hidden while calling is
// switched off on the server (CallsHub, the one gate).

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/notification_prefs/notification_prefs_cubit.dart';
import '../../../core/cubits/notification_prefs/notification_prefs_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/ui_copy.dart';
import '../call_api.dart';
import '../call_platform.dart';
import '../calling_rules.dart';
import '../calls_hub.dart';
import 'call_minutes_sheet.dart';
import 'calling_guide_sheet.dart';

class CallSettingsSection extends StatefulWidget {
  const CallSettingsSection({super.key});

  @override
  State<CallSettingsSection> createState() => _CallSettingsSectionState();
}

class _CallSettingsSectionState extends State<CallSettingsSection> with WidgetsBindingObserver {
  String? _mode;
  bool _enabled = false;
  bool _fullScreenAllowed = true;
  bool _autoStartTip = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Android settings: show the new lock-screen choice.
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await CallApi.instance.preferences();
    final fullScreen = await CallPlatform.instance.canUseFullScreenIntent();
    final maker = await CallPlatform.instance.manufacturer();
    if (!mounted) return;
    setState(() {
      _enabled = prefs?.enabled ?? false;
      _mode = prefs?.mode;
      _fullScreenAllowed = fullScreen;
      _autoStartTip = needsAutoStartTip(maker);
    });
  }

  Future<void> _setMode(String mode) async {
    final previous = _mode;
    setState(() {
      _mode = mode;
      _saving = true;
    });
    final ok = await CallApi.instance.setMode(mode);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _mode = previous;
    });
    if (!ok) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: UiText('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CallingRules?>(
      valueListenable: CallsHub.instance.rules,
      builder: (context, rules, _) => rules?.callsEnabled == true && _enabled && _mode != null
          ? _section(context)
          : const SizedBox.shrink(),
    );
  }

  Widget _section(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 28, 0, 10),
          child: UiText('CALLS',
              style: AppTypography.sectionLabel.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.7)),
        ),
        Material(
          color: AppColors.surfaceElevated,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppColors.cardBorder.withValues(alpha: .72)),
          ),
          child: Column(
            children: [
              for (final option in const [
                ('ring', 'Ring', 'Calls from your matches ring this phone.'),
                ('silent', 'Silent',
                    'No ring. Calls show as missed, and callers see that you are not taking calls right now.'),
                ('off', 'Calls off',
                    'Nobody can call you or plan a call with you. Callers see that you are not taking calls right now.'),
              ])
                RadioListTile<String>(
                  value: option.$1,
                  // ignore: deprecated_member_use
                  groupValue: _mode,
                  activeColor: AppColors.champagneGold,
                  // ignore: deprecated_member_use
                  onChanged: _saving ? null : (value) => _setMode(value!),
                  title: UiText(option.$2, style: AppTypography.body),
                  subtitle: UiText(option.$3,
                      style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
                ),
              Divider(color: AppColors.divider, height: 1),
              // Calls follow the member's quiet hours (Settings > Notifications);
              // callers are told it is quiet hours and when calls ring again.
              BlocBuilder<NotificationPrefsCubit, NotificationPrefsState>(
                buildWhen: (a, b) =>
                    a.quietStartHour != b.quietStartHour || a.quietEndHour != b.quietEndHour,
                builder: (context, prefs) {
                  final labels = MaterialLocalizations.of(context);
                  final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
                  String at(int hour) =>
                      labels.formatTimeOfDay(TimeOfDay(hour: hour % 24, minute: 0), alwaysUse24HourFormat: h24);
                  return ListTile(
                    leading: Icon(Icons.bedtime_outlined, color: AppColors.champagneGold),
                    title: UiText('Quiet hours', style: AppTypography.body),
                    subtitle: UiText.verbatim(
                      context.uiCopyWith(
                        "Calls don't ring from {start} to {end}. Callers are told it's your quiet hours and when calls ring again.",
                        {'start': at(prefs.quietStartHour), 'end': at(prefs.quietEndHour)},
                      ),
                      style: AppTypography.caption.copyWith(color: AppColors.slateMist),
                    ),
                  );
                },
              ),
              Divider(color: AppColors.divider, height: 1),
              BlocBuilder<NotificationPrefsCubit, NotificationPrefsState>(
                buildWhen: (a, b) => a.missedCall != b.missedCall,
                builder: (context, prefs) => SwitchListTile.adaptive(
                  value: prefs.missedCall,
                  activeTrackColor: AppColors.champagneGold,
                  onChanged: context.read<NotificationPrefsCubit>().toggleMissedCall,
                  secondary: Icon(Icons.phone_missed_outlined, color: AppColors.champagneGold),
                  title: UiText('Missed-call notifications', style: AppTypography.body),
                  subtitle: UiText('Missed calls always show in your Calls tab.',
                      style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
                ),
              ),
              Divider(color: AppColors.divider, height: 1),
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: AppColors.champagneGold),
                title: UiText('How calling works', style: AppTypography.body),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.slateMist),
                onTap: () => unawaited(showCallingGuide(context)),
              ),
              Divider(color: AppColors.divider, height: 1),
              ListTile(
                leading: Icon(Icons.timer_outlined, color: AppColors.champagneGold),
                title: UiText('Call minutes', style: AppTypography.body),
                subtitle: UiText('Included minutes and minute packs',
                    style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.slateMist),
                onTap: () => showCallMinutesSheet(context),
              ),
              if (!_fullScreenAllowed) ...[
                Divider(color: AppColors.divider, height: 1),
                ListTile(
                  leading: Icon(Icons.screen_lock_portrait_outlined, color: AppColors.expiryAmber),
                  title: UiText('Show incoming calls on the lock screen', style: AppTypography.body),
                  subtitle: UiText('Allow full-screen calls for Silarah in Android settings.',
                      style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
                  onTap: CallPlatform.instance.openFullScreenIntentSettings,
                ),
              ],
              if (_autoStartTip) ...[
                Divider(color: AppColors.divider, height: 1),
                ListTile(
                  leading: Icon(Icons.battery_saver_outlined, color: AppColors.slateMist),
                  title: UiText('Make sure calls can ring', style: AppTypography.body),
                  subtitle: UiText(
                      'On some phones, allow Silarah to start automatically so calls ring when the app is closed.',
                      style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
                  onTap: CallPlatform.instance.openAutoStartSettings,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
