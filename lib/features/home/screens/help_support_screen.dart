import 'package:silarah/l10n/ui_copy.dart';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/legal/public_site_links.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/services/coach_mark_service.dart';
import '../../../core/services/support_email.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/silarah_product_guide.dart';
import 'settings_screen.dart';
import 'profile_views_screen.dart';
import 'block_list_screen.dart';
import '../../calls/calling_rules.dart';
import '../../calls/calls_hub.dart';
import '../../calls/widgets/calling_guide_sheet.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final member = auth is AuthAuthenticated && !auth.isGuardianOnly;
    final memberId = auth is AuthAuthenticated ? auth.userId : null;
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
              color: AppColors.pearlWhite,
              size: 20),
        ),
        title: UiText(
          context.uiCopy('Help & Support'),
          style: AppTypography.screenTitle.copyWith(fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _GuidanceCard(
            onOpenGuide: () => SilarahProductGuide.show(context),
            onReplayTips: () => _resetFirstUseTips(context),
          ),
          const SizedBox(height: AppDimensions.space16),
          const _FaqTile(
            question: 'Interests',
            answer:
                'Every interest keeps a clear status. Open Sent to review, withdraw, or follow its progress without losing the profile.',
          ),
          _FaqTile(
            question: 'Photo Privacy',
            answer:
                'Public photos appear after upload and moderation. Private photos are shown only based on your photo privacy setting.',
            onTap: member
                ? () => _openScreen(
                    context, const SettingsScreen(initialSection: 'privacy'))
                : null,
            actionLabel: 'Photo Privacy',
          ),
          _FaqTile(
            question: 'Profile Views',
            answer:
                'The activity eye shows profile visits. Your profile, photo controls, and optional trust checks stay together here.',
            onTap: member
                ? () => _openScreen(context, const ProfileViewsScreen())
                : null,
            actionLabel: 'Profile Views',
          ),
          _FaqTile(
            question: 'Guardian connection',
            answer: 'Optional consent-based guardian connection',
            onTap: member
                ? () => _openScreen(
                    context, const SettingsScreen(initialSection: 'guardian'))
                : null,
            actionLabel: 'Guardian connection',
          ),
          _FaqTile(
            question: 'Safety & Reports',
            answer:
                'Report abusive behavior from the profile menu. Urgent safety reviews are prioritized.',
            onTap: member
                ? () => _openScreen(context, const BlockListScreen())
                : null,
            actionLabel: 'Blocked Profiles',
          ),
          // Voice calls: only while calling is switched on (one gate).
          ValueListenableBuilder<CallingRules?>(
            valueListenable: CallsHub.instance.rules,
            builder: (context, rules, _) => rules?.callsEnabled == true
                ? _FaqTile(
                    question: 'Voice calls',
                    answer:
                        'Call your matches privately inside Silarah. See who can call, how call minutes work and how members are protected from unwanted calls.',
                    onTap: member ? () => showCallingGuide(context) : null,
                    actionLabel: 'How calling works',
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: AppDimensions.space16),
          const _EmailTrustNotice(),
          const SizedBox(height: AppDimensions.space16),
          _SupportCard(
            icon: Icons.support_agent_rounded,
            title: 'Contact Support',
            body:
                'For account, billing, safety, verification, or profile issues.',
            actionLabel: 'support@silarah.com',
            onTap: () => _contactEmail(
              context,
              SupportInbox.support,
              memberId: memberId,
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
          _SupportCard(
            icon: Icons.verified_user_outlined,
            title: 'Safety & Reports',
            body:
                'Report abusive behavior from the profile menu. Urgent safety reviews are prioritized.',
            actionLabel: 'safety@silarah.com',
            onTap: () => _contactEmail(
              context,
              SupportInbox.safety,
              memberId: memberId,
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
          _SupportCard(
            icon: Icons.gavel_outlined,
            title: 'Grievance Officer',
            body:
                'Silarah Grievance Desk. Formal grievances are acknowledged and resolved within the time limits set by Indian law.',
            actionLabel: 'grievance@silarah.com',
            onTap: () => _contactEmail(
              context,
              SupportInbox.grievance,
              memberId: memberId,
            ),
          ),
          const SizedBox(height: AppDimensions.space20),
          UiText(context.uiCopy('Common Help'),
              style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          const _FaqTile(
            question: 'Why are my photos not visible?',
            answer:
                'Public photos appear after upload and moderation. Private photos are shown only based on your photo privacy setting.',
          ),
          const _FaqTile(
            question: 'Why can I not message someone?',
            answer:
                'Messaging opens after a mutual interest. Women read and send messages free. Men need active Premium to send. No phone number or KYC is required.',
          ),
          const _FaqTile(
            question: 'How does verification work?',
            answer:
                'Photo verification uses an easy look, smile and blink guide followed by human comparison with your current profile photo. Temporary captures are deleted after review and within 48 hours; no face template or government-ID match is created.',
          ),
          const SizedBox(height: AppDimensions.space20),
          UiText(context.uiCopy('Official online resources'),
              style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          _WebResourceTile(
            icon: Icons.help_center_outlined,
            title: 'Full Help Center',
            uri: PublicSiteLinks.help,
            onTap: () => _openWebPage(context, PublicSiteLinks.help),
          ),
          _WebResourceTile(
            icon: Icons.quiz_outlined,
            title: 'Frequently Asked Questions',
            uri: PublicSiteLinks.faq,
            onTap: () => _openWebPage(context, PublicSiteLinks.faq),
          ),
          _WebResourceTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Safety Center',
            uri: PublicSiteLinks.safety,
            onTap: () => _openWebPage(context, PublicSiteLinks.safety),
          ),
          _WebResourceTile(
            icon: Icons.account_balance_outlined,
            title: 'Legal Center',
            uri: PublicSiteLinks.legal,
            onTap: () => _openWebPage(context, PublicSiteLinks.legal),
          ),
          _WebResourceTile(
            icon: Icons.info_outline_rounded,
            title: 'About Silarah',
            uri: PublicSiteLinks.about,
            onTap: () => _openWebPage(context, PublicSiteLinks.about),
          ),
        ],
      ),
    );
  }

  static void _openScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  static Future<void> _contactEmail(
    BuildContext context,
    SupportInbox inbox, {
    String? memberId,
  }) async {
    final email = inbox.address;
    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version} (${info.buildNumber})';
    } catch (_) {
      // The email still opens without version details.
    }
    final uri = supportEmailUri(
      inbox,
      appVersion: appVersion,
      device: _deviceLabel(),
      memberId: memberId,
    );
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    await Clipboard.setData(ClipboardData(text: email));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: UiText(context.uiEmailCopied(email),
              style: AppTypography.body.copyWith(
                color: AppColors.readableOn(AppColors.surfaceGlassHover),
              )),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: BorderSide(color: AppColors.cardBorder),
          ),
        ),
      );
  }

  static String? _deviceLabel() {
    if (kIsWeb) return 'Web';
    final version = Platform.operatingSystemVersion.trim();
    final label =
        '${Platform.isIOS ? 'iOS' : Platform.isAndroid ? 'Android' : Platform.operatingSystem} $version';
    return label.length <= 80 ? label : label.substring(0, 80);
  }

  static Future<void> _resetFirstUseTips(BuildContext context) async {
    await CoachMarkService().resetAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: UiText(
            context.uiCopy('First-use tips are ready to show again.'),
            style: AppTypography.body.copyWith(
              color: AppColors.readableOn(AppColors.surfaceGlassHover),
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceGlassHover,
        ),
      );
  }

  static Future<void> _openWebPage(BuildContext context, Uri uri) async {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: UiText(
            context.uiCopy('Web address copied to your clipboard.'),
            style: TextStyle(
              color: AppColors.readableOn(AppColors.surfaceGlassHover),
            ),
          ),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.onOpenGuide,
    required this.onReplayTips,
  });

  final VoidCallback onOpenGuide;
  final VoidCallback onReplayTips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.goldGlow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                ),
                child: Icon(
                  Icons.route_outlined,
                  size: 21,
                  color: AppColors.champagneGold,
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(
                      context.uiCopy('Using Silarah'),
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppDimensions.space4),
                    UiText(
                      context.uiCopy(
                        'Learn how introductions, interests, privacy, and conversations work.',
                      ),
                      style: AppTypography.caption.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeightSmall,
            child: OutlinedButton.icon(
              onPressed: onOpenGuide,
              icon: const Icon(Icons.menu_book_outlined, size: 17),
              label: UiText(context.uiCopy('View guide')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.champagneGold,
                side: BorderSide(color: AppColors.goldBorder),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.center,
            child: TextButton(
              onPressed: onReplayTips,
              child: UiText(
                context.uiCopy('Show first-use tips again'),
                textAlign: TextAlign.center,
                style: AppTypography.captionMedium.copyWith(
                  color: AppColors.slateMist,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebResourceTile extends StatelessWidget {
  const _WebResourceTile({
    required this.icon,
    required this.title,
    required this.uri,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Uri uri;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: Material(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.champagneGold, size: 20),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText(title, style: AppTypography.bodyMedium),
                      const SizedBox(height: AppDimensions.space2),
                      UiText(
                        uri.host + uri.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  color: AppColors.slateMist,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onTap;

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
          Row(
            children: [
              Icon(icon, color: AppColors.champagneGold, size: 22),
              const SizedBox(width: AppDimensions.space8),
              Expanded(child: UiText(title, style: AppTypography.bodyMedium)),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          UiText(body, style: AppTypography.caption.copyWith(height: 1.5)),
          const SizedBox(height: AppDimensions.space12),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeightSmall,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: UiText(actionLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.champagneGold,
                side: BorderSide(color: AppColors.goldBorder),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailTrustNotice extends StatelessWidget {
  const _EmailTrustNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mark_email_read_outlined,
              color: AppColors.champagneGold, size: 21),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText('Recognize official Silarah email',
                    style: AppTypography.bodyMedium),
                const SizedBox(height: AppDimensions.space4),
                UiText(
                  'Account and security messages use @mail.silarah.com. Product updates use @news.silarah.com. We never ask for passwords or verification codes.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppDimensions.space8),
                UiText(
                  'Support replies come from support@silarah.com. If you are waiting for one, please check Spam or Junk and mark it “Not spam”.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.question,
    required this.answer,
    this.onTap,
    this.actionLabel,
  });

  final String question;
  final String answer;
  final VoidCallback? onTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.space8),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ExpansionTile(
        collapsedIconColor: AppColors.slateMist,
        iconColor: AppColors.champagneGold,
        title: UiText(question, style: AppTypography.body),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: UiText(answer,
                style: AppTypography.caption.copyWith(height: 1.5)),
          ),
          if (onTap != null && actionLabel != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: UiText(actionLabel!),
              ),
            ),
        ],
      ),
    );
  }
}
