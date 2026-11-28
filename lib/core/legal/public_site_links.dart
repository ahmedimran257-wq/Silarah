abstract final class PublicSiteLinks {
  static const origin = 'https://silarah.com';
  static final app = Uri.parse('https://app.silarah.com/');
  static final about = Uri.parse('$origin/about/');
  static final safety = Uri.parse('$origin/safety/');
  static final faq = Uri.parse('$origin/faq/');
  static final help = Uri.parse('$origin/help/');
  static final legal = Uri.parse('$origin/legal/');
  static final deleteAccount = Uri.parse('$origin/delete-account/');
  static final googlePlaySubscriptions = Uri.parse(
    'https://play.google.com/store/account/subscriptions?package=com.silarah.app',
  );

  /// The Play Store app first; the web listing when it is missing.
  static final googlePlayAppListing =
      Uri.parse('market://details?id=com.silarah.app');
  static final googlePlayWebListing = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.silarah.app',
  );
  static final googlePlayRefundRequest = Uri.parse(
    'https://support.google.com/googleplay/workflow/9813244',
  );

  static Uri policy(String slug) => Uri.parse('$origin/$slug/');
}
