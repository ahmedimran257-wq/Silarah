// SILARAH — Interests Cubit (Supabase production flow)
//
//   accept → ACCEPTED + match created (DB trigger)
//   decline → DECLINED
//   14 days → EXPIRED (DB cron job)
//
// Real mode: all operations hit Supabase interests/matches tables.
// Production mode: all operations hit Supabase.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'interests_state.dart';
import '../../models/discovery_profile.dart';
import '../../services/supabase_service.dart';
import '../../services/relationship_revision_service.dart';
import '../../services/profile_photo_service.dart';
import '../../services/authorized_profile_service.dart';
import '../../utils/content_filter.dart';
import '../../utils/silarah_compute.dart';

class _InterestQuota {
  const _InterestQuota({
    required this.sentToday,
    required this.dailyLimit,
    required this.isPremium,
    required this.resetsAt,
  });

  final int sentToday;
  final int dailyLimit;
  final bool isPremium;
  final DateTime resetsAt;
}

class InterestsCubit extends Cubit<InterestsState> {
  InterestsCubit() : super(const InterestsState());

  bool _loadInFlight = false;
  bool _forceReloadQueued = false;
  DateTime? _lastLoadedAt;
  String? _loadedUserId;
  String? _loadedRelationshipRevision;
  DateTime? _lastRelationshipRevisionCheckAt;
  static const _freshness = Duration(minutes: 5);
  static const _revisionCheckFreshness = Duration(seconds: 90);
  static const _maxRowsPerSection = 100;

  // Profiles with a send_interest request on the wire. A double tap, or two
  // screens sending to the same member, must not send a second request that
  // the database rejects and the screen reports as a failure.
  final Set<String> _sendsInFlight = <String>{};

  /// Whether an interest to [profileId] is being sent right now.
  bool isSendingInterest(String profileId) =>
      _sendsInFlight.contains(profileId);

  /// Server errors meaning the pair already has a pending interest or a
  /// match, so this screen is out of date rather than the send having failed.
  @visibleForTesting
  static bool isRelationshipAlreadyActive(Object error) {
    final message = error.toString();
    return message.contains('interest_already_active') ||
        message.contains('already_matched') ||
        message.contains('interest_already_exists') ||
        message.contains('already sent');
  }

  /// The interest was already answered, withdrawn or expired elsewhere (a
  /// second device, or the sender withdrawing at the same moment).
  static bool _isInterestUnavailable(Object error) =>
      error.toString().contains('interest_unavailable');

  // Init
  Future<void> loadData({bool force = false}) async {
    if (!SupabaseService.isInitialized) return;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    if (_loadInFlight) {
      if (force) _forceReloadQueued = true;
      return;
    }
    final lastLoadedAt = _lastLoadedAt;
    if (!force &&
        _loadedUserId == userId &&
        lastLoadedAt != null &&
        DateTime.now().difference(lastLoadedAt) < _freshness) {
      return;
    }
    _loadInFlight = true;
    final revisionAtStart = RelationshipRevisionService.readToken();
    try {
      await _loadFromDb();
      _loadedUserId = userId;
      _lastLoadedAt = DateTime.now();
      _loadedRelationshipRevision = await revisionAtStart;
      _lastRelationshipRevisionCheckAt = DateTime.now();
    } finally {
      _loadInFlight = false;
      if (_forceReloadQueued && !isClosed) {
        _forceReloadQueued = false;
        unawaited(loadData(force: true));
      }
    }
  }

  /// Reconciles this surface using a tiny relationship token. A full reload is
  /// retained as a five-minute fallback for quota/subscription changes that do
  /// not alter an interest or match row.
  Future<void> refreshIfChanged({bool forceCheck = false}) async {
    if (!SupabaseService.isInitialized) return;
    if (_loadInFlight) {
      if (forceCheck) _forceReloadQueued = true;
      return;
    }
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final loadedAt = _lastLoadedAt;
    if (_loadedUserId != userId || loadedAt == null) {
      await loadData();
      return;
    }
    if (DateTime.now().difference(loadedAt) >= _freshness) {
      await loadData();
      return;
    }

    final checkedAt = _lastRelationshipRevisionCheckAt;
    if (!forceCheck &&
        checkedAt != null &&
        DateTime.now().difference(checkedAt) < _revisionCheckFreshness) {
      return;
    }

    _lastRelationshipRevisionCheckAt = DateTime.now();
    final serverRevision = await RelationshipRevisionService.readToken();
    if (serverRevision == null || isClosed) return;
    if (_loadedRelationshipRevision == serverRevision) return;
    await loadData(force: true);
  }

