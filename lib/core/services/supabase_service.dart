// SILARAH — Supabase Service
// Provides singleton Supabase client throughout the app.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import 'my_account_snapshot.dart';
import 'request_timeout_client.dart';

enum SessionRecoveryStatus {
  authenticated,
  noSession,
  invalidSession,
  transientFailure,
}

class SessionRecoveryResult {
  const SessionRecoveryResult._(this.status, {this.session, this.error});

  const SessionRecoveryResult.authenticated(Session session)
      : this._(SessionRecoveryStatus.authenticated, session: session);
  const SessionRecoveryResult.noSession()
      : this._(SessionRecoveryStatus.noSession);
  const SessionRecoveryResult.invalidSession([Object? error])
      : this._(SessionRecoveryStatus.invalidSession, error: error);
  const SessionRecoveryResult.transientFailure([Object? error])
      : this._(SessionRecoveryStatus.transientFailure, error: error);

  final SessionRecoveryStatus status;
  final Session? session;
  final Object? error;
}

class SupabaseService {
  SupabaseService._();

  static SupabaseClient? _client;
  static bool _isInitialized = false;
  static Future<SessionRecoveryResult>? _sessionRecoveryInFlight;
  static const _minimumSessionValidity = Duration(minutes: 2);

  /// Returns the Supabase client instance.
  /// Throws if not initialized - check `isInitialized` first.
  static SupabaseClient get client {
    if (_client == null) {
      throw StateError(
          'SupabaseService not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Whether Supabase has been initialized.
  static bool get isInitialized => _isInitialized;

  /// Whether configured credentials are usable for this build.
  static bool get isConfigured => _hasUsableConfig;

  /// Current user ID if authenticated, null otherwise.
  ///
  /// Supabase can restore a persisted session before `currentUser` is hydrated
  /// after app resume. Discovery and chat use this helper so a valid session is
  /// not mistaken for a signed-out user.
  static String? get currentUserId =>
      _client?.auth.currentUser?.id ?? _client?.auth.currentSession?.user.id;

  /// Returns a session that is valid long enough to start a backend request.
  ///
  /// A persisted Supabase session can still expose `currentUser` while its
  /// access token is expired (or seconds from expiry). Treating that as an
  /// authenticated session produces intermittent 401 responses on Edge
  /// Functions and private Storage reads. Refresh once, shared by all callers,
  /// before allowing authenticated work to continue.
  static Future<Session?> currentSessionOrRefresh() async {
    final result = await recoverSession();
    return result.status == SessionRecoveryStatus.authenticated
        ? result.session
        : null;
  }

  /// Restores the persisted session without collapsing temporary network
  /// failures into a signed-out identity. Startup routing uses the status to
  /// distinguish a real logout from a connection that is still warming up.
  static Future<SessionRecoveryResult> recoverSession() async {
    if (!_isInitialized || _client == null) {
      return const SessionRecoveryResult.noSession();
    }

    final session = _client!.auth.currentSession;
    if (session == null) return const SessionRecoveryResult.noSession();
    if (_isSessionUsable(session)) {
      return SessionRecoveryResult.authenticated(session);
    }

    final activeRecovery = _sessionRecoveryInFlight;
    if (activeRecovery != null) return activeRecovery;

    final recovery = _refreshCurrentSession();
    _sessionRecoveryInFlight = recovery;
    try {
      return await recovery;
    } finally {
      if (identical(_sessionRecoveryInFlight, recovery)) {
        _sessionRecoveryInFlight = null;
      }
    }
  }

  static Future<String?> currentUserIdOrRefresh() async {
    final session = await currentSessionOrRefresh();
    return session?.user.id;
  }

  static Future<SessionRecoveryResult> _refreshCurrentSession() async {
    try {
      final response = await _client!.auth.refreshSession();
      final refreshed = response.session;
      if (_isSessionUsable(refreshed)) {
        return SessionRecoveryResult.authenticated(refreshed!);
      }
      return const SessionRecoveryResult.invalidSession();
    } catch (error) {
      return _isInvalidRefreshToken(error)
          ? SessionRecoveryResult.invalidSession(error)
          : SessionRecoveryResult.transientFailure(error);
    }
  }

  static bool _isInvalidRefreshToken(Object error) {
    if (error is! AuthException) return false;
    final message = error.message.toLowerCase();
    return message.contains('invalid refresh token') ||
        message.contains('refresh token not found') ||
        message.contains('refresh_token_not_found') ||
        message.contains('already used');
  }

  static bool _isSessionUsable(Session? session) {
    if (session == null || session.isExpired) return false;

    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true;

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt - nowSeconds > _minimumSessionValidity.inSeconds;
  }

  /// Guard production features that cannot run without Supabase.
  ///
  /// Debug/dev screens may choose to show an empty state while a developer is
  /// wiring credentials. Release builds fail closed instead of exposing local
  /// demo or fake behavior.
  static bool requireInitialized(String featureName) {
    if (_isInitialized) return true;
    if (kReleaseMode) {
      throw StateError(
        '$featureName requires Supabase. Release builds must fail closed.',
      );
    }
    debugPrint(
      '[SupabaseService] $featureName skipped because Supabase is not '
      'initialized. This is allowed only in debug/dev builds.',
    );
    return false;
  }

  /// Initialize Supabase with credentials from AppConfig.
  /// Call this before runApp() in main.dart.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const url = AppConfig.supabaseUrl;
    const anonKey = AppConfig.supabaseAnonKey;

    if (!_hasUsableConfig) {
      throw StateError(
        'Supabase credentials are not configured. Production builds must fail '
        'closed before auth, profile, discovery, chat, or payment flows run.',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        // AuthCallbackService owns URI validation and exchange. A second
        // listener would bypass its allowlist and race the one-time code.
        detectSessionInUri: false,
      ),
      // Writes clear the shared account rows; every request has a time limit.
      httpClient: AccountSnapshotInvalidatingClient(RequestTimeoutClient()),
    );
    _client = Supabase.instance.client;
    _isInitialized = true;
  }

  /// Pass to every `functions.invoke` so edge functions run beside the
  /// database. Null (no pinning) when the build does not set the region.
  static String? get functionsRegion {
    final region = AppConfig.supabaseFunctionsRegion.trim();
    return region.isEmpty ? null : region;
  }

  /// Installs an isolated client for tests without contacting live services.
  @visibleForTesting
  static void initializeForTesting(SupabaseClient client) {
    _client = client;
    _isInitialized = true;
  }

  /// Reset for testing or re-initialization
  static void reset() {
    _client = null;
    _isInitialized = false;
    _sessionRecoveryInFlight = null;
    MyAccountSnapshot.invalidate();
  }

  static bool get _hasUsableConfig {
    const url = AppConfig.supabaseUrl;
    const anonKey = AppConfig.supabaseAnonKey;
    if (_looksPlaceholder(url) || _looksPlaceholder(anonKey)) return false;

    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return false;
    }
    if (kReleaseMode && parsed.scheme != 'https') return false;
    return true;
  }

  static bool _looksPlaceholder(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final upper = trimmed.toUpperCase();
    return upper.contains('YOUR_') ||
        upper.contains('YOUR-PROJECT') ||
        upper.contains('PLACEHOLDER') ||
        upper.contains('SUPABASE_URL') ||
        upper.contains('SUPABASE_ANON_KEY');
  }
}
