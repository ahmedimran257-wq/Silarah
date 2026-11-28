// Values are injected at build time with --dart-define or
// --dart-define-from-file. Live project config is never committed here.
abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Region of the Supabase project's database, e.g. ap-northeast-1. Edge
  /// functions otherwise run near the caller and pay a cross-region round
  /// trip for every database, auth and storage call they make.
  static const String supabaseFunctionsRegion =
      String.fromEnvironment('SUPABASE_FUNCTIONS_REGION');

  /// Google OAuth web client ID (not a secret). Native Google sign-in asks
  /// for an ID token issued to this client, and the Supabase Google provider
  /// accepts that client. Empty means the build has no Google sign-in.
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static const String revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const String revenueCatIosKey =
      String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const String revenueCatTestKey =
      String.fromEnvironment('REVENUECAT_TEST_KEY');
}
