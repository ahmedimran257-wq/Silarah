// SILARAH — Settings Screen
// Sections:
//   1. ACCOUNT   — identity and photo privacy
//   2. NOTIFICATIONS — per-category toggles
//   3. GUARDIAN  — wali and guardian details
//   4. PRIVACY   — profile and photo visibility
//   5. APP       — language and version
//   6. SAFETY    — block list, report history
//   7. LEGAL     — ToS, Privacy Policy
//   8. DANGER ZONE — account deletion
import 'dart:async';

import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../l10n/generated/app_localizations.dart';

import '../../../core/cubits/locale/locale_cubit.dart';
import '../../../core/cubits/theme/theme_cubit.dart';
import '../../../core/cubits/notification_prefs/notification_prefs_cubit.dart';
import '../../../core/cubits/notification_prefs/notification_prefs_state.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/block_report/block_report_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../core/widgets/overlays/silarah_dialog.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/account_standing/account_standing_cubit.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/cubits/subscription/subscription_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/services/personal_data_export_service.dart';
import '../../../core/services/incognito_service.dart';
import '../../../core/services/my_account_snapshot.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/wali_mode_service.dart';
import '../../../core/legal/legal_documents.dart';
import 'legal_doc_screen.dart';
import 'privacy_requests_screen.dart';
import 'subscription_screen.dart';

const _kLanguages = LocaleCubit.supportedLanguages;

String _themeLabel(AppLocalizations l10n, SilarahThemeMode mode) =>
    switch (mode) {
      SilarahThemeMode.oled => l10n.settings_theme_oled,
      SilarahThemeMode.ivoryEmerald => l10n.settings_theme_ivory,
      SilarahThemeMode.roseMarigold => l10n.settings_theme_rose,
    };

String _themeDescription(AppLocalizations l10n, SilarahThemeMode mode) =>
    switch (mode) {
      SilarahThemeMode.oled => l10n.settings_theme_oledDesc,
      SilarahThemeMode.ivoryEmerald => l10n.settings_theme_ivoryDesc,
      SilarahThemeMode.roseMarigold => l10n.settings_theme_roseDesc,
    };

// Guardian prefs keys
const _kGuardianEmailHelp =
    'Only this verified email account can accept the one-time invitation.';

// Privacy prefs keys
const _kPhotoVisibility = 'privacy_photo_visibility';
const _kProfilePaused = 'privacy_profile_paused';

IconData _legalIcon(String slug) => switch (slug) {
      'terms' => Icons.description_outlined,
      'privacy' => Icons.privacy_tip_outlined,
      'community-guidelines' => Icons.groups_2_outlined,
      'child-safety' => Icons.child_care_outlined,
      'refund-policy' => Icons.receipt_long_outlined,
      'data-deletion' => Icons.delete_sweep_outlined,
      'privacy-rights' => Icons.manage_accounts_outlined,
      'verification-policy' => Icons.badge_outlined,
      'photo-moderation-policy' => Icons.photo_filter_outlined,
      'guardian-policy' => Icons.family_restroom_outlined,
      _ => Icons.policy_outlined,
    };