  /// Load interests, sent interests, and matches from Supabase.
  Future<void> _loadFromDb() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (!isClosed) emit(const InterestsState());
      return;
    }

    // Quota and relationship rows are independent reads. Starting them
    // together removes one network round trip from the visible inbox load, and
    // a quota outage no longer hides genuine received interests.
    final quotaFuture = _loadServerQuotaOrNull();

    try {
      final now = DateTime.now();

      // Fetch the three bounded relationship sections concurrently. Profiles
      // and photos are batch-loaded below, avoiding the former 3-5 queries per
      // row. Quota is handled independently so a relationship read failure can
      // never be misreported as a daily-allowance failure.
      final results = await Future.wait<dynamic>([
        SupabaseService.client
            .from('interests')
            .select('id, sender_id, note, status, created_at, expires_at')
            .eq('receiver_id', userId)
            .inFilter('status', ['pending', 'accepted', 'declined', 'expired'])
            .order('created_at', ascending: false)
            .limit(_maxRowsPerSection),
        SupabaseService.client
            .from('interests')
            .select('id, receiver_id, note, status, created_at, expires_at')
            .eq('sender_id', userId)
            .inFilter('status',
                ['pending', 'accepted', 'declined', 'withdrawn', 'expired'])
            .order('created_at', ascending: false)
            .limit(_maxRowsPerSection),
        SupabaseService.client.rpc(
          'get_my_matches',
          params: {'p_limit': _maxRowsPerSection},
        ),
      ]);
      final quota = await quotaFuture;

      final receivedRows = results[0] as List<dynamic>;
      final sentRows = results[1] as List<dynamic>;
      final matchRows = (results[2] as List<dynamic>)
          .where((row) => (row as Map)['status'] == 'active')
          .toList(growable: false);
      final relatedUserIds = <String>{
        for (final row in receivedRows) row['sender_id'] as String,
        for (final row in sentRows) row['receiver_id'] as String,
        for (final row in matchRows)
          (row['user_a'] as String) == userId
              ? row['user_b'] as String
              : row['user_a'] as String,
      };
      final profilesByUser = await _loadProfilesForUsers(relatedUserIds);

      final received = <InterestEntry>[];
      for (final row in receivedRows) {
        final senderId = row['sender_id'] as String;
        final profile = profilesByUser[senderId];
        if (profile == null) continue;
        final createdAt = DateTime.tryParse(row['created_at'] as String) ?? now;

        received.add(InterestEntry(
          id: row['id'] as String,
          profile: profile,
          timeAgo: _timeAgoString(createdAt),
          sentAt: createdAt,
          createdAt: createdAt,
          serverExpiresAt:
              DateTime.tryParse(row['expires_at']?.toString() ?? '')?.toLocal(),
          status: _parseStatus(row['status'] as String),
          note: row['note'] as String?,
        ));
      }

      final sent = <InterestEntry>[];
      for (final row in sentRows) {
        final receiverId = row['receiver_id'] as String;
        final profile = profilesByUser[receiverId];
        if (profile == null) continue;
        final createdAt = DateTime.tryParse(row['created_at'] as String) ?? now;
        final statusStr = row['status'] as String;

        sent.add(InterestEntry(
          id: row['id'] as String,
          profile: profile,
          timeAgo: _timeAgoString(createdAt),
          sentAt: createdAt,
          createdAt: createdAt,
          serverExpiresAt:
              DateTime.tryParse(row['expires_at']?.toString() ?? '')?.toLocal(),
          status: _parseStatus(statusStr),
          note: row['note'] as String?,
        ));
      }

      final matches = <InterestEntry>[];
      for (final row in matchRows) {
        final otherUserId = (row['user_a'] as String) == userId
            ? row['user_b'] as String
            : row['user_a'] as String;
        final profile = profilesByUser[otherUserId];
        if (profile == null) continue;
        final createdAt = DateTime.tryParse(row['created_at'] as String) ?? now;

        matches.add(InterestEntry(
          id: row['id'] as String,
          profile: profile,
          timeAgo: _timeAgoString(createdAt),
          sentAt: createdAt,
          createdAt: createdAt,
          status: InterestStatus.accepted,
        ));
      }

      if (!isClosed) {
        emit(InterestsState(
          received: received,
          sent: sent,
          matches: matches,
          interestsSentToday: quota?.sentToday ?? state.interestsSentToday,
          dailyLimit: quota?.dailyLimit ?? state.dailyLimit,
          lastResetDate: quota == null ? state.lastResetDate : now,
          quotaResetsAt: quota?.resetsAt ?? state.quotaResetsAt,
          isPremium: quota?.isPremium ?? state.isPremium,
          quotaUnavailable: quota == null,
        ));
      }
    } catch (e) {
      debugPrint('[InterestsCubit] Error loading from DB: $e');
      final quota = await quotaFuture;
      if (!isClosed) {
        emit(state.copyWith(
          interestsSentToday: quota?.sentToday ?? state.interestsSentToday,
          dailyLimit: quota?.dailyLimit ?? state.dailyLimit,
          lastResetDate: quota == null ? state.lastResetDate : DateTime.now(),
          quotaResetsAt: quota?.resetsAt ?? state.quotaResetsAt,
          isPremium: quota?.isPremium ?? state.isPremium,
          quotaUnavailable: quota == null,
          clearQuotaUnavailable: quota != null,
        ));
      }
    }
  }

  Future<_InterestQuota?> _loadServerQuotaOrNull() async {
    try {
      return await _loadServerQuota();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, DiscoveryProfile>> _loadProfilesForUsers(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};
    // Each authorization RPC deliberately accepts at most 50 owners. Keep the
    // server-side safety bound, while covering every relationship row returned
    // by the three 100-row inbox sections instead of silently dropping owners
    // after the first batch.
    final userIdBatches = _batches(userIds, 50);
    final profileBatchResults = await Future.wait(
      userIdBatches.map(AuthorizedProfileService.load),
    );
    final mappedRows = profileBatchResults.expand((rows) => rows).toList();
    final profileIds = mappedRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    final photoBatchResults = profileIds.isEmpty
        ? const <List<dynamic>>[]
        : await Future.wait(
            _batches(profileIds, 50).map(
              (batch) => SupabaseService.client
                  .from('photos')
                  .select('profile_id, blurhash')
                  .inFilter('profile_id', batch)
                  .eq('status', 'active')
                  .eq('admin_approved', true)
                  .eq('nsfw_cleared', true)
                  .order('order_index'),
            ),
          );
    final photos = photoBatchResults.expand((rows) => rows);
    final photosByProfile = <String, List<Map<String, dynamic>>>{};
    for (final raw in photos) {
      final photo = Map<String, dynamic>.from(raw as Map);
      final profileId = photo['profile_id']?.toString();
      if (profileId != null) {
        photosByProfile.putIfAbsent(profileId, () => []).add(photo);
      }
    }
    final photoOwners = mappedRows
        .where(
            (row) => photosByProfile[row['id']?.toString()]?.isNotEmpty == true)
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    final signedUrlBatchResults = await Future.wait(
      _batches(photoOwners, 50).map(
        (batch) => ProfilePhotoService.instance.getAuthorizedPhotoUrls(
          ownerUserIds: batch,
        ),
      ),
    );
    final signedUrls = <String, String>{
      for (final batch in signedUrlBatchResults) ...batch,
    };

    final result = <String, DiscoveryProfile>{};
    for (final row in mappedRows) {
      final userId = row['user_id']?.toString();
      if (userId == null) continue;
      final profilePhotos = photosByProfile[row['id']?.toString()] ?? const [];
      row['photo_count'] = profilePhotos.length;
      row['photo_url'] = signedUrls[userId];
      if (profilePhotos.isNotEmpty) {
        row['blurhash'] = profilePhotos.first['blurhash'];
      }
      try {
        result[userId] = mapDbRowToDiscoveryProfile(row);
      } catch (error) {
        debugPrint('[InterestsCubit] Invalid profile $userId: $error');
      }
    }
    return result;
  }

  static List<List<T>> _batches<T>(Iterable<T> values, int size) {
    final batches = <List<T>>[];
    var current = <T>[];
    for (final value in values) {
      current.add(value);
      if (current.length == size) {
        batches.add(current);
        current = <T>[];
      }
    }
    if (current.isNotEmpty) batches.add(current);
    return batches;
  }

  void setDailyLimitForGender({
    required String gender,
    required bool isSubscribed,
  }) {
    refreshQuota();
  }

  void setDailyLimit(int limit) {
    refreshQuota();
  }

  Future<void> refreshQuota() async {
    _InterestQuota quota;
    try {
      quota = await _loadServerQuota();
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(
        interestsSentToday: 0,
        dailyLimit: 0,
        quotaUnavailable: true,
      ));
      return;
    }
    if (isClosed) return;
    emit(state.copyWith(
      interestsSentToday: quota.sentToday,
      dailyLimit: quota.dailyLimit,
      lastResetDate: DateTime.now(),
      quotaResetsAt: quota.resetsAt,
      isPremium: quota.isPremium,
      clearQuotaUnavailable: true,
    ));
  }

  Future<_InterestQuota> _loadServerQuota() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      throw StateError('Interest quota requires an authenticated session.');
    }
    try {
      final response = await SupabaseService.client.rpc('get_interest_quota');
      final rows = response as List<dynamic>;
      if (rows.isEmpty) {
        throw StateError('Interest quota response was empty.');
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      final sentToday = (row['sent_today'] as num?)?.toInt();
      final dailyLimit = (row['daily_limit'] as num?)?.toInt();
      final resetsAt = DateTime.tryParse(row['resets_at']?.toString() ?? '');
      final isPremium = row['is_premium'] == true;
      if (sentToday == null || dailyLimit == null || resetsAt == null) {
        throw StateError('Interest quota response was incomplete.');
      }
      return _InterestQuota(
        sentToday: sentToday,
        dailyLimit: dailyLimit,
        isPremium: isPremium,
        resetsAt: resetsAt.toLocal(),
      );
    } catch (e) {
      debugPrint('[InterestsCubit] Error loading daily quota: $e');
      throw StateError('Unable to verify your daily interest limit.');
    }
  }

  /// Refreshes the authoritative allowance before opening a composer or note
  /// sheet. A still-valid quota snapshot is reused; the send_interest RPC is
  /// the authoritative security boundary and rejects stale or concurrent use.
  Future<bool> canStartInterest() async {
    final resetsAt = state.quotaResetsAt;
    if (!state.quotaUnavailable &&
        state.dailyLimit > 0 &&
        resetsAt != null &&
        resetsAt.isAfter(DateTime.now())) {
      final allowed = state.interestsSentToday < state.dailyLimit;
      if (!isClosed) {
        emit(state.copyWith(
          limitError: !allowed,
          clearQuotaUnavailable: true,
        ));
      }
      return allowed;
    }

    try {
      final quota = await _loadServerQuota();
      if (isClosed) return false;
      emit(state.copyWith(
        interestsSentToday: quota.sentToday,
        dailyLimit: quota.dailyLimit,
        quotaResetsAt: quota.resetsAt,
        isPremium: quota.isPremium,
        limitError: quota.sentToday >= quota.dailyLimit,
        clearQuotaUnavailable: true,
      ));
      return quota.sentToday < quota.dailyLimit;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(quotaUnavailable: true));
      return false;
    }
  }

  // Received actions
  /// Accept an incoming interest → creates a match (via DB trigger).
  Future<bool> acceptInterest(String id) async {
    if (!SupabaseService.isInitialized) return false;

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.rpc('respond_to_interest', params: {
          'p_interest_id': id,
          'p_decision': 'accepted',
        });
        // DB trigger create_match_on_accept() automatically creates the match row
      } catch (e) {
        debugPrint('[InterestsCubit] Error accepting interest: $e');
        if (_isInterestUnavailable(e)) {
          // Show the server's answer: accepted elsewhere is still a match.
          await loadData(force: true);
          return state.matches.any((entry) => entry.id == id);
        }
        return false;
      }
    }

    final updated = List<InterestEntry>.from(state.received);
    final idx = updated.indexWhere((e) => e.id == id);
    if (idx == -1) {
      await loadData(force: true);
      return state.matches.any((entry) => entry.id == id);
    }

    final accepted = updated[idx].copyWith(status: InterestStatus.accepted);
    updated[idx] = accepted;

    final updatedMatches = List<InterestEntry>.from(state.matches)
      ..add(accepted);

    emit(state.copyWith(received: updated, matches: updatedMatches));
    return true;
  }

  /// Decline an incoming interest.
  Future<bool> declineInterest(String id) async {
    if (!SupabaseService.isInitialized) return false;

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.rpc('respond_to_interest', params: {
          'p_interest_id': id,
          'p_decision': 'declined',
        });
      } catch (e) {
        debugPrint('[InterestsCubit] Error declining interest: $e');
        if (_isInterestUnavailable(e)) await loadData(force: true);
        return false;
      }
    }

    final updated = List<InterestEntry>.from(state.received);
    final idx = updated.indexWhere((e) => e.id == id);
    if (idx == -1) return false;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.declined);
    emit(state.copyWith(received: updated));
    return true;
  }

  // Sent actions
  /// Send an interest from the discovery feed or profile detail.
  Future<bool> sendInterest(DiscoveryProfile profile, {String? note}) async {
    if (!SupabaseService.isInitialized) return false;

    // One active relationship owns this pair. Repeated interests would be
    // spam and are also rejected by the database constraint.
    if (state.interactionWith(profile.id) != ProfileInteractionState.none) {
      return false;
    }
    // A second tap while the first send is on the wire is not a new send.
    if (!_sendsInFlight.add(profile.id)) return false;
    try {
      return await _sendInterest(profile, note: note);
    } finally {
      _sendsInFlight.remove(profile.id);
    }
  }

  Future<bool> _sendInterest(DiscoveryProfile profile, {String? note}) async {
    final now = DateTime.now();
    final filteredNote =
        note?.isNotEmpty == true ? ContentFilter.redact(note!) : null;

    String? interestId;

    final myId = SupabaseService.currentUserId;
    if (myId == null) return false;
    try {
      final result = await SupabaseService.client.rpc('send_interest', params: {
        'p_receiver_id': profile.id,
        'p_note': filteredNote,
      });
      interestId = result?.toString();
    } catch (e) {
      debugPrint('[InterestsCubit] Error sending interest: $e');
      // If the DB rejects (e.g., daily limit hit by trigger), surface the error.
      if (e.toString().contains('interest_quota_exhausted') ||
          e.toString().contains('Daily interest limit')) {
        try {
          final quota = await _loadServerQuota();
          if (!isClosed) {
            emit(state.copyWith(
              interestsSentToday: quota.sentToday,
              dailyLimit: quota.dailyLimit,
              quotaResetsAt: quota.resetsAt,
              isPremium: quota.isPremium,
              limitError: true,
              clearQuotaUnavailable: true,
            ));
          }
        } catch (_) {
          if (!isClosed) emit(state.copyWith(limitError: true));
        }
        return false;
      }
      // Refresh stale UI when the server already owns this relationship. A
      // duplicate is not a new successful send and must not replay ceremony.
      if (isRelationshipAlreadyActive(e)) {
        await loadData(force: true);
        return false;
      }
      return false;
    }

    if (interestId == null || interestId.isEmpty) return false;

    final entry = InterestEntry(
      id: interestId,
      profile: profile,
      timeAgo: 'Just now',
      sentAt: now,
      createdAt: now,
      status: InterestStatus.pending,
      note: filteredNote,
    );

    final updated = [entry, ...state.sent];
    // The server has committed the write and its quota trigger. Reflect that
    // result immediately instead of delaying the card for another quota RPC.
    // Multi-device drift is corrected by the next cached-quota expiry or a
    // server rejection; it can never bypass the database limit.
    emit(state.copyWith(
      sent: updated,
      interestsSentToday: state.interestsSentToday + 1,
      lastResetDate: now,
      clearLimitError: true,
      clearQuotaUnavailable: true,
    ));
    return true;
  }

  void clearLimitError() {
    emit(state.copyWith(clearLimitError: true));
  }

  void clearQuotaUnavailable() {
    emit(state.copyWith(clearQuotaUnavailable: true));
  }

  void clear() {
    _loadInFlight = false;
    _forceReloadQueued = false;
    _lastLoadedAt = null;
    _loadedUserId = null;
    if (!isClosed) emit(const InterestsState());
  }

  /// Immediately removes a match that this device just closed. The next
  /// relationship revision reconciliation remains the server-authoritative
  /// fallback for other devices and background changes.
  void markMatchClosed(String matchId) {
    final activeMatches = state.matches
        .where((entry) => entry.id != matchId)
        .toList(growable: false);
    if (activeMatches.length == state.matches.length || isClosed) return;
    emit(state.copyWith(matches: activeMatches));
  }

  /// Withdraw a pending sent interest (silent — no notification to recipient).
  Future<bool> withdrawInterest(String id) async {
    if (!SupabaseService.isInitialized) return false;

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .rpc('withdraw_interest', params: {'p_interest_id': id});
      } catch (e) {
        debugPrint('[InterestsCubit] Error withdrawing interest: $e');
        if (_isInterestUnavailable(e)) await loadData(force: true);
        return false;
      }
    }

    final updated = List<InterestEntry>.from(state.sent);
    final idx = updated.indexWhere((e) => e.id == id);
    if (idx == -1) return false;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.withdrawn);
    emit(state.copyWith(sent: updated));
    return true;
  }

  // Helpers
  InterestStatus _parseStatus(String s) {
    switch (s) {
      case 'pending':
        return InterestStatus.pending;
      case 'accepted':
        return InterestStatus.accepted;
      case 'declined':
        return InterestStatus.declined;
      case 'expired':
        return InterestStatus.expired;
      case 'withdrawn':
        return InterestStatus.withdrawn;
      default:
        return InterestStatus.pending;
    }
  }

  String _timeAgoString(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
