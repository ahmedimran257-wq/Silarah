// SILARAH - Firebase Cloud Messaging Service
//
// Handles FCM token lifecycle:
//   - Request notification permissions
//   - Obtain and save FCM registration token to Supabase
//   - Listen for token refresh events
//   - Delete token on logout / account deletion
//
// Replaces the OneSignal integration with a free, unlimited
// alternative using Firebase Cloud Messaging.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'operational_telemetry_service.dart';
import '../utils/notification_deep_link.dart';

class FcmService {
  FcmService._();
  static final instance = FcmService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  Future<void>? _initializeFuture;
  Future<void>? _pushRegistrationFuture;
  bool _pushAvailable = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;

  /// Device ID - persisted across sessions so the same device
  /// always overwrites its own token row (via UPSERT).
  String? _deviceId;

  /// Last registration the server acknowledged in this process. Login and
  /// initialization both save the current token, so an identical repeat is
  /// skipped instead of costing another RPC.
  String? _syncedRegistration;
  static const _pendingRegistrationKey = 'silarah_pending_fcm_registration_v1';
  static const _pendingRemovalKey = 'silarah_pending_fcm_removal_v1';

  /// Initializes tap and foreground-message handling without presenting a
  /// system permission dialog. Push authorization is deliberately deferred
  /// until an authenticated session exists.
  Future<void> initialize({bool requestPermission = false}) async {
    var future = _initializeFuture;
    if (future == null) {
      future = _initialize().catchError((Object error) {
        _initializeFuture = null;
        throw error;
      });
      _initializeFuture = future;
    }
    await future;
    if (requestPermission) await _enablePushRegistration();
  }

  Future<void> _initialize() async {
    if (!_hasUsableFirebaseConfig()) {
      _pushAvailable = false;
      debugPrint(
        '[FcmService] Firebase config is missing or placeholder; push registration disabled.',
      );
      return;
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle notification taps when app is in background
    await _messageOpenedSub?.cancel();
    _messageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Foreground pushes should refresh in-app state immediately. Android does
    // not show system banners for foreground FCM by default, so the app uses
    // Supabase realtime plus this callback for a reliable visible inbox badge.
    await _foregroundMessageSub?.cancel();
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) {
      _onForegroundMessage?.call(message);
    });

    // Handle notification that launched the app from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _enablePushRegistration() async {
    if (!_hasUsableFirebaseConfig()) {
      _pushAvailable = false;
      return;
    }

