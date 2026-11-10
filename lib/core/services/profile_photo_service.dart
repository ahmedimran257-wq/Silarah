import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_data.dart';
import 'photo_moderation_service.dart';
import 'my_account_snapshot.dart';
import 'supabase_service.dart';

enum PhotoSyncStage {
  safetyScan,
  preparingUpload,
  transferring,
  publishing,
  complete,
}

class PhotoSyncProgress {
  const PhotoSyncProgress({
    required this.slot,
    required this.completedPhotos,
    required this.totalPhotos,
    required this.stage,
  });

  final int slot;
  final int completedPhotos;
  final int totalPhotos;
  final PhotoSyncStage stage;

  double get fraction {
    if (totalPhotos == 0) return 1;
    if (stage == PhotoSyncStage.complete) {
      return (completedPhotos / totalPhotos).clamp(0.0, 1.0);
    }
    const stageWeight = <PhotoSyncStage, double>{
      PhotoSyncStage.safetyScan: 0.08,
      PhotoSyncStage.preparingUpload: 0.24,
      PhotoSyncStage.transferring: 0.46,
      PhotoSyncStage.publishing: 0.78,
      PhotoSyncStage.complete: 1,
    };
    return ((completedPhotos + stageWeight[stage]!) / totalPhotos)
        .clamp(0.0, 1.0);
  }
}

typedef PhotoSyncProgressCallback = void Function(PhotoSyncProgress progress);

class ProfilePhotoService {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();
  static const _bucket = 'profile-photos';
  static const _signedUrlSafetyMargin = Duration(seconds: 30);
  static const _maxCachedUrls = 200;
  final Map<String, _CachedPhotoUrl> _readUrlCache = {};
  final Map<String, Future<String?>> _readUrlLoads = {};

  void invalidateAllPhotoUrls() {
    _readUrlCache.clear();
    _readUrlLoads.clear();
  }

