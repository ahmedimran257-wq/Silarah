import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/legal/legal_documents.dart';
import '../../../core/legal/legal_translations.dart';
import '../../../core/legal/public_site_links.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Renders the versioned policy catalogue used by onboarding and Settings.
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final document = LegalDocuments.fromType(type);
    // Calling, minute-pack and refund terms in Hindi, Urdu and Bengali
    // (DPDP s.5(3)); the English text below them prevails.
    final translation = LegalTranslations.of(
        document.slug, Localizations.localeOf(context).languageCode);
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: context.uiCopy('Back'),
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.pearlWhite,
            size: 20,
          ),
        ),
        title: UiText(
          context.uiCopy(document.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.screenTitle.copyWith(fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: context.uiCopy('Open official web version'),
            onPressed: () => _openOfficialWebVersion(context, document),
            icon: Icon(
              Icons.open_in_new_rounded,
              color: AppColors.champagneGold,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
        ],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DocumentHeader(document: document),
              if (Localizations.localeOf(context).languageCode != 'en') ...[
                const SizedBox(height: AppDimensions.space16),
                const _OfficialLanguageNotice(),
              ],
              if (translation != null) ...[
                const SizedBox(height: AppDimensions.space16),
                _TranslatedSections(translation: translation),
              ],
              const SizedBox(height: AppDimensions.space24),
              for (final section in document.sections)
                _PolicySection(section: section),
              const _ContactFooter(),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _openOfficialWebVersion(
    BuildContext context,
    LegalDocument document,
  ) async {
    final uri = PublicSiteLinks.policy(document.slug);
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
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceGlassHover,
        ),
      );
  }
}

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.policy_outlined,
                color: AppColors.champagneGold,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.space10),
              Expanded(
                child: UiText(
                  context.uiCopy(document.title),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.champagneGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space12),
          UiText(
            document.summary,
            style: AppTypography.bodyMuted.copyWith(height: 1.55),
          ),
          const SizedBox(height: AppDimensions.space14),
          UiText(
            '${context.uiCopy('Effective')} '
            '${LegalDocuments.effectiveDate}  •  '
            '${context.uiCopy('Version')} ${LegalDocuments.version}',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _OfficialLanguageNotice extends StatelessWidget {
  const _OfficialLanguageNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space14),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(
          color: AppColors.champagneGold.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.translate_rounded,
            color: AppColors.champagneGold,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(
                  context.uiCopy('Official policy text'),
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.space4),
                UiText(
                  context.uiCopy(
                    'The binding policy below is provided in English. Localized titles and navigation help you find each policy.',
                  ),
                  style: AppTypography.caption.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslatedSections extends StatelessWidget {
  const _TranslatedSections({required this.translation});

  final LegalTranslation translation;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('legal-translation'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiText.verbatim(
            translation.heading,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.champagneGold,
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          UiText.verbatim(
            translation.note,
            style: AppTypography.caption.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppDimensions.space20),
          for (final section in translation.sections)
            _PolicySection(section: section, verbatim: true),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.section, this.verbatim = false});

  final LegalSection section;

  /// Already in the reader's language: shown as written.
  final bool verbatim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          verbatim
              ? UiText.verbatim(section.title, style: AppTypography.bodyMedium)
              : UiText(section.title, style: AppTypography.bodyMedium),
          const SizedBox(height: AppDimensions.space8),
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: AppDimensions.space12),
          verbatim
              ? UiText.verbatim(
                  section.body,
                  style: AppTypography.body.copyWith(height: 1.7),
                )
              : UiText(
                  section.body,
                  style: AppTypography.body.copyWith(height: 1.7),
                ),
        ],
      ),
    );
  }
}

class _ContactFooter extends StatelessWidget {
  const _ContactFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(
          color: AppColors.champagneGold.withValues(alpha: 0.24),
        ),
      ),
      child: UiText(
        '${context.uiCopy('Questions')}: ${LegalDocuments.supportEmail}\n'
        '${context.uiCopy('Privacy requests')}: '
        '${LegalDocuments.privacyEmail}\n'
        '${context.uiCopy('Formal grievances')}: '
        '${LegalDocuments.grievanceEmail}',
        style: AppTypography.caption.copyWith(height: 1.7),
      ),
    );
  }
}