// MAIN SCREEN

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.initialSection});

  /// Optional section to scroll to on open.
  final String? initialSection;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _privacyKey = GlobalKey();
  final _helpKey = GlobalKey();
  final _accountKey = GlobalKey();
  final _notificationsKey = GlobalKey();
  final _guardianKey = GlobalKey();
  String _appVersion = '—';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    // The Safety rows show blocked and reported counts. Without this they
    // read "None" after a restart until the block list screen was opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<BlockReportCubit>().loadData());
    });
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection());
    }
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version} (${info.buildNumber})');
    }
  }

  void _scrollToSection() {
    GlobalKey? key;
    switch (widget.initialSection) {
      case 'privacy':
        key = _privacyKey;
      case 'help':
        key = _helpKey;
      case 'account':
        key = _accountKey;
      case 'notifications':
        key = _notificationsKey;
      case 'guardian':
        key = _guardianKey;
    }
    if (key?.currentContext != null) {
      _scrollToKey(key!);
    }
  }

  void _scrollToKey(GlobalKey key) {
    if (key.currentContext == null) return;
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: l10n.common_button_back,
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.pearlWhite, size: 20),
        ),
        title: UiText(l10n.settings_title,
            style: AppTypography.screenTitle.copyWith(fontSize: 20)),
      ),
      // This is a bounded, static settings document. Building its sections
      // together keeps GlobalKey-based deep links (Help, Privacy, Guardian)
      // reliable; a lazy ListView can leave the requested off-screen section
      // without a BuildContext when the first-frame jump runs.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. ACCOUNT
            _SectionHeader(l10n.settings_section_account, key: _accountKey),
            _SettingsCard(children: [
              Builder(
                builder: (ctx) {
                  final data = ctx.read<OnboardingCubit>().currentData;
                  final email = data.email ??
                      (SupabaseService.isInitialized
                          ? SupabaseService.client.auth.currentUser?.email
                          : null);
                  return _InfoTile(
                    icon: Icons.alternate_email_rounded,
                    label: l10n.settings_label_email,
                    value: _maskEmail(email),
                  );
                },
              ),
            ]),

            // 2. NOTIFICATIONS
            _SectionHeader(l10n.settings_section_notifications,
                key: _notificationsKey),
            BlocConsumer<NotificationPrefsCubit, NotificationPrefsState>(
              listenWhen: (previous, current) =>
                  previous.syncEvent != current.syncEvent &&
                  current.syncError != null,
              listener: (context, prefs) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: UiText(prefs.syncError!)),
                );
              },
              builder: (context, prefs) => _SettingsCard(children: [
                _ToggleTile(
                  icon: Icons.favorite_outline_rounded,
                  label: l10n.settings_notify_newInterest,
                  value: prefs.newInterest,
                  onChanged: (v) => context
                      .read<NotificationPrefsCubit>()
                      .toggleNewInterest(v),
                ),
                _Divider(),
                _ToggleTile(
                  icon: Icons.check_circle_outline_rounded,
                  label: l10n.settings_notify_interestAccepted,
                  value: prefs.interestAccepted,
                  onChanged: (v) => context
                      .read<NotificationPrefsCubit>()
                      .toggleInterestAccepted(v),
                ),
                _Divider(),
                _ToggleTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: l10n.settings_notify_newMessage,
                  value: prefs.newMessage,
                  onChanged: (v) => context
                      .read<NotificationPrefsCubit>()
                      .toggleNewMessage(v),
                ),
                _Divider(),
                _ToggleTile(
                  icon: Icons.visibility_outlined,
                  label: l10n.settings_notify_profileViews,
                  caption: l10n.settings_notify_profileViewsSub,
                  value: prefs.profileView,
                  onChanged: (v) => context
                      .read<NotificationPrefsCubit>()
                      .toggleProfileView(v),
                ),
                _Divider(),
                _ToggleTile(
                  icon: Icons.public_rounded,
                  label: l10n.settings_notify_profileLive,
                  caption: l10n.settings_notify_profileLiveSub,
                  value: prefs.profileLive,
                  onChanged: (v) => context
                      .read<NotificationPrefsCubit>()
                      .toggleProfileLive(v),
                ),
                _Divider(),
                _ToggleTile(
                  icon: Icons.explore_outlined,
                  label: l10n.settings_notify_compatibleProfiles,
                  caption: l10n.settings_notify_compatibleProfilesSub,
                  value: prefs.newCompatibleProfiles,
                  onChanged: (v) => context
                      .read<NotificationPrefsCubit>()
                      .toggleNewCompatibleProfiles(v),
                ),
                _Divider(),
                _NavTile(
                  icon: Icons.calendar_month_outlined,
                  label: l10n.settings_notify_discoveryDigest,
                  value: _digestFrequencyLabel(
                    l10n,
                    prefs.discoveryDigestFrequency,
                  ),
                  onTap: () => _showDiscoveryDigestSheet(context, prefs),
                ),
                _Divider(),
                _ToggleTile(
                  icon: Icons.timer_outlined,
                  label: l10n.settings_notify_interestExpiring,
                  value: prefs.interestExpiring,
                  onChanged: (v) => context
                      .read<NotificationPrefsCubit>()
                      .toggleInterestExpiring(v),
                ),
                _Divider(),
                _ToggleTile(
                  icon: Icons.notifications_active_outlined,
                  label: l10n.settings_notify_activityNudges,
                  caption: l10n.settings_notify_activityNudgesSub,
                  value: prefs.inactiveNudge,
                  onChanged: (v) => context
                      .read<NotificationPrefsCubit>()
                      .toggleInactiveNudge(v),
                ),
                _Divider(),
                _ToggleTile(
                  icon: Icons.rocket_launch_outlined,
                  label: l10n.settings_notify_boostReminders,
                  caption: l10n.settings_notify_boostRemindersSub,
                  value: prefs.boostAvailable,
                  onChanged: (v) => context
                      .read<NotificationPrefsCubit>()
                      .toggleBoostAvailable(v),
                ),
                _Divider(),
                _ToggleTile(
                  icon: Icons.auto_awesome_outlined,
                  label: l10n.settings_notify_festivalGreetings,
                  caption: l10n.settings_notify_festivalGreetingsSub,
                  value: prefs.festivalGreetings,
                  onChanged: (v) => context
                      .read<NotificationPrefsCubit>()
                      .toggleFestivalGreetings(v),
                ),
                _Divider(),
                _NavTile(
                  icon: Icons.bedtime_outlined,
                  label: l10n.settings_notify_quietHours,
                  value:
                      '${_fmtHour(prefs.quietStartHour)} – ${_fmtHour(prefs.quietEndHour)}',
                  onTap: () => _changeQuietHours(context, prefs),
                ),
              ]),
            ),

            // 3. GUARDIAN
            _SectionHeader(l10n.settings_section_guardian, key: _guardianKey),
            const _GuardianSection(),

            // 4. PRIVACY
            _SectionHeader(l10n.settings_section_privacy, key: _privacyKey),
            const _PrivacySection(),

            // 5. APP
            _SectionHeader(l10n.settings_section_app),
            _SettingsCard(children: [
              BlocBuilder<ThemeCubit, ThemeSelectionState>(
                builder: (context, themeState) => _NavTile(
                  icon: Icons.palette_outlined,
                  label: l10n.settings_appearance,
                  value: themeState.followSystem
                      ? l10n.settings_theme_automatic
                      : _themeLabel(l10n, themeState.activeMode),
                  onTap: () => _showThemeSheet(context),
                ),
              ),
              _Divider(),
              BlocBuilder<LocaleCubit, Locale>(
                builder: (context, locale) {
                  final lang = _kLanguages.firstWhere(
                      (l) => l.code == locale.languageCode,
                      orElse: () => _kLanguages.first);
                  return _NavTile(
                    icon: Icons.language_rounded,
                    label: l10n.settings_label_language,
                    value: lang.englishName,
                    onTap: () => _showLanguageSheet(context, lang),
                  );
                },
              ),
              _Divider(),
              _InfoTile(
                icon: Icons.info_outline_rounded,
                label: l10n.settings_label_version,
                value: _appVersion,
              ),
            ]),

            // 6. SAFETY
            _SectionHeader(l10n.settings_section_safety),
            BlocBuilder<BlockReportCubit, BlockReportState>(
              builder: (context, brs) => _SettingsCard(children: [
                _NavTile(
                  icon: Icons.block_rounded,
                  label: l10n.settings_label_blocked,
                  value: brs.blockedUsers.isEmpty
                      ? l10n.settings_label_blocked_none
                      : l10n.settings_label_blocked_count(
                          brs.blockedUsers.length),
                  onTap: () => context.push(AppRoutes.blockList),
                ),
                _Divider(),
                _NavTile(
                  icon: Icons.flag_outlined,
                  label: l10n.settings_label_reports,
                  value: brs.reportHistory.isEmpty
                      ? l10n.settings_label_reports_none
                      : l10n.settings_label_reports_count(
                          brs.reportHistory.length),
                  onTap: () => _showReportHistory(context, brs),
                ),
              ]),
            ),

            // 7. LEGAL
            _SectionHeader(l10n.settings_helpSupport, key: _helpKey),
            _SettingsCard(children: [
              _NavTile(
                icon: Icons.help_outline_rounded,
                label: l10n.settings_helpCenter,
                onTap: () => context.push(AppRoutes.helpSupport),
              ),
              _Divider(),
              _NavTile(
                icon: Icons.gavel_outlined,
                label: l10n.settings_grievanceOfficer,
                onTap: () => _showGrievanceInfo(context),
              ),
            ]),

            _SectionHeader(l10n.settings_section_legal),
            _SettingsCard(
              children: [
                for (var index = 0;
                    index < LegalDocuments.all.length;
                    index++) ...[
                  _NavTile(
                    icon: _legalIcon(LegalDocuments.all[index].slug),
                    label: LegalDocuments.all[index].title,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LegalDocScreen(
                          type: LegalDocuments.all[index].slug,
                        ),
                      ),
                    ),
                  ),
                  if (index != LegalDocuments.all.length - 1) _Divider(),
                ],
              ],
            ),

            // 8. DANGER ZONE
            _SectionHeader(l10n.settings_section_dangerZone),
            _SettingsCard(
              borderColor: AppColors.softCoral.withValues(alpha: 0.3),
              children: [
                _NavTile(
                  icon: Icons.delete_forever_outlined,
                  label: l10n.settings_button_deleteAccount,
                  iconColor: AppColors.softCoral,
                  labelColor: AppColors.softCoral,
                  onTap: () => context.push(AppRoutes.deleteAccount),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Center(
              child: UiText(
                l10n.settings_brand_credit,
                style: AppTypography.caption.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Grievance Officer (India IT Act 2021)
  static void _showGrievanceInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showSilarahDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.gavel_outlined,
                color: AppColors.champagneGold, size: 20),
            const SizedBox(width: 10),
            UiText(l10n.settings_grievanceOfficer,
                style: AppTypography.bodyMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.space16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    LegalDocuments.grievanceOfficerName,
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  Row(
                    children: [
                      Icon(Icons.email_outlined,
                          color: AppColors.champagneGold, size: 16),
                      const SizedBox(width: 8),
                      UiText('grievance@silarah.com',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.champagneGold)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  UiText(
                    l10n.settings_grievanceResponse,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            UiText(
              l10n.settings_grievanceIndiaNotice,
              style: AppTypography.caption.copyWith(height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: UiText(l10n.settings_support_btn_close,
                style: AppTypography.caption
                    .copyWith(color: AppColors.champagneGold)),
          ),
        ],
      ),
    );
  }

  // Photo privacy
  // Language sheet
  void _showThemeSheet(BuildContext context) {
    showSilarahBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.overlayBlack55,
      builder: (sheetContext) => BlocProvider<ThemeCubit>.value(
        value: context.read<ThemeCubit>(),
        child: const _ThemePickerSheet(),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, SupportedLanguage current) {
    showSilarahBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<LocaleCubit>(),
        child: _LanguagePickerSheet(currentLocale: current.code),
      ),
    );
  }

  void _showReportHistory(BuildContext context, BlockReportState state) {
    showSilarahBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportHistorySheet(reports: state.reportHistory),
    );
  }

  static String _fmtHour(int h) => '${h.toString().padLeft(2, '0')}:00';

  static String _digestFrequencyLabel(
    AppLocalizations l10n,
    DiscoveryDigestFrequency frequency,
  ) =>
      switch (frequency) {
        DiscoveryDigestFrequency.off => l10n.settings_notify_digestOff,
        DiscoveryDigestFrequency.daily => l10n.settings_notify_digestDaily,
        DiscoveryDigestFrequency.weekly => l10n.settings_notify_digestWeekly,
      };

  Future<void> _showDiscoveryDigestSheet(
    BuildContext context,
    NotificationPrefsState prefs,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showSilarahBottomSheet<DiscoveryDigestFrequency>(
      context: context,
      backgroundColor: AppColors.obsidianNight,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UiText(
              l10n.settings_notify_discoveryDigest,
              style: AppTypography.screenTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 6),
            UiText(
              l10n.settings_notify_digestHelp,
              style: AppTypography.caption,
            ),
            const SizedBox(height: 12),
            for (final frequency in DiscoveryDigestFrequency.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: UiText(
                  _digestFrequencyLabel(l10n, frequency),
                  style: AppTypography.body,
                ),
                trailing: Icon(
                  frequency == prefs.discoveryDigestFrequency
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: frequency == prefs.discoveryDigestFrequency
                      ? AppColors.champagneGold
                      : AppColors.slateMist,
                ),
                onTap: () => Navigator.of(sheetContext).pop(frequency),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    context
        .read<NotificationPrefsCubit>()
        .setDiscoveryDigestFrequency(selected);
  }

  Future<void> _changeQuietHours(
    BuildContext context,
    NotificationPrefsState prefs,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.quietStartHour, minute: 0),
      helpText: AppLocalizations.of(context).settings_quietHoursStart,
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (start == null || !context.mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.quietEndHour, minute: 0),
      helpText: AppLocalizations.of(context).settings_quietHoursEnd,
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (end == null || !context.mounted) return;

    context.read<NotificationPrefsCubit>().setQuietHours(
          startHour: start.hour,
          endHour: end.hour,
        );
  }

  // Helper snackbar
  static String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return 'Add email';
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return email;
    final name = parts.first;
    final domain = parts.last;
    if (name.length == 1) return '${name[0]}***@$domain';
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  // Support dialog
}

// GUARDIAN SECTION

class _GuardianSection extends StatefulWidget {
  const _GuardianSection();

  @override
  State<_GuardianSection> createState() => _GuardianSectionState();
}

class _GuardianSectionState extends State<_GuardianSection> {
  bool _enabled = false;
  bool _serverEnabled = false;
  bool _isLinked = false;
  bool _canReply = false;
  String _relationship = 'Father';
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saved = false;
  bool _saving = false;
  bool _hasGuardianEmailOnServer = false;
  bool _renewingInvitation = false;
  bool _hasDashboardAccess = false;

  static const _relationships = [
    'Father',
    'Mother',
    'Brother',
    'Uncle',
    'Other'
  ];

  bool _isValidGuardianEmail(String value) => RegExp(
        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
      ).hasMatch(value.trim().toLowerCase());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!SupabaseService.isInitialized) return;
    final service = WaliModeService.instance;
    final info = await service.getMyGuardianInfo();
    final hasDashboardAccess = await service.isGuardian();
    if (!mounted) return;
    setState(() {
      _hasDashboardAccess = hasDashboardAccess;
      if (info == null) return;
      _enabled = true;
      _serverEnabled = true;
      _isLinked = info.isLinked;
      _canReply = info.mode == 'active';
      _relationship = _relationLabelFromDb(info.relationship);
      _nameCtrl.text = info.name;
      _emailCtrl.text = info.email ?? '';
      _hasGuardianEmailOnServer = info.hasEmail || info.isLinked;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_enabled &&
        (_nameCtrl.text.trim().isEmpty ||
            !_isValidGuardianEmail(_emailCtrl.text))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(
            context.uiCopy(
              'Guardian name and a valid Guardian email are required.',
            ),
          ),
        ),
      );
      return;
    }

    if (!SupabaseService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(l10n.settings_guardian_backendRequired),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    GuardianInvitation? invitation;
    try {
      invitation = await WaliModeService.instance.saveMyGuardianSettings(
        enabled: _enabled,
        guardianName: _nameCtrl.text,
        guardianEmail: _emailCtrl.text,
        relationship: _relationship,
        canReply: _canReply,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(l10n.settings_guardian_saveError),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _saving = false;
        _saved = true;
        _serverEnabled = _enabled;
        if (!_enabled) {
          _isLinked = false;
          _hasGuardianEmailOnServer = false;
        } else {
          _hasGuardianEmailOnServer = true;
        }
      });
      if (invitation != null) await _showInvitation(invitation);
    }
  }

  Future<void> _renewInvitation() async {
    if (_renewingInvitation) return;
    setState(() => _renewingInvitation = true);
    try {
      final invitation =
          await WaliModeService.instance.renewMyGuardianInvitation();
      if (!mounted) return;
      await _showInvitation(invitation);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: UiText('A new Guardian invitation could not be created.'),
      ));
    } finally {
      if (mounted) setState(() => _renewingInvitation = false);
    }
  }

  Future<void> _showInvitation(GuardianInvitation invitation) async {
    await showSilarahBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiText(context.uiCopy('Guardian invitation'),
                  style: AppTypography.screenTitle),
              const SizedBox(height: 8),
              UiText(
                context.uiCopy(
                  'Share this one-time code only with your chosen Guardian. They must sign in with the invited verified email within 7 days.',
                ),
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: 18),
              Semantics(
                label: context.uiCopyWith(
                  'Guardian invitation code {code}',
                  {'code': invitation.code},
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: UiText(
                    invitation.code,
                    style: AppTypography.userName.copyWith(letterSpacing: 4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: invitation.code),
                      );
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                            content: UiText('Invitation code copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const UiText('Copy code'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => SharePlus.instance.share(ShareParams(
                      subject: context.uiCopy('Silarah Guardian invitation'),
                      text: context
                          .uiCopy(
                            'You are invited as my Guardian on Silarah. Install or open Silarah, sign in with the invited email, choose “I have a Guardian invitation”, and enter code {code}. This code expires in 7 days.',
                          )
                          .replaceAll('{code}', invitation.code),
                    )),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: UiText(context.uiCopy('Share securely')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _relationLabel(AppLocalizations l10n, String relation) {
    switch (relation) {
      case 'Father':
        return l10n.settings_relation_father;
      case 'Mother':
        return l10n.settings_relation_mother;
      case 'Brother':
        return l10n.settings_relation_brother;
      case 'Uncle':
        return l10n.settings_relation_uncle;
      case 'Other':
        return l10n.settings_relation_other;
      default:
        return relation;
    }
  }

  String _relationLabelFromDb(String? relation) {
    switch (relation) {
      case 'father':
        return 'Father';
      case 'mother':
        return 'Mother';
      case 'brother':
        return 'Brother';
      case 'uncle':
        return 'Uncle';
      default:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SettingsCard(children: [
      if (_hasDashboardAccess) ...[
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Icon(
            Icons.visibility_outlined,
            color: AppColors.verifiedTeal,
            size: 20,
          ),
          title: UiText(
            context.uiCopy('Open Guardian dashboard'),
            style: AppTypography.body,
          ),
          subtitle: UiText(
            context.uiCopy('View the conversations shared by your wards'),
            style: AppTypography.caption,
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: AppColors.slateMist,
          ),
          onTap: () => context.push(AppRoutes.guardianDashboard),
        ),
        const _DividerFull(),
      ],
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(
          Icons.mark_email_unread_outlined,
          color: AppColors.champagneGold,
          size: 20,
        ),
        title: UiText(
          context.uiCopy('Accept a Guardian invitation'),
          style: AppTypography.body,
        ),
        subtitle: UiText(
          context.uiCopy('Enter a private invitation code from a member'),
          style: AppTypography.caption,
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: AppColors.slateMist,
        ),
        onTap: () => context.push(AppRoutes.guardianConnect),
      ),
      const _DividerFull(),
      // Guardian Mode master toggle
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(Icons.supervisor_account_outlined,
            color: AppColors.champagneGold, size: 20),
        title: UiText(l10n.settings_guardian_title, style: AppTypography.body),
        subtitle:
            UiText(l10n.settings_guardian_sub, style: AppTypography.caption),
        trailing: Switch(
          value: _enabled,
          onChanged: (v) => setState(() {
            _enabled = v;
            if (!v) {
              _canReply = false;
            }
            _saved = false;
          }),
          activeThumbColor: AppColors.obsidianNight,
          activeTrackColor: AppColors.champagneGold,
          inactiveThumbColor: AppColors.slateMist,
          inactiveTrackColor: AppColors.surfaceGlassHover,
        ),
      ),

      // Expandable guardian details
      AnimatedSize(
        duration: AppDimensions.durationReveal,
        curve: Curves.easeOutCubic,
        child: _enabled
            ? Column(children: [
                const _DividerFull(),
                // Guardian name
                _TextFieldTile(
                  icon: Icons.person_outline_rounded,
                  hint: l10n.settings_guardian_name_hint,
                  controller: _nameCtrl,
                ),
                const _DividerFull(),
                // Guardian email
                _TextFieldTile(
                  icon: Icons.alternate_email_rounded,
                  hint: context.uiCopy('Guardian email'),
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                if (_hasGuardianEmailOnServer)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
                    child: UiText(
                      context.uiCopy(_kGuardianEmailHelp),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.slateMist,
                      ),
                    ),
                  ),
                if (_serverEnabled) ...[
                  const _DividerFull(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 10, 16, 10),
                    child: Row(
                      children: [
                        Icon(
                          _isLinked
                              ? Icons.verified_user_outlined
                              : Icons.schedule_send_outlined,
                          color: _isLinked
                              ? AppColors.verifiedTeal
                              : AppColors.champagneGold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: UiText(
                            _isLinked
                                ? 'Guardian account connected'
                                : 'Guardian invitation is waiting for acceptance',
                            style: AppTypography.caption.copyWith(
                              color: _isLinked
                                  ? AppColors.verifiedTeal
                                  : AppColors.champagneGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isLinked) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 16, 10),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed:
                              _renewingInvitation ? null : _renewInvitation,
                          icon: _renewingInvitation
                              ? const SilarahActivityIndicator(
                                  size: 16,
                                )
                              : const Icon(Icons.share_outlined, size: 18),
                          label: const UiText('Create a new invitation code'),
                        ),
                      ),
                    ),
                  ],
                ],
                const _DividerFull(),
                // Relationship dropdown
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Icon(Icons.family_restroom_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: UiText(l10n.settings_guardian_relationship,
                      style: AppTypography.body),
                  trailing: DropdownButton<String>(
                    value: _relationship,
                    dropdownColor: AppColors.surfaceDark,
                    underline: const SizedBox.shrink(),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.champagneGold),
                    icon: Icon(Icons.expand_more_rounded,
                        color: AppColors.slateMist, size: 16),
                    items: _relationships
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: UiText(_relationLabel(l10n, r),
                                  style: AppTypography.body),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _relationship = v);
                    },
                  ),
                ),
                const _DividerFull(),
                // Guardian can reply toggle
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Icon(Icons.reply_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: UiText(l10n.settings_guardian_reply,
                      style: AppTypography.body),
                  subtitle: UiText(l10n.settings_guardian_reply_sub,
                      style: AppTypography.caption),
                  trailing: Switch(
                    value: _canReply,
                    onChanged: (v) => setState(() => _canReply = v),
                    activeThumbColor: AppColors.obsidianNight,
                    activeTrackColor: AppColors.champagneGold,
                    inactiveThumbColor: AppColors.slateMist,
                    inactiveTrackColor: AppColors.surfaceGlassHover,
                  ),
                ),
              ])
            : const SizedBox.shrink(),
      ),
      if (_enabled || _serverEnabled) ...[
        const _DividerFull(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeightSmall,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.champagneGold,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: AnimatedSwitcher(
                duration: AppDimensions.durationTransition,
                child: _saving
                    ? SilarahPulseLoader(
                        key: const ValueKey('saving'),
                        size: 24,
                        accentColor: AppColors.obsidianNight,
                        highlightColor: AppColors.obsidianDeep,
                        markColor: AppColors.champagneLight,
                        coreGradientColors: [
                          AppColors.obsidianNight,
                          AppColors.obsidianDeep,
                        ],
                      )
                    : _saved
                        ? Row(
                            key: const ValueKey('saved'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded,
                                  color: AppColors.obsidianNight, size: 16),
                              const SizedBox(width: 6),
                              UiText(l10n.settings_guardian_saved,
                                  style: AppTypography.button),
                            ],
                          )
                        : UiText(
                            _enabled
                                ? l10n.settings_guardian_save
                                : 'Disconnect guardian',
                            key: const ValueKey('save'),
                            style: AppTypography.button,
                          ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

// PRIVACY SECTION

class _PrivacySection extends StatefulWidget {
  const _PrivacySection();
  @override
  State<_PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<_PrivacySection> {
  // Defaults
  String _photoVisibility = 'Everyone';
  bool _profilePaused = false;
  bool _profilePauseSaving = false;
  String _profileVisibility = 'visible';
  String? _visibilityBlockReason;
  bool _exportingData = false;
  IncognitoSetting? _incognito;
  bool _incognitoLoading = true;
  bool _incognitoSaving = false;
  // Animated save checkmark
  final Map<String, bool> _savedIndicators = {};
  Future<void> _photoPrivacyMutationQueue = Future<void>.value();
  String _confirmedPhotoVisibility = 'Everyone';
  int _photoPrivacyRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var photoVisibility = 'Everyone';
    var profilePaused = false;

    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (SupabaseService.isInitialized && userId != null) {
      try {
        final row = await MyAccountSnapshot.instance.profile(userId);
        final dbPhotoPrivacy = row?['photo_privacy'] as String?;
        final dbVisibility = row?['visibility'] as String?;
        photoVisibility = _photoVisibilityFromDb(dbPhotoPrivacy);
        _profileVisibility = dbVisibility ?? 'visible';
        profilePaused = _profileVisibility != 'visible';
        _visibilityBlockReason = await _visibilityBlockReasonFor(row);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _photoVisibility = photoVisibility;
      _confirmedPhotoVisibility = photoVisibility;
      _profilePaused = profilePaused;
    });
    try {
      final setting = await IncognitoService.instance.load(force: true);
      if (mounted) setState(() => _incognito = setting);
    } catch (_) {
      // The card stays retryable; unrelated privacy settings remain usable.
    } finally {
      if (mounted) setState(() => _incognitoLoading = false);
    }
  }

  Future<void> _toggleIncognito(bool value) async {
    if (_incognitoSaving) return;
    final subscription = context.read<SubscriptionCubit>().state;
    if (value && !subscription.canUseIncognito) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
      );
      if (mounted) {
        await context.read<SubscriptionCubit>().refreshEntitlement();
        setState(() => _incognitoLoading = true);
        try {
          final setting = await IncognitoService.instance.load(force: true);
          if (mounted) setState(() => _incognito = setting);
        } finally {
          if (mounted) setState(() => _incognitoLoading = false);
        }
      }
      return;
    }
    setState(() => _incognitoSaving = true);
    try {
      final setting = await IncognitoService.instance.setEnabled(value);
      if (!mounted) return;
      setState(() => _incognito = setting);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(context.uiCopy(
            setting.enabled
                ? 'Incognito Discovery is on.'
                : 'Incognito Discovery is off.',
          )),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UiText(_settingsErrorMessage(error.toString()))),
      );
    } finally {
      if (mounted) setState(() => _incognitoSaving = false);
    }
  }

  void _selectPhotoVisibility(String value) {
    if (_photoVisibility == value) return;
    final revision = ++_photoPrivacyRevision;
    setState(() {
      _photoVisibility = value;
      _savedIndicators[_kPhotoVisibility] = false;
    });
    _photoPrivacyMutationQueue = _photoPrivacyMutationQueue.then((_) async {
      final backendError = await _persistBackend(_kPhotoVisibility, value);
      if (backendError == null) _confirmedPhotoVisibility = value;
      if (!mounted || revision != _photoPrivacyRevision) return;
      if (backendError != null) {
        setState(() => _photoVisibility = _confirmedPhotoVisibility);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: UiText(backendError)),
        );
        return;
      }
      setState(() => _savedIndicators[_kPhotoVisibility] = true);
    });
  }

  Future<void> _persist(String key, dynamic value,
      {Object? previousValue}) async {
    final backendError = await _persistBackend(key, value);
    if (backendError != null) {
      if (!mounted) return;
      setState(() {
        if (key == _kPhotoVisibility) {
          _photoVisibility = previousValue as String? ?? _photoVisibility;
        } else if (key == _kProfilePaused) {
          _profilePaused = previousValue as bool? ?? _profilePaused;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UiText(backendError)),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _savedIndicators[key] = true);
  }

  Future<String?> _persistBackend(String key, dynamic value) async {
    if (!SupabaseService.isInitialized) {
      return 'Could not connect to Silarah. Please try again.';
    }
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) {
      return 'Please sign in again to update this setting.';
    }
    try {
      if (key == _kPhotoVisibility && value is String) {
        await SupabaseService.client.rpc(
          'set_my_photo_privacy',
          params: {'p_privacy': _photoVisibilityToDb(value)},
        );
      } else if (key == _kProfilePaused && value is bool) {
        final response = await SupabaseService.client.rpc(
          'set_profile_pause',
          params: {'p_paused': value},
        );
        final rows = response as List<dynamic>;
        if (rows.isNotEmpty && mounted) {
          final row = Map<String, dynamic>.from(rows.first as Map);
          setState(() => _profilePaused = row['is_paused'] == true);
          _profileVisibility = row['visibility']?.toString() ?? 'visible';
          _visibilityBlockReason = null;
        }
        if (mounted) {
          await context.read<AccountStandingCubit>().refresh();
        }
        return null;
      }
      if (key == _kPhotoVisibility && value is String && mounted) {
        final privacy = switch (_photoVisibilityToDb(value)) {
          'mutual_only' => PhotoPrivacy.mutualOnly,
          'request_only' => PhotoPrivacy.requestOnly,
          _ => PhotoPrivacy.publicAll,
        };
        await context.read<OnboardingCubit>().syncPhotoPrivacy(privacy);
        ProfilePhotoService.instance.invalidateAllPhotoUrls();
      }
      return null;
    } on PostgrestException catch (error) {
      return _settingsErrorMessage(error.message);
    } catch (error) {
      return _settingsErrorMessage(error.toString());
    }
  }

  Future<String?> _visibilityBlockReasonFor(Map<String, dynamic>? row) async {
    if (row == null) return 'Complete your profile before changing visibility.';
    final visibility = row['visibility'] as String? ?? 'visible';
    if (visibility == 'suspended') {
      return 'This profile is suspended and cannot be made visible from settings.';
    }
    if (visibility == 'deactivated') {
      return 'This profile is deactivated and cannot be made visible from settings.';
    }
    if (row['onboarding_completed'] != true) {
      return 'Complete onboarding before making your profile visible.';
    }
    final profileId = row['id'] as String?;
    if (profileId == null || profileId.isEmpty) {
      return 'Complete your profile before changing visibility.';
    }
    final photos = await SupabaseService.client
        .from('photos')
        .select('id')
        .eq('profile_id', profileId)
        .eq('order_index', 0)
        .eq('status', 'active')
        .eq('admin_approved', true)
        .eq('nsfw_cleared', true)
        .limit(1);
    if ((photos as List<dynamic>).isEmpty) {
      return 'Add a profile photo that passes the safety scan before making your profile visible.';
    }
    return null;
  }

  String _settingsErrorMessage(String message) {
    final cleaned = message
        .replaceAll('Exception:', '')
        .replaceAll('PostgrestException(message:', '')
        .trim();
    if (cleaned.isEmpty || cleaned == 'null') {
      return 'Could not save. Please try again.';
    }
    return cleaned;
  }

  String _photoVisibilityFromDb(String? value) {
    switch (value) {
      case 'mutual_only':
        return 'Accepted interests only';
      case 'request_only':
        return 'Request to view';
      case 'public':
      default:
        return 'Everyone';
    }
  }

  String _photoVisibilityToDb(String value) {
    switch (value) {
      case 'Accepted interests only':
        return 'mutual_only';
      case 'Request to view':
        return 'request_only';
      case 'Everyone':
      default:
        return 'public';
    }
  }

  String _photoPrivacyLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'Public':
        return l10n.settings_photo_privacy_public;
      case 'After Acceptance':
        return l10n.settings_photo_privacy_after_acceptance;
      case 'Request Only':
        return l10n.settings_photo_privacy_request_only;
      case 'Everyone':
        return l10n.settings_photo_privacy_everyone;
      case 'Accepted interests only':
        return l10n.settings_photo_privacy_accepted_interests;
      case 'Request to view':
        return l10n.settings_photo_privacy_request_to_view;
      default:
        return code;
    }
  }

  Future<void> _downloadMyData() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showSilarahDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: UiText(l10n.settings_privacy_download_label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UiText(
              l10n.settings_privacy_download_body,
              style: AppTypography.bodyMedium.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppDimensions.space12),
            Container(
              padding: const EdgeInsets.all(AppDimensions.space12),
              decoration: BoxDecoration(
                color: AppColors.premiumGold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(
                  color: AppColors.premiumGold.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: AppColors.premiumGold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: UiText(
                      l10n.settings_privacy_export_subbody,
                      style: AppTypography.caption.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: UiText(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: UiText(l10n.settings_privacy_download_btn),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _exportingData = true);
    try {
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      final result = await PersonalDataExportService.instance.createAndShare(
        sharePositionOrigin: origin,
      );
      if (!mounted) return;
      final message = result.wasDismissed
          ? l10n.settings_privacy_export_subbody
          : l10n.settings_privacy_export_body;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UiText(message)),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final rateLimited = error.message.contains('export_rate_limited');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: UiText(rateLimited
            ? 'A fresh export was created recently. You can create another in 10 minutes.'
            : _settingsErrorMessage(error.message)),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UiText(_settingsErrorMessage(error.toString()))),
      );
    } finally {
      if (mounted) setState(() => _exportingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unpauseBlocked = _profilePaused && _visibilityBlockReason != null;
    final pauseWarning =
        _visibilityBlockReason ?? l10n.settings_privacy_pause_warning;
    return Column(children: [
      // Photo Visibility
      _PrivacyCard(
        label: l10n.settings_privacy_photo_label,
        subtitle: l10n.settings_privacy_photo_sub,
        saved: _savedIndicators[_kPhotoVisibility] ?? false,
        child: Column(children: [
          const SizedBox(height: 8),
          _RadioRow(
            label: _photoPrivacyLabel(l10n, 'Everyone'),
            selected: _photoVisibility == 'Everyone',
            onTap: () => _selectPhotoVisibility('Everyone'),
          ),
          _RadioRow(
            label: _photoPrivacyLabel(l10n, 'Accepted interests only'),
            selected: _photoVisibility == 'Accepted interests only',
            onTap: () => _selectPhotoVisibility('Accepted interests only'),
          ),
          _RadioRow(
            label: _photoPrivacyLabel(l10n, 'Request to view'),
            selected: _photoVisibility == 'Request to view',
            onTap: () => _selectPhotoVisibility('Request to view'),
          ),
          Divider(color: AppColors.cardBorder, height: 24),
          Semantics(
            button: true,
            label: l10n.settings_managePhotoRequests,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              onTap: () => context.push(AppRoutes.photoRequests),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: AppColors.champagneGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UiText(
                            l10n.settings_managePhotoRequests,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.pearlWhite,
                            ),
                          ),
                          const SizedBox(height: 2),
                          UiText(
                            l10n.settings_managePhotoRequestsSub,
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.slateMist,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: AppDimensions.space8),

      BlocBuilder<SubscriptionCubit, SubscriptionState>(
        builder: (context, subscription) {
          final enabled = _incognito?.enabled == true;
          final requested = _incognito?.requested == true;
          return _PrivacyCard(
            label: context.uiCopy('Incognito discovery'),
            subtitle: context.uiCopy(
                'Browse privately. Your profile appears only to people you contact or already know.'),
            saved: enabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        enabled
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_outlined,
                        color: AppColors.champagneGold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: UiText(
                        context.uiCopy(subscription.canUseIncognito
                            ? enabled
                                ? 'Hidden from general discovery'
                                : 'Visible in general discovery'
                            : requested
                                ? 'Paused until Premium is active again'
                                : 'Premium privacy control'),
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                    if (_incognitoLoading || _incognitoSaving)
                      const SilarahActivityIndicator(
                        size: 24,
                      )
                    else if (subscription.canUseIncognito || requested)
                      _PrivacyToggle(
                        value:
                            subscription.canUseIncognito ? enabled : requested,
                        onChanged: _toggleIncognito,
                      )
                    else
                      TextButton(
                        onPressed: () => _toggleIncognito(true),
                        child: UiText(context.uiCopy('Unlock')),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                UiText(
                  context.uiCopy(
                      'Existing interests, matches, chats and Guardian access remain available. Incognito does not erase prior interactions.'),
                  style: AppTypography.caption.copyWith(height: 1.45),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: AppDimensions.space8),

      // Profile Pause
      _PrivacyCard(
        label: l10n.settings_privacy_pause_label,
        subtitle: l10n.settings_privacy_pause_sub,
        saved: _savedIndicators[_kProfilePaused] ?? false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PrivacyToggle(
              value: _profilePaused,
              onChanged: _profilePauseSaving || unpauseBlocked
                  ? null
                  : (v) {
                      final previous = _profilePaused;
                      setState(() {
                        _profilePaused = v;
                        _profilePauseSaving = true;
                      });
                      _persist(
                        _kProfilePaused,
                        v,
                        previousValue: previous,
                      ).whenComplete(() {
                        if (mounted) {
                          setState(() => _profilePauseSaving = false);
                        }
                      });
                    },
            ),
            if (_profilePaused) ...[
              const SizedBox(height: AppDimensions.space8),
              Container(
                padding: const EdgeInsets.all(AppDimensions.space12),
                decoration: BoxDecoration(
                  color: AppColors.premiumGold.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(
                      color: AppColors.premiumGold.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.visibility_off_outlined,
                      color: AppColors.premiumGold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: UiText(
                      pauseWarning,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.premiumGold),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppDimensions.space8),

      _PrivacyCard(
        label: l10n.settings_privacy_download_label,
        subtitle: l10n.settings_privacy_download_sub,
        saved: false,
        child: Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _exportingData ? null : _downloadMyData,
              icon: _exportingData
                  ? const SilarahActivityIndicator(
                      size: 18,
                    )
                  : const Icon(Icons.download_for_offline_outlined),
              label: UiText(l10n.settings_privacy_download_btn),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppDimensions.space8),
      ListTile(
        leading: const Icon(Icons.manage_accounts_outlined),
        title: const UiText('Privacy requests'),
        subtitle:
            const UiText('Access, correction, erasure, consent and nomination'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const PrivacyRequestsScreen(),
        )),
      ),
    ]);
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.label,
    required this.subtitle,
    required this.child,
    required this.saved,
  });
  final String label;
  final String subtitle;
  final Widget child;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: UiText(label, style: AppTypography.sectionLabel),
            ),
            AnimatedSwitcher(
              duration: AppDimensions.durationTransition,
              child: saved
                  ? Row(
                      key: const ValueKey('saved'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            color: AppColors.verifiedTeal, size: 14),
                        const SizedBox(width: 3),
                        UiText(
                            AppLocalizations.of(context)
                                .settings_guardian_saved,
                            style: AppTypography.caption.copyWith(
                                color: AppColors.verifiedTeal, fontSize: 11)),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ]),
          const SizedBox(height: 2),
          UiText(subtitle, style: AppTypography.caption),
          child,
        ],
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.obsidianNight,
        activeTrackColor: AppColors.champagneGold,
        inactiveThumbColor: AppColors.slateMist,
        inactiveTrackColor: AppColors.surfaceGlassHover,
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space10),
        child: Row(children: [
          AnimatedContainer(
            duration: AppDimensions.durationTransition,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.champagneGold : Colors.transparent,
              border: Border.all(
                color: selected ? AppColors.champagneGold : AppColors.slateMist,
                width: 2,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded,
                    color: AppColors.obsidianNight, size: 14)
                : null,
          ),
          const SizedBox(width: AppDimensions.space12),
          UiText(label, style: AppTypography.body),
        ]),
      ),
    );
  }
}

// THEME PICKER SHEET

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return BlocBuilder<ThemeCubit, ThemeSelectionState>(
      builder: (context, themeState) => AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMid,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 36,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 14, 24, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              UiText(
                l10n.settings_theme_chooseTitle,
                style: AppTypography.screenTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 6),
              UiText(
                l10n.settings_theme_chooseSubtitle,
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: 24),
              _ThemePreviewCard(
                label: l10n.settings_theme_automatic,
                description: l10n.settings_theme_automaticDesc,
                miniature: const _AutomaticThemeMiniature(),
                selected: themeState.followSystem,
                onTap: () async {
                  if (themeState.followSystem) return;
                  HapticFeedback.selectionClick();
                  await context.read<ThemeCubit>().applyAutomatic();
                },
              ),
              for (final mode in SilarahThemeMode.values) ...[
                const SizedBox(height: 12),
                _ThemePreviewCard(
                  label: _themeLabel(l10n, mode),
                  description: _themeDescription(l10n, mode),
                  miniature:
                      _ThemeMiniature(palette: SilarahPalette.forMode(mode)),
                  selected: !themeState.followSystem &&
                      mode == themeState.selectedMode,
                  onTap: () async {
                    if (!themeState.followSystem &&
                        mode == themeState.selectedMode) {
                      return;
                    }
                    HapticFeedback.selectionClick();
                    await context.read<ThemeCubit>().applyMode(mode);
                  },
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.verifiedTeal,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  UiText(
                    l10n.settings_theme_applied,
                    style: AppTypography.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.label,
    required this.description,
    required this.miniature,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final Widget miniature;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${context.uiCopy(label)}. ${context.uiCopy(description)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldGlow : AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.champagneGold : AppColors.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              miniature,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(
                      label,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 16,
                        color: selected
                            ? AppColors.champagneGold
                            : AppColors.pearlWhite,
                      ),
                    ),
                    const SizedBox(height: 3),
                    UiText(description, style: AppTypography.caption),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: selected
                    ? Container(
                        key: const ValueKey('selected'),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.champagneGold,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppColors.obsidianNight,
                          size: 17,
                        ),
                      )
                    : Icon(
                        Icons.arrow_forward_ios_rounded,
                        key: const ValueKey('available'),
                        color: AppColors.slateMist,
                        size: 15,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ivory & Emerald on the left, Pure OLED on the right: the two identities
/// Automatic switches between with the phone's light or dark setting.
class _AutomaticThemeMiniature extends StatelessWidget {
  const _AutomaticThemeMiniature();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 72,
      height: 82,
      child: Stack(
        children: [
          _ThemeMiniature(palette: SilarahPalette.ivoryEmerald),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.horizontal(right: Radius.circular(13)),
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: .5,
                child: _ThemeMiniature(palette: SilarahPalette.oled),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeMiniature extends StatelessWidget {
  const _ThemeMiniature({required this.palette});

  final SilarahPalette palette;

  @override
  Widget build(BuildContext context) {
    final chromatic = palette.mode.isChromatic;
    return Container(
      width: 72,
      height: 82,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: chromatic ? null : palette.accent,
                  gradient: chromatic
                      ? LinearGradient(
                          colors: [
                            palette.spectrum[0],
                            palette.spectrum[1],
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.contentPrimary.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: chromatic ? null : palette.surfaceInteractive,
                gradient: chromatic
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          palette.spectrum[0].withValues(alpha: .55),
                          palette.spectrum[2].withValues(alpha: .34),
                          palette.surfaceInteractive,
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: palette.border),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            height: 7,
            decoration: BoxDecoration(
              color: chromatic ? null : palette.accent,
              gradient:
                  chromatic ? LinearGradient(colors: palette.spectrum) : null,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({required this.currentLocale});
  final String currentLocale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: ListView(
        shrinkWrap: true,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          UiText(l10n.settings_label_language,
              style: AppTypography.screenTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          ..._kLanguages.map((lang) {
            final isSelected = lang.code == currentLocale;
            return GestureDetector(
              onTap: () async {
                await context.read<LocaleCubit>().setLocale(Locale(lang.code));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: UiText(
                        context.uiCopyWith('Language · {language}',
                            {'language': lang.nativeName}),
                        style: AppTypography.body.copyWith(
                          color:
                              AppColors.readableOn(AppColors.surfaceGlassHover),
                        ),
                      ),
                      backgroundColor: AppColors.surfaceGlassHover,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color:
                      isSelected ? AppColors.goldGlow : AppColors.surfaceGlass,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.champagneGold
                        : AppColors.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Expanded(
                    child: lang.isRtl
                        ? Directionality(
                            textDirection: TextDirection.rtl,
                            child: Row(children: [
                              UiText(lang.nativeName,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: isSelected
                                        ? AppColors.champagneGold
                                        : AppColors.pearlWhite,
                                  )),
                              const SizedBox(width: 8),
                              UiText('(${lang.englishName})',
                                  style: AppTypography.caption),
                            ]),
                          )
                        : Row(children: [
                            UiText(lang.nativeName,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: isSelected
                                      ? AppColors.champagneGold
                                      : AppColors.pearlWhite,
                                )),
                            if (lang.nativeName != lang.englishName) ...[
                              const SizedBox(width: 8),
                              UiText('(${lang.englishName})',
                                  style: AppTypography.caption),
                            ],
                          ]),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded,
                        color: AppColors.champagneGold, size: 18),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// SHARED TILE & CARD WIDGETS

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 28, 0, 10),
        child: UiText(
          label,
          style: AppTypography.sectionLabel.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.7,
          ),
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color? borderColor;
  const _SettingsCard({required this.children, this.borderColor});

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceElevated,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: borderColor ?? AppColors.cardBorder.withValues(alpha: .72),
          ),
        ),
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
        color: AppColors.divider,
        height: 1,
        indent: 62,
        endIndent: 16,
      );
}

class _DividerFull extends StatelessWidget {
  const _DividerFull();
  @override
  Widget build(BuildContext context) =>
      Divider(color: AppColors.divider, height: 1);
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        visualDensity: const VisualDensity(vertical: -1),
        minVerticalPadding: 8,
        minLeadingWidth: 38,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: _SettingsIcon(icon: icon, color: iconColor),
        title: UiText(label,
            style: AppTypography.body.copyWith(color: labelColor)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              UiText(value!,
                  style: AppTypography.caption.copyWith(
                    color: labelColor != null
                        ? labelColor!.withValues(alpha: 0.7)
                        : AppColors.slateMist,
                  )),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: iconColor ?? AppColors.slateMist, size: 18),
          ],
        ),
      );
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        visualDensity: const VisualDensity(vertical: -1),
        minVerticalPadding: 8,
        minLeadingWidth: 38,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: _SettingsIcon(icon: icon),
        title: UiText(label, style: AppTypography.body),
        subtitle: caption != null
            ? UiText(caption!, style: AppTypography.caption)
            : null,
        trailing: Semantics(
          label: context.uiCopy(label),
          toggled: value,
          child: Transform.scale(
            scale: .82,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.readableOn(
                AppColors.champagneGold,
              ),
              activeTrackColor: AppColors.champagneGold,
              inactiveThumbColor: AppColors.slateMist,
              inactiveTrackColor: AppColors.surfaceGlassHover,
            ),
          ),
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoTile({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) => ListTile(
        visualDensity: const VisualDensity(vertical: -1),
        minVerticalPadding: 8,
        minLeadingWidth: 38,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: _SettingsIcon(icon: icon),
        title: UiText(label, style: AppTypography.body),
        trailing:
            value != null ? UiText(value!, style: AppTypography.caption) : null,
      );
}

class _TextFieldTile extends StatelessWidget {
  const _TextFieldTile({
    required this.icon,
    required this.hint,
    required this.controller,
    this.keyboardType,
  });
  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => ListTile(
        visualDensity: const VisualDensity(vertical: -1),
        minVerticalPadding: 8,
        minLeadingWidth: 38,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: _SettingsIcon(icon: icon),
        title: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTypography.body,
          decoration: InputDecoration(
            labelText: hint,
            hintText: hint,
            hintStyle: AppTypography.bodyMuted,
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? AppColors.champagneGold;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: resolved, size: 18),
    );
  }
}

// Report History Sheet
class _ReportHistorySheet extends StatelessWidget {
  final List<ReportEntry> reports;
  const _ReportHistorySheet({required this.reports});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          UiText(l10n.settings_label_reports,
              style: AppTypography.screenTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: UiText(l10n.settings_label_reports_none,
                  style: AppTypography.bodyMuted),
            ))
          else
            ...reports.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.surfaceGlass,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(children: [
                      Icon(Icons.flag_outlined,
                          color: AppColors.softCoral, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UiText(r.reportedName,
                              style: AppTypography.bodyMedium),
                          UiText(r.reason.label, style: AppTypography.caption),
                        ],
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: AppColors.surfaceGlassHover,
                        ),
                        child: UiText(l10n.settings_reportPending,
                            style:
                                AppTypography.caption.copyWith(fontSize: 10)),
                      ),
                    ]),
                  ),
                )),
        ],
      ),
    );
  }
}