  Future<PhotoPrivacy> getMyPhotoPrivacy() async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) {
      throw StateError('Please sign in again to manage your photos.');
    }
    final row = await MyAccountSnapshot.instance.profile(userId);
    return switch (row?['photo_privacy']?.toString()) {
      'mutual_only' => PhotoPrivacy.mutualOnly,
      'request_only' => PhotoPrivacy.requestOnly,
      _ => PhotoPrivacy.publicAll,
    };
  }

  Future<PhotoModerationResult?> syncLocalPhotos(
    List<String> localPaths, {
    PhotoPrivacy privacy = PhotoPrivacy.publicAll,
  }) async {
    return syncPhotoSlots(
      {
        for (var i = 0; i < localPaths.length && i < 4; i++) i: localPaths[i],
      },
      privacy: privacy,
    );
  }

  /// Uploads only the slots that changed while preserving their real indexes.
  ///
  /// The photo manager can contain gaps (for example slots 0 and 2). Passing a
  /// compact list would accidentally move slot 2 into slot 1, so edit flows
  /// must use this explicit index map.
  Future<PhotoModerationResult?> syncPhotoSlots(
    Map<int, String> localPathsBySlot, {
    PhotoPrivacy privacy = PhotoPrivacy.publicAll,
    PhotoSyncProgressCallback? onProgress,
  }) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      throw StateError(
        'Profile photo upload is not available without an authenticated backend session.',
      );
    }

    if (await _currentProfileId() == null) {
      throw StateError('Profile must be saved before uploading photos.');
    }
    await SupabaseService.client.rpc(
      'set_my_photo_privacy',
      params: {'p_privacy': _privacyValue(privacy)},
    );

    PhotoModerationResult? primaryModeration;
    final slots = localPathsBySlot.entries
        .where((entry) => entry.key >= 0 && entry.key < 4)
        .toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    var completedPhotos = 0;
    for (final entry in slots) {
      final orderIndex = entry.key;
      final file = File(entry.value);
      if (!await file.exists()) continue;

      void report(PhotoSyncStage stage) => onProgress?.call(
            PhotoSyncProgress(
              slot: orderIndex,
              completedPhotos: completedPhotos,
              totalPhotos: slots.length,
              stage: stage,
            ),
          );

      // Scan again at the upload boundary so stale onboarding state cannot
      // bypass moderation. A failed scan is rejected rather than uploaded.
      report(PhotoSyncStage.safetyScan);
      final moderation =
          await PhotoModerationService.instance.scanFile(file.path);
      if (orderIndex == 0) primaryModeration = moderation;
      if (!moderation.canUpload) {
        throw StateError(
          moderation.decision == PhotoModerationDecision.rejected
              ? _moderationMessage(moderation)
              : 'Photo safety validation failed. Please choose another photo.',
        );
      }

      report(PhotoSyncStage.preparingUpload);
      final signed = await SupabaseService.client.functions.invoke(
        'get-signed-url',
        region: SupabaseService.functionsRegion,
        body: {
          'order_index': orderIndex,
          'file_extension': 'jpg',
        },
      );

      if (signed.status != 200 || signed.data is! Map) {
        throw StateError('Unable to prepare profile photo upload.');
      }

      final payload = Map<String, dynamic>.from(signed.data as Map);
      if (payload['action'] == 'already_pending') {
        completedPhotos += 1;
        report(PhotoSyncStage.complete);
        continue;
      }
      final storagePath = payload['storage_path'] as String?;
      final token = payload['token'] as String?;
      if (storagePath == null || token == null) {
        throw StateError('Profile photo upload response was incomplete.');
      }

      final bytes = await file.readAsBytes();
      report(PhotoSyncStage.transferring);
      try {
        await SupabaseService.client.storage
            .from(_bucket)
            .uploadBinaryToSignedUrl(
              storagePath,
              token,
              bytes,
              const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
      } catch (error) {
        debugPrint(
          '[ProfilePhotoService] transfer failed: ${error.runtimeType}',
        );
        throw StateError(
          'Photo transfer failed. Check your connection and try again.',
        );
      }

      report(PhotoSyncStage.publishing);
      await _validateUploaded(storagePath, moderation);
      completedPhotos += 1;
      report(PhotoSyncStage.complete);
    }
    _invalidateOwner(SupabaseService.currentUserId);
    return primaryModeration;
  }

  /// Returns the authenticated user's approved photos keyed by their persisted
  /// slot. Signed URLs are deliberately fetched fresh for this screen.
  Future<Map<int, String>> getMyPhotoSlots() async {
    if (!SupabaseService.isInitialized) return const {};
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) {
      throw StateError('Please sign in again to manage your photos.');
    }
    if (await _currentProfileId() == null) {
      throw StateError('Profile must be saved before managing photos.');
    }

    return getVisiblePhotoSlots(ownerUserId: userId);
  }

  /// Loads every photo the authenticated viewer is authorized to see for a
  /// profile, preserving the persisted slot order. Photo RLS remains the
  /// source of truth for public, mutual-only, and request-only galleries.
  Future<Map<int, String>> getVisiblePhotoSlots({
    required String ownerUserId,
  }) async {
    if (!SupabaseService.isInitialized || ownerUserId.trim().isEmpty) {
      return const {};
    }
    final viewerId = await SupabaseService.currentUserIdOrRefresh();
    if (viewerId == null) {
      throw StateError('Please sign in again to view profile photos.');
    }

    final response = await SupabaseService.client.functions.invoke(
      'get-signed-url',
      region: SupabaseService.functionsRegion,
      body: {
        'purpose': 'read_profile_gallery',
        'owner_user_id': ownerUserId,
      },
    );
    if (response.status != 200 || response.data is! Map) {
      throw StateError('Your photos could not be loaded securely. Try again.');
    }
    final payload = Map<String, dynamic>.from(response.data as Map);
    final slots = payload['slots'];
    if (slots is! Map) {
      throw StateError('Your photos could not be loaded securely. Try again.');
    }
    final result = <int, String>{};
    final expiresIn = (payload['expires_in'] as num?)?.toInt() ?? 300;
    for (final entry in slots.entries) {
      final orderIndex = int.tryParse(entry.key.toString());
      if (orderIndex == null || orderIndex < 0 || orderIndex > 3) continue;
      final url = entry.value?.toString();
      if (url == null || url.isEmpty) {
        continue;
      }
      _cacheUrl('$viewerId:$ownerUserId:$orderIndex', url, expiresIn);
      result[orderIndex] = url;
    }
    return result;
  }

  Future<void> deleteMyPhotoSlot(int orderIndex) async {
    if (orderIndex < 0 || orderIndex > 3) {
      throw ArgumentError.value(orderIndex, 'orderIndex');
    }
    if (await SupabaseService.currentUserIdOrRefresh() == null) {
      throw StateError('Please sign in again to manage your photos.');
    }
    final response = await SupabaseService.client.functions.invoke(
      'get-signed-url',
      region: SupabaseService.functionsRegion,
      body: {
        'purpose': 'delete_profile_photo',
        'order_index': orderIndex,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Could not remove this photo. Please try again.');
    }
    _invalidateOwner(SupabaseService.currentUserId);
  }

  Future<String?> getPrimaryPhotoUrl({bool forceRefresh = false}) async {
    if (!SupabaseService.isInitialized) return null;
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) return null;

    return getAuthorizedPhotoUrl(
      ownerUserId: userId,
      forceRefresh: forceRefresh,
    );
  }

  Future<String?> getAuthorizedPhotoUrl({
    required String ownerUserId,
    int orderIndex = 0,
    bool forceRefresh = false,
  }) async {
    if (!SupabaseService.isInitialized || ownerUserId.isEmpty) {
      return null;
    }
    final viewerId = await SupabaseService.currentUserIdOrRefresh();
    if (viewerId == null) return null;

    final cacheKey = '$viewerId:$ownerUserId:$orderIndex';
    if (!forceRefresh) {
      final cached = _readUrlCache[cacheKey];
      if (cached != null && cached.isUsable) return cached.url;
      final activeLoad = _readUrlLoads[cacheKey];
      if (activeLoad != null) return activeLoad;
    } else {
      _readUrlCache.remove(cacheKey);
    }

    final load = _loadAuthorizedPhotoUrl(
      cacheKey: cacheKey,
      ownerUserId: ownerUserId,
      orderIndex: orderIndex,
    );
    _readUrlLoads[cacheKey] = load;
    try {
      return await load;
    } finally {
      if (identical(_readUrlLoads[cacheKey], load)) {
        _readUrlLoads.remove(cacheKey);
      }
    }
  }

  Future<String?> _loadAuthorizedPhotoUrl({
    required String cacheKey,
    required String ownerUserId,
    required int orderIndex,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'get-signed-url',
      region: SupabaseService.functionsRegion,
      body: {
        'purpose': 'read_profile_photo',
        'owner_user_id': ownerUserId,
        'order_index': orderIndex,
      },
    );
    if (response.status != 200 || response.data is! Map) return null;
    final payload = Map<String, dynamic>.from(response.data as Map);
    final url = payload['signed_url'] as String?;
    if (url == null || url.isEmpty) return null;
    _cacheUrl(
      cacheKey,
      url,
      (payload['expires_in'] as num?)?.toInt() ?? 300,
    );
    return url;
  }

  Future<Map<String, String>> getAuthorizedPhotoUrls({
    required List<String> ownerUserIds,
    int orderIndex = 0,
  }) async {
    if (!SupabaseService.isInitialized || ownerUserIds.isEmpty) {
      return const {};
    }
    final viewerId = await SupabaseService.currentUserIdOrRefresh();
    if (viewerId == null) return const {};

    final uniqueOwnerIds = ownerUserIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(50)
        .toList(growable: false);
    if (uniqueOwnerIds.isEmpty) return const {};

    final result = <String, String>{};
    final missingOwnerIds = <String>[];
    for (final ownerId in uniqueOwnerIds) {
      final cached = _readUrlCache['$viewerId:$ownerId:$orderIndex'];
      if (cached != null && cached.isUsable) {
        result[ownerId] = cached.url;
      } else {
        missingOwnerIds.add(ownerId);
      }
    }
    if (missingOwnerIds.isEmpty) return result;

    final response = await SupabaseService.client.functions.invoke(
      'get-signed-url',
      region: SupabaseService.functionsRegion,
      body: {
        'purpose': 'read_profile_photos',
        'owner_user_ids': missingOwnerIds,
        'order_index': orderIndex,
      },
    );
    // Keep already-cached URLs usable when a partial batch refresh fails.
    // Returning an empty map here used to blank every card, including owners
    // whose signed URLs were still valid in the local cache.
    if (response.status != 200 || response.data is! Map) return result;

    final payload = Map<String, dynamic>.from(response.data as Map);
    final urls = payload['urls'];
    if (urls is! Map) return result;

    final loaded = urls.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    )..removeWhere((_, value) => value.isEmpty);
    final expiresIn = (payload['expires_in'] as num?)?.toInt() ?? 300;
    for (final entry in loaded.entries) {
      _cacheUrl(
        '$viewerId:${entry.key}:$orderIndex',
        entry.value,
        expiresIn,
      );
    }
    result.addAll(loaded);
    return result;
  }

  void _cacheUrl(String key, String url, int expiresInSeconds) {
    final safeSeconds = expiresInSeconds > _signedUrlSafetyMargin.inSeconds + 60
        ? expiresInSeconds - _signedUrlSafetyMargin.inSeconds
        : 60;
    final usableFor = Duration(
      seconds: safeSeconds,
    );
    _readUrlCache[key] = _CachedPhotoUrl(
      url: url,
      expiresAt: DateTime.now().add(usableFor),
    );
    _readUrlCache.removeWhere((_, value) => !value.isUsable);
    while (_readUrlCache.length > _maxCachedUrls) {
      _readUrlCache.remove(_readUrlCache.keys.first);
    }
  }

  void _invalidateOwner(String? ownerUserId) {
    if (ownerUserId == null) return;
    _readUrlCache.removeWhere(
      (key, _) => key.contains(':$ownerUserId:'),
    );
  }

  Future<String?> _currentProfileId() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    final profile = await MyAccountSnapshot.instance.profile(userId);

    return profile?['id'] as String?;
  }

  /// A failure here must not stop the upload; the server decides what an
  /// unverified device means.
  Future<String?> _appCheckToken() async {
    try {
      return await FirebaseAppCheck.instance
          .getToken()
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('[ProfilePhotoService] App Check unavailable: $error');
      return null;
    }
  }

  Future<void> _validateUploaded(
    String storagePath,
    PhotoModerationResult moderation,
  ) async {
    final appCheckToken = await _appCheckToken();
    final response = await SupabaseService.client.functions.invoke(
      'validate-photo-upload',
      region: SupabaseService.functionsRegion,
      headers: {
        if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
      },
      body: {
        'storage_path': storagePath,
        'moderation': moderation.toValidationPayload(),
      },
    );
    if ((response.status != 200 && response.status != 202) ||
        response.data is! Map) {
      debugPrint(
        '[ProfilePhotoService] validation rejected: HTTP ${response.status}',
      );
      throw StateError(
        response.status == 422
            ? 'The server could not decode this photo. Choose another image.'
            : 'Photo validation could not be completed. Please try again.',
      );
    }
    final action = (response.data as Map)['action'] as String?;
    if (action != 'active' && action != 'pending_review') {
      throw StateError('Photo validation did not accept this upload.');
    }
  }

  String _moderationMessage(PhotoModerationResult moderation) {
    if (moderation.category == 'invalid_image') {
      return 'Choose a valid photo file.';
    }
    if (moderation.category == 'explicit_content') {
      return "This photo can't be used. Silarah doesn't allow nudity or revealing photos.";
    }
    return 'This photo could not be safety checked. Please choose another image.';
  }

  String _privacyValue(PhotoPrivacy privacy) {
    switch (privacy) {
      case PhotoPrivacy.mutualOnly:
        return 'mutual_only';
      case PhotoPrivacy.requestOnly:
        return 'request_only';
      case PhotoPrivacy.publicAll:
        return 'public';
    }
  }
}

class _CachedPhotoUrl {
  const _CachedPhotoUrl({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;

  bool get isUsable => DateTime.now().isBefore(expiresAt);
}