    var future = _pushRegistrationFuture;
    if (future == null) {
      future = _registerForPush().catchError((Object error) {
        _pushRegistrationFuture = null;
        throw error;
      });
      _pushRegistrationFuture = future;
    }
    await future;
  }

  Future<void> _registerForPush() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FcmService] Notification permissions denied by user.');
      _pushAvailable = false;
      return;
    }

    _pushAvailable = true;
    debugPrint(
      '[FcmService] Notification permissions: '
      '${settings.authorizationStatus}',
    );

    _deviceId = await _getOrCreateDeviceId();
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToSupabase(token);
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FcmService] FCM token refreshed.');
      await _saveTokenToSupabase(newToken);
    });
  }

  /// Save (upsert) the FCM token to the user_fcm_tokens table in Supabase.
  /// This is only meaningful when a user is logged in.
  Future<void> _saveTokenToSupabase(String token) async {
    if (!SupabaseService.isInitialized) {
      debugPrint(
          '[FcmService] Supabase not initialized - skipping token save.');
      return;
    }

    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      debugPrint(
          '[FcmService] No active session - token will be saved on login.');
      return;
    }

    _deviceId ??= await _getOrCreateDeviceId();

    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    final registration = '${session.user.id}|$platform|${_deviceId!}|$token';
    if (_syncedRegistration == registration) return;

    try {
      await SupabaseService.client.rpc('register_my_fcm_token', params: {
        'p_device_id': _deviceId,
        'p_fcm_token': token,
        'p_platform': platform,
      });
      _syncedRegistration = registration;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingRegistrationKey);
      debugPrint('[FcmService] Push registration synchronized.');
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingRegistrationKey,
        '$platform|${_deviceId!}|$token',
      );
      debugPrint('[FcmService] Push registration queued for retry.');
    }
  }

  /// Called after successful authentication to ensure the token
  /// is linked to the authenticated user.
  Future<void> onUserLogin() async {
    await _flushPendingTokenOperations();
    try {
      await initialize(requestPermission: true);
    } catch (e) {
      debugPrint('[FcmService] Failed to initialize after login: $e');
      return;
    }

    if (!_pushAvailable) {
      debugPrint('[FcmService] Push unavailable; skipping login token save.');
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToSupabase(token);
    }
  }

  /// Called on logout or account deletion.
  /// Deletes the FCM token row to prevent ghost push notifications.
  Future<void> onUserLogout() async {
    _syncedRegistration = null;
    try {
      await _unregisterFromServer();
    } finally {
      // Always retire this device's token, even when the session is already
      // gone (remote sign-out, revoked session, ban) or the server call
      // failed: the old token stops working, so pushes for the signed-out
      // account can never reach this phone. The next sign-in registers a
      // fresh token.
      await _discardDeviceToken();
    }
  }

  Future<void> _discardDeviceToken() async {
    _pushRegistrationFuture = null;
    if (!_hasUsableFirebaseConfig()) return;
    try {
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('[FcmService] Device token not deleted: $error');
    }
  }

  Future<void> _unregisterFromServer() async {
    if (!SupabaseService.isInitialized || _deviceId == null) return;

    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return;

    try {
      await SupabaseService.client.rpc(
        'unregister_my_fcm_token',
        params: {'p_device_id': _deviceId},
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingRemovalKey);
      debugPrint('[FcmService] FCM token deleted from Supabase.');
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingRemovalKey,
        '${session.user.id}|${_deviceId!}',
      );
      debugPrint('[FcmService] Push removal queued for retry.');
      OperationalTelemetryService.record('push', 'token_removal_deferred');
    }
  }

  Future<void> _flushPendingTokenOperations() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final removal = prefs.getString(_pendingRemovalKey);
    final removalParts = removal?.split('|') ?? const <String>[];
    if (removalParts.length == 2 &&
        removalParts[0] == SupabaseService.currentUserId) {
      try {
        await SupabaseService.client.rpc(
          'unregister_my_fcm_token',
          params: {'p_device_id': removalParts[1]},
        );
        await prefs.remove(_pendingRemovalKey);
      } catch (_) {
        debugPrint('[FcmService] Pending push removal will retry later.');
        OperationalTelemetryService.record(
          'push',
          'pending_token_removal_failed',
        );
      }
    }
    final pending = prefs.getString(_pendingRegistrationKey);
    if (pending == null) return;
    final parts = pending.split('|');
    if (parts.length != 3) {
      await prefs.remove(_pendingRegistrationKey);
      return;
    }
    _deviceId = parts[1];
    try {
      await SupabaseService.client.rpc('register_my_fcm_token', params: {
        'p_device_id': parts[1],
        'p_fcm_token': parts[2],
        'p_platform': parts[0],
      });
      await prefs.remove(_pendingRegistrationKey);
    } catch (_) {
      debugPrint('[FcmService] Pending push registration will retry later.');
      OperationalTelemetryService.record(
        'push',
        'pending_token_registration_failed',
      );
    }
  }

  /// This phone's persistent id, the one its push registration uses (call
  /// ringing capability is reported under the same id).
  Future<String> deviceId() => _getOrCreateDeviceId();

  /// Get or create a persistent device ID stored in SharedPreferences.
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('silarah_device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('silarah_device_id', deviceId);
    }
    return deviceId;
  }

  bool _hasUsableFirebaseConfig() {
    try {
      final options = Firebase.app().options;
      return !_looksMissingOrPlaceholder(options.projectId) &&
          !_looksMissingOrPlaceholder(options.appId) &&
          !_looksMissingOrPlaceholder(options.messagingSenderId) &&
          !_looksMissingOrPlaceholder(options.apiKey);
    } catch (_) {
      return false;
    }
  }

  bool _looksMissingOrPlaceholder(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return true;
    final upper = normalized.toUpperCase();
    return upper.startsWith('YOUR_') ||
        upper.contains('PLACEHOLDER') ||
        upper.contains('FIREBASE_');
  }

  Function(String path)? _onNotificationTap;
  void Function(RemoteMessage message)? _onForegroundMessage;
  String? _pendingNotificationPath;

  set onNotificationTap(Function(String path)? callback) {
    _onNotificationTap = callback;
    if (callback != null && _pendingNotificationPath != null) {
      callback(_pendingNotificationPath!);
      _pendingNotificationPath = null;
    }
  }

  set onForegroundMessage(void Function(RemoteMessage message)? callback) {
    _onForegroundMessage = callback;
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FcmService] Notification tapped: ${message.data}');
    final type = message.data['type'] as String?;
    final path = notificationDestinationPath(
      type: type,
      deepLink: message.data['deep_link'] as String?,
      matchId: message.data['match_id'] as String?,
      profileId: message.data['owner_user_id'] as String?,
    );

    if (path != null) {
      if (_onNotificationTap != null) {
        _onNotificationTap!(path);
      } else {
        _pendingNotificationPath = path;
      }
    }
  }

  /// Dispose resources.
  void dispose() {
    _tokenRefreshSub?.cancel();
    _messageOpenedSub?.cancel();
    _foregroundMessageSub?.cancel();
  }
}
