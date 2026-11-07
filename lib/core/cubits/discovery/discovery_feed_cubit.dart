// SILARAH — Discovery Feed Cubit (Step 6 — Filter-aware)
//
//   • Cursor-based pagination — no offset drift, no duplicates
//   • Every 10th profile: "Someone you might connect with"
//   • Free-tier counter
//   • Sect / Deen / Age / Verified / FamilyType filters applied by Supabase
//
// Filter persistence: active filter is saved to SharedPreferences
// so it survives app restarts.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../models/discovery_profile.dart';
import '../../services/my_account_snapshot.dart';
import '../../services/supabase_service.dart';
import '../../utils/perf_log.dart';
import '../../services/profile_write_service.dart';
import '../../services/location_service.dart';
import '../../services/profile_photo_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/launch_configuration_service.dart';
import '../../models/onboarding_data.dart';
import '../../utils/silarah_compute.dart';
import 'discovery_feed_state.dart';

class _ProfileViewQuota {
  const _ProfileViewQuota({
    required this.viewsToday,
    required this.dailyLimit,
  });

  final int viewsToday;
  final int dailyLimit;
}

class DiscoveryFeedCubit extends Cubit<DiscoveryFeedState> {
  DiscoveryFeedCubit() : super(const DiscoveryFeedState());

  // Each page otherwise repeats the database ranking and three bounded
  // enrichment calls. Twenty cards materially lowers requests per viewed
  // profile while staying below every batch RPC's 50-ID safety cap.
  static const _batchSize = 20;
  static const _kFilterKey = 'discovery_active_filter';

  double? _backendCursorScore;
  String? _backendCursorId;
  bool _discoveryLocationPrepared = false;
  int _requestVersion = 0;
  String? _readyViewerId;
  DateTime? _viewerReadyAt;
  String? _loadedRevisionToken;
  String? _pendingRevisionToken;
  DateTime? _lastRevisionCheckAt;
  String? _lastInventoryFingerprint;
  DateTime? _lastInventorySyncAt;
  static const _viewerReadinessFreshness = Duration(minutes: 10);
  bool _feedPageAvailable = true;
  static const _revisionCheckFreshness = Duration(seconds: 90);

  // Public API
  Future<OnboardingData?> _getViewerProfile() async {
    try {
      if (SupabaseService.isInitialized) {
        final dbData = await ProfileWriteService.loadProfile();
        if (dbData != null) return dbData;
      }
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: Error loading viewer profile: $e');
    }
    return null;
  }

  /// Initial page load — shows skeleton loaders first.
  /// Restores saved filters locally; browse quota always comes from Supabase.
  Future<void> loadInitial({bool force = false}) async {
    if (!force && state.status != FeedStatus.initial) return;
    final requestVersion = _nextRequestVersion();
    emit(state.copyWith(
      status:
          state.profiles.isEmpty ? FeedStatus.loading : FeedStatus.refreshing,
      clearFailure: true,
    ));

    perfMark('discovery: load start');
    // The saved filter is device-local. The viewer profile is only needed to
    // derive a first-run default, so returning members skip that network read.
    final launchLoad = LaunchConfigurationService.load();
    final savedFilter = await _loadFilterFromPrefs();
    final viewerProfile =
        savedFilter == null ? await _getViewerProfile() : null;
    final launch = await launchLoad;
    if (!_isCurrentRequest(requestVersion)) return;
    perfMark('discovery: filter ready (saved=${savedFilter != null})');
    DiscoveryFilter filter = savedFilter ?? state.activeFilter;

    if (savedFilter == null && viewerProfile != null) {
      filter = DiscoveryFilter(
        ageMin: viewerProfile.preferredAgeMin,
        ageMax: viewerProfile.preferredAgeMax,
        sect: viewerProfile.preferredSect != null &&
                viewerProfile.preferredSect != 'Any'
            ? viewerProfile.preferredSect
            : null,
        deenLevel: viewerProfile.preferredDeenLevel != null &&
                viewerProfile.preferredDeenLevel != 'Any'
            ? viewerProfile.preferredDeenLevel
            : null,
        diasporaMode:
            viewerProfile.locationPreference == LocationPreference.diaspora,
        distanceLabel:
            viewerProfile.locationPreference == LocationPreference.sameCity
                ? 'Same City'
                : (viewerProfile.locationPreference ==
                        LocationPreference.sameCountry
                    ? 'Same Country'
                    : 'Anywhere'),
      );
    }

    if (launch.isSingleCountry) {
      final legacyGlobalLabel = filter.distanceLabel == 'Same Country' ||
          filter.distanceLabel == 'Anywhere';
      filter = filter.copyWith(
        diasporaMode: false,
        clearDiasporaCountries: true,
        clearBrowseCountries: true,
        clearDistanceLabel: legacyGlobalLabel,
        clearMaxDistance: legacyGlobalLabel,
      );
    }

    try {
      filter = await _enforceLocationFilterAccess(filter);
      if (!_isCurrentRequest(requestVersion)) return;
      await _saveFilterToPrefs(filter);
      if (!_isCurrentRequest(requestVersion)) return;
      final currentUserId = await SupabaseService.currentUserIdOrRefresh();
      if (currentUserId == null) {
        throw StateError('Please sign in to view discovery profiles.');
      }

      // The daily quota only labels the UI; get_discovery_feed enforces the
      // limit itself, so the quota read runs beside the feed instead of in
      // front of it. The revision token arrives with the first page.
      final quotaLoad = _Outcome.of(_loadServerViewQuota());
      final pendingRevision = _pendingRevisionToken;
      _pendingRevisionToken = null;
      _lastRevisionCheckAt = DateTime.now();
      String? revisionAtStart = pendingRevision;
      _resetCursors();
      final profiles = await _getPool(
        filter: filter,
        requestVersion: requestVersion,
        onRevisionToken:
            pendingRevision == null ? (token) => revisionAtStart = token : null,
      );
      if (!_isCurrentRequest(requestVersion)) return;
      final quota = (await quotaLoad).valueOrThrow;
      if (!_isCurrentRequest(requestVersion)) return;
      perfMark('discovery: ${profiles.length} cards ready');
      final batch = _toFeedProfiles(profiles, offset: 0);
      if (!isClosed) {
        if (revisionAtStart != null) {
          _loadedRevisionToken = revisionAtStart;
        }
        emit(state.copyWith(
          status: batch.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
          profiles: batch,
          hasMore: profiles.length == _batchSize,
          activeFilter: filter,
          profilesViewedToday: quota.viewsToday,
          dailyLimit: quota.dailyLimit,
          clearFailure: true,
        ));
        unawaited(_recordDiscoveryInventory(
          filter,
          hasProfiles: batch.isNotEmpty,
        ));
      }
    } catch (e) {
      if (_isCurrentRequest(requestVersion)) await _emitDiscoveryError(e);
    }
  }

  /// Invalidates only viewer readiness when onboarding publishes a profile.
  /// This is an event-driven, once-per-signup handoff; normal tab changes keep
  /// using the inexpensive revision token instead of reloading the feed.
  Future<void> refreshAfterViewerPublication() async {
    // Approval is recorded by the server, so the shared account rows are
    // re-read rather than reused.
    MyAccountSnapshot.invalidate();
    _readyViewerId = null;
    _viewerReadyAt = null;
    _loadedRevisionToken = null;
    _pendingRevisionToken = null;
    _lastRevisionCheckAt = null;
    _lastInventoryFingerprint = null;
    _lastInventorySyncAt = null;

    if (isClosed || state.status == FeedStatus.initial) return;
    await loadInitial(force: true);
  }

  /// Reconciles quota, persisted Premium filters, and page inventory after the
  /// effective entitlement changes. Subscription state is deliberately not
  /// part of the shared discovery revision token, so a revision-only refresh
  /// would retain the old free/Premium page until another catalog mutation.
  Future<void> refreshForEntitlementChange() async {
    _loadedRevisionToken = null;
    _pendingRevisionToken = null;
    _lastRevisionCheckAt = null;

    if (isClosed || state.status == FeedStatus.initial) return;
    if (state.status == FeedStatus.loading ||
        state.status == FeedStatus.refreshing ||
        state.status == FeedStatus.loadingMore) {
      return;
    }
    await loadInitial(force: true);
  }

  /// Checks a tiny server revision and reloads only when discovery-relevant
  /// catalog or relationship state changed. Repeated tab taps and short
  /// background/resume cycles therefore do not re-query or re-sign the feed.
  Future<void> refreshIfChanged({bool forceCheck = false}) async {
    if (state.status == FeedStatus.initial) {
      await loadInitial();
      return;
    }
    if (state.status == FeedStatus.loading ||
        state.status == FeedStatus.refreshing ||
        state.status == FeedStatus.loadingMore) {
      return;
    }

    final checkedAt = _lastRevisionCheckAt;
    if (!forceCheck &&
        checkedAt != null &&
        DateTime.now().difference(checkedAt) < _revisionCheckFreshness) {
      return;
    }

    _lastRevisionCheckAt = DateTime.now();
    final serverToken = await _readDiscoveryRevisionToken(state.activeFilter);
    if (serverToken == null || isClosed) return;
    if (_loadedRevisionToken == serverToken) {
      if (state.status == FeedStatus.error) {
        await loadInitial(force: true);
      } else if (state.failureKind != null) {
        emit(state.copyWith(clearFailure: true));
      }
      return;
    }

    final loadedToken = _loadedRevisionToken;
    if (loadedToken != null &&
        state.profiles.isNotEmpty &&
        _catalogRevisionOf(loadedToken) == _catalogRevisionOf(serverToken)) {
      await _refreshRelationshipContext(serverToken);
      return;
    }

    _pendingRevisionToken = serverToken;
    await loadInitial(force: true);
  }

  String _catalogRevisionOf(String token) => token.split(':member=').first;

  /// Load next page (append).
  Future<void> loadMore() async {
    if (state.status == FeedStatus.loadingMore) return;
    if (!state.hasMore) return;

    final requestVersion = _nextRequestVersion();
    final baseProfiles = state.profiles;
    final filter = state.activeFilter;
    emit(state.copyWith(status: FeedStatus.loadingMore));
    try {
      final profiles =
          await _getPool(filter: filter, requestVersion: requestVersion);
      if (!_isCurrentRequest(requestVersion)) return;
      final batch = _toFeedProfiles(
        profiles,
        offset: baseProfiles.length,
      );
      if (!isClosed) {
        emit(state.copyWith(
          status: FeedStatus.loaded,
          profiles: [...baseProfiles, ...batch],
          hasMore: profiles.length == _batchSize,
          clearFailure: true,
        ));
      }
    } catch (e) {
      if (_isCurrentRequest(requestVersion)) {
        await _emitDiscoveryError(e, keepProfiles: true);
      }
    }
  }

  void clear() {
    _nextRequestVersion();
    _resetCursors();
    _discoveryLocationPrepared = false;
    _readyViewerId = null;
    _viewerReadyAt = null;
    _loadedRevisionToken = null;
    _pendingRevisionToken = null;
    _lastRevisionCheckAt = null;
    if (!isClosed) emit(const DiscoveryFeedState());
  }

  /// Apply new filters — resets the feed and reloads from cursor 0.
  Future<void> applyFilter(DiscoveryFilter filter) async {
    final requestVersion = _nextRequestVersion();
    final previousFilter = state.activeFilter;
    try {
      final effectiveFilter = await _enforceLocationFilterAccess(filter);
      if (!_isCurrentRequest(requestVersion)) return;
      emit(state.copyWith(
        status:
            state.profiles.isEmpty ? FeedStatus.loading : FeedStatus.refreshing,
        activeFilter: effectiveFilter,
        clearFailure: true,
      ));

      // Persist only the server-authorized filter. This prevents an expired
      // Premium scope from breaking discovery on every subsequent launch.
      await _saveFilterToPrefs(effectiveFilter);
      if (!_isCurrentRequest(requestVersion)) return;

      String? revisionAtStart;
      _lastRevisionCheckAt = DateTime.now();
      _resetCursors();
      final profiles = await _getPool(
        filter: effectiveFilter,
        requestVersion: requestVersion,
        onRevisionToken: (token) => revisionAtStart = token,
      );
      if (!_isCurrentRequest(requestVersion)) return;
      final batch = _toFeedProfiles(profiles, offset: 0);
      if (!isClosed) {
        if (revisionAtStart != null) {
          _loadedRevisionToken = revisionAtStart;
        }
        emit(state.copyWith(
          status: batch.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
          profiles: batch,
          hasMore: profiles.length == _batchSize,
          clearFailure: true,
        ));
        unawaited(_recordDiscoveryInventory(
          effectiveFilter,
          hasProfiles: batch.isNotEmpty,
        ));
      }
    } catch (e) {
      if (_isCurrentRequest(requestVersion)) {
        await _saveFilterToPrefs(previousFilter);
        await _emitDiscoveryError(e, fallbackFilter: previousFilter);
      }
    }
  }

  /// Clear all filters and reload.
  Future<void> clearFilters() => applyFilter(DiscoveryFilter.empty);

  Future<bool> recordProfileView(String viewedUserId) async {
    if (!SupabaseService.isInitialized || viewedUserId.isEmpty) {
      return false;
    }
    final currentUserId = await SupabaseService.currentUserIdOrRefresh();
    if (currentUserId == null) return false;

    try {
      final response = await SupabaseService.client.rpc(
        'record_profile_view',
        params: {
          'p_viewed_user_id': viewedUserId,
          'p_notify_owner': false,
        },
      );
      final rows = response as List<dynamic>;
      final row = rows.isNotEmpty
          ? Map<String, dynamic>.from(rows.first as Map)
          : <String, dynamic>{};
      final allowed = row['allowed'] == true;
      if (!isClosed) {
        emit(state.copyWith(
          profilesViewedToday: (row['views_today'] as num?)?.toInt() ??
              state.profilesViewedToday,
          dailyLimit: (row['daily_limit'] as num?)?.toInt() ?? state.dailyLimit,
        ));
      }
      return allowed;
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: failed to record profile view: $e');
      return false;
    }
  }

  /// A new match unlocks "visible after acceptance" photos on the server,
  /// but cards already in the feed were built while they were locked. Fetch
  /// the now-authorised main photo for those members and unlock the card in
  /// place, without reloading the whole feed.
  Future<void> revealPhotosForMatches(Set<String> matchedUserIds) async {
    if (matchedUserIds.isEmpty || isClosed) return;
    final locked = state.profiles
        .where((entry) =>
            matchedUserIds.contains(entry.profile.id) &&
            entry.profile.photoUrl == null &&
            entry.profile.photoCount > 0)
        .map((entry) => entry.profile.id)
        .toSet();
    if (locked.isEmpty) return;
    final revealed = <String, String>{};
    for (final userId in locked) {
      try {
        final url = await ProfilePhotoService.instance.getAuthorizedPhotoUrl(
          ownerUserId: userId,
          forceRefresh: true,
        );
        if (url != null && url.isNotEmpty) revealed[userId] = url;
      } catch (error) {
        debugPrint('DiscoveryFeedCubit: photo reveal skipped: $error');
      }
    }
    if (revealed.isEmpty || isClosed) return;
    emit(state.copyWith(
      profiles: [
        for (final entry in state.profiles)
          revealed.containsKey(entry.profile.id)
              ? FeedProfile(
                  profile: entry.profile.copyWith(
                    photoUrl: revealed[entry.profile.id],
                    isPhotoPrivate: false,
                  ),
                  isWildCard: entry.isWildCard,
                  lastActiveAt: entry.lastActiveAt,
                )
              : entry,
      ],
    ));
  }

  Future<_ProfileViewQuota> _loadServerViewQuota() async {
    if (!SupabaseService.isInitialized) {
      throw StateError('Discovery quota requires an authenticated session.');
    }
    final currentUserId = await SupabaseService.currentUserIdOrRefresh();
    if (currentUserId == null) {
      throw StateError('Discovery quota requires an authenticated session.');
    }

    try {
      final response =
          await SupabaseService.client.rpc('get_profile_view_quota');
      final rows = response as List<dynamic>;
      if (rows.isEmpty) {
        throw StateError('Profile view quota response was empty.');
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      final viewsToday = (row['views_today'] as num?)?.toInt();
      final dailyLimit = (row['daily_limit'] as num?)?.toInt();
      if (viewsToday == null || dailyLimit == null) {
        throw StateError('Profile view quota response was incomplete.');
      }
      return _ProfileViewQuota(
        viewsToday: viewsToday,
        dailyLimit: dailyLimit,
      );
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: failed to load profile view quota: $e');
      throw StateError('Unable to verify your daily discovery limit.');
    }
  }

  Future<String?> _readDiscoveryRevisionToken(DiscoveryFilter filter) async {
    if (!SupabaseService.isInitialized) return null;
    final currentUserId = await SupabaseService.currentUserIdOrRefresh();
    if (currentUserId == null) return null;
    try {
      final response = await SupabaseService.client.rpc(
        'get_my_discovery_revision',
        params: {'p_filters': _mapFilterToJson(filter)},
      );
      if (response is! List || response.isEmpty) return null;
      final row = Map<String, dynamic>.from(response.first as Map);
      final token = row['revision_token']?.toString();
      return token == null || token.isEmpty ? null : token;
    } catch (e) {
      // Revision invalidation is an optimization. A temporary failure must not
      // make the primary discovery path unavailable.
      debugPrint('DiscoveryFeedCubit: revision check unavailable: $e');
      return null;
    }
  }

  Future<DiscoveryFilter> _enforceLocationFilterAccess(
    DiscoveryFilter filter,
  ) async {
    final hasPremiumFilter = filter.locationScope != 'global' ||
        filter.trustFilter != null ||
        filter.stateName != null ||
        filter.cityId != null ||
        filter.motherTongue != null ||
        filter.community != null ||
        filter.livingExpectation != null;
    if (!hasPremiumFilter) return filter;
    if (!SupabaseService.isInitialized) {
      throw StateError('Location filters require a Supabase connection.');
    }

    final response = await SupabaseService.client.rpc(
      'get_discovery_filter_access',
    );
    final rows = response as List<dynamic>;
    if (rows.isEmpty) {
      throw StateError('Unable to verify Premium location-filter access.');
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    if (row['allowed'] == true) return filter;

    return filter.copyWith(
      diasporaMode: false,
      clearDiasporaCountries: true,
      clearBrowseCountries: true,
      clearDistanceLabel: true,
      clearMaxDistance: true,
      clearTrustFilter: true,
      clearState: true,
      clearCity: true,
      clearMotherTongue: true,
      clearCommunity: true,
      clearLivingExpectation: true,
    );
  }

  // Filter Persistence
  Future<DiscoveryFilter?> _loadFilterFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kFilterKey);
      final raw = prefs.getString(_filterKey);
      if (raw == null || raw.isEmpty) return null;

      final j = jsonDecode(raw) as Map<String, dynamic>;
      return DiscoveryFilter(
        ageMin: j['ageMin'] as int?,
        ageMax: j['ageMax'] as int?,
        sect: j['sect'] as String?,
        deenLevel: j['deenLevel'] as String?,
        trustFilter: j['trustFilter'] as String?,
        activeRecentlyOnly: (j['activeRecentlyOnly'] as bool?) ?? false,
        maxDistanceKm: j['maxDistanceKm'] as int?,
        familyType: j['familyType'] as String?,
        openToDivorced: (j['openToDivorced'] as bool?) ?? false,
        genderPref: j['genderPref'] as String?,
        maritalStatus: j['maritalStatus'] as String?,
        hasChildren: j['hasChildren'] as String?,
        educationMin: j['educationMin'] as String?,
        distanceLabel: j['distanceLabel'] as String?,
        stateName: j['stateName'] as String?,
        cityId: j['cityId'] as String?,
        cityName: j['cityName'] as String?,
        motherTongue: j['motherTongue'] as String?,
        community: j['community'] as String?,
        livingExpectation: j['livingExpectation'] as String?,
        quranMemorization: j['quranMemorization'] as String?,
        marriageTimeline: j['marriageTimeline'] as String?,
        willingToRelocate: j['willingToRelocate'] as String?,
        diasporaMode: (j['diasporaMode'] as bool?) ?? false,
        diasporaCountries: j['diasporaCountries'] != null
            ? List<String>.from(j['diasporaCountries'] as Iterable)
            : null,
        browseCountries: j['browseCountries'] != null
            ? List<String>.from(j['browseCountries'] as Iterable)
            : null,
      );
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: failed to load filter: $e');
      return null;
    }
  }

  Future<void> _saveFilterToPrefs(DiscoveryFilter f) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!f.isActive) {
        await prefs.remove(_filterKey);
        return;
      }
      final json = jsonEncode({
        'ageMin': f.ageMin,
        'ageMax': f.ageMax,
        'sect': f.sect,
        'deenLevel': f.deenLevel,
        'trustFilter': f.trustFilter,
        'activeRecentlyOnly': f.activeRecentlyOnly,
        'maxDistanceKm': f.maxDistanceKm,
        'familyType': f.familyType,
        'openToDivorced': f.openToDivorced,
        'genderPref': f.genderPref,
        'maritalStatus': f.maritalStatus,
        'hasChildren': f.hasChildren,
        'educationMin': f.educationMin,
        'distanceLabel': f.distanceLabel,
        'stateName': f.stateName,
        'cityId': f.cityId,
        'cityName': f.cityName,
        'motherTongue': f.motherTongue,
        'community': f.community,
        'livingExpectation': f.livingExpectation,
        'quranMemorization': f.quranMemorization,
        'marriageTimeline': f.marriageTimeline,
        'willingToRelocate': f.willingToRelocate,
        'diasporaMode': f.diasporaMode,
        'diasporaCountries': f.diasporaCountries,
        'browseCountries': f.browseCountries,
      });
      await prefs.setString(_filterKey, json);
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: failed to save filter: $e');
    }
  }

  String get _filterKey {
    final userId = SupabaseService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Authenticated user is required for filter storage.');
    }
    return '${_kFilterKey}_$userId';
  }

  static Future<void> clearPersistedFilters({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFilterKey);
    if (userId != null && userId.isNotEmpty) {
      await prefs.remove('${_kFilterKey}_$userId');
    }
  }

  void _resetCursors() {
    _backendCursorScore = null;
    _backendCursorId = null;
  }

  int _nextRequestVersion() => ++_requestVersion;

  bool _isCurrentRequest(int requestVersion) =>
      !isClosed && requestVersion == _requestVersion;

  List<FeedProfile> _toFeedProfiles(
    List<DiscoveryProfile> profiles, {
    required int offset,
  }) {
    return [
      for (var i = 0; i < profiles.length; i++)
        FeedProfile(
          profile: profiles[i],
          isWildCard: offset + i > 0 && (offset + i + 1) % 10 == 0,
          lastActiveAt: profiles[i].lastActiveAt,
        ),
    ];
  }

  void _updateBackendCursor(List<dynamic> rows) {
    if (rows.isEmpty) return;

    final last = Map<String, dynamic>.from(rows.last as Map);
    final score = (last['rank_score'] as num?)?.toDouble();
    final profileId = last['profile_id'] as String?;
    if (score != null && profileId != null) {
      _backendCursorScore = score;
      _backendCursorId = profileId;
    }
  }

  Map<String, dynamic> _mapFilterToJson(DiscoveryFilter f) {
    final maxKm = f.effectiveMaxDistanceKm;
    final genderPref = _enumToken(f.genderPref);
    final sect = _enumToken(f.sect);
    final deenLevel = _enumToken(f.deenLevel);
    final familyType = _enumToken(f.familyType);
    final maritalStatus = _maritalStatusToken(f.maritalStatus);
    final hasChildren = _enumToken(f.hasChildren);

    return {
      'location_scope': f.locationScope,
      if (f.stateName != null && f.stateName!.trim().isNotEmpty)
        'state_name': f.stateName!.trim(),
      if (f.cityId != null && f.cityId!.trim().isNotEmpty)
        'city_id': f.cityId!.trim(),
      if (maxKm != null) 'max_distance_km': maxKm,
      if (f.distanceLabel == 'Same City') 'same_city': true,
      if (f.distanceLabel == 'Same State' ||
          f.distanceLabel == 'Same State / Region')
        'same_region': true,
      if (f.distanceLabel == 'Same Country' ||
          f.distanceLabel == 'All India' ||
          f.distanceLabel == 'Anywhere in India')
        'same_country': true,
      if (f.distanceLabel == 'Anywhere') 'anywhere': true,
      if (f.browseCountries != null && f.browseCountries!.isNotEmpty)
        'country_codes': f.browseCountries,
      'diaspora_mode': f.diasporaMode,
      if (f.diasporaCountries != null && f.diasporaCountries!.isNotEmpty)
        'diaspora_countries': f.diasporaCountries,
      if (f.ageMin != null) 'age_min': f.ageMin,
      if (f.ageMax != null) 'age_max': f.ageMax,
      'active_recently': f.activeRecentlyOnly,
      if (genderPref != null) 'gender_pref': genderPref,
      if (sect != null) 'sect': sect,
      if (deenLevel != null) 'deen_level': deenLevel,
      if (f.trustFilter != null) 'trust_filter': f.trustFilter,
      if (familyType != null) 'family_type': familyType,
      if (maritalStatus != null) 'marital_status': maritalStatus,
      // Marital status is an explicit filter below. A broad Discovery query
      // must remain inclusive; the member's partner preference influences
      // ranking and compatibility rather than silently removing every
      // divorced/widowed profile from inventory.
      if (_educationRank(f.educationMin) != null)
        'education_min': _educationRank(f.educationMin),
      if (f.motherTongue != null && f.motherTongue != 'Any')
        'mother_tongue': f.motherTongue,
      if (f.community != null && f.community != 'Any') 'community': f.community,
      if (f.livingExpectation != null && f.livingExpectation != 'Any')
        'living_expectation': f.livingExpectation,
      if (f.quranMemorization != null && f.quranMemorization != 'Any')
        'quran_memorization': f.quranMemorization,
      if (f.marriageTimeline != null && f.marriageTimeline != 'Any')
        'marriage_timeline': f.marriageTimeline,
      if (f.willingToRelocate != null && f.willingToRelocate != 'Any')
        'willing_to_relocate': f.willingToRelocate,
      if (hasChildren != null) 'has_children': hasChildren,
    };
  }

  Future<void> _recordDiscoveryInventory(
    DiscoveryFilter filter, {
    required bool hasProfiles,
  }) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return;
    }
    final fingerprint = jsonEncode({
      'user': SupabaseService.currentUserId,
      'has_profiles': hasProfiles,
      'filters': _mapFilterToJson(filter),
    });
    final lastSync = _lastInventorySyncAt;
    if (_lastInventoryFingerprint == fingerprint &&
        lastSync != null &&
        DateTime.now().difference(lastSync) < const Duration(minutes: 5)) {
      return;
    }
    try {
      await SupabaseService.client.rpc(
        'record_discovery_inventory',
        params: {
          'p_filters': _mapFilterToJson(filter),
          'p_has_profiles': hasProfiles,
        },
      );
      _lastInventoryFingerprint = fingerprint;
      _lastInventorySyncAt = DateTime.now();
    } catch (error) {
      // Notification state is an optimization and must never delay or replace
      // a successfully loaded Discovery feed.
      debugPrint('[DiscoveryFeedCubit] Inventory state sync deferred: $error');
    }
  }

  String? _enumToken(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'any') {
      return null;
    }
    return raw.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  String? _maritalStatusToken(String? value) {
    final token = _enumToken(value);
    if (token == null) return null;
    return token == 'never_married' ? 'no' : token;
  }

  /// Fetches real candidates and their stated compatibility preferences.
  ///
  /// [onRevisionToken] asks for the revision token in the same round trip;
  /// the server reads it before the page so it is never newer than the rows.
  Future<List<DiscoveryProfile>> _getPool({
    DiscoveryFilter? filter,
    required int requestVersion,
    ValueChanged<String?>? onRevisionToken,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw StateError('Discovery requires a Supabase connection.');
    }
    final currentUserId = await SupabaseService.currentUserIdOrRefresh();
    if (currentUserId == null) {
      throw StateError('Please sign in to view discovery profiles.');
    }

    try {
      final timings = Stopwatch()..start();
      // The feed RPC returns nothing for a viewer who is not yet live, so
      // readiness only turns that into a specific message. It runs beside the
      // RPC and its message takes priority over the RPC's result or error.
      final readiness = _Outcome.of(_assertViewerDiscoveryReady(currentUserId));

      final payload =
          filter != null ? _mapFilterToJson(filter) : <String, dynamic>{};
      if (filter?.effectiveMaxDistanceKm != null &&
          !_discoveryLocationPrepared) {
        await LocationService.refreshDiscoveryLocation();
        _discoveryLocationPrepared = true;
      }
      final List<Map<String, dynamic>> rows;
      try {
        rows = await _fetchFeedRows(
          viewerId: currentUserId,
          payload: payload,
          filter: filter ?? state.activeFilter,
          onRevisionToken: onRevisionToken,
        );
      } catch (_) {
        (await readiness).throwIfFailed();
        rethrow;
      }
      (await readiness).throwIfFailed();
      if (!_isCurrentRequest(requestVersion)) return const [];

      final feedMs = timings.elapsedMilliseconds;
      perfMark('discovery: feed rpc ${feedMs}ms');
      // Race fix: stale discovery responses must not advance the shared cursor
      // or overwrite a newer filter/load request.
      if (!_isCurrentRequest(requestVersion)) return const [];
      _updateBackendCursor(rows);
      final photoOwners = rows
          .where((row) => ((row['photo_count'] as num?)?.toInt() ?? 0) > 0)
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      final candidateIds = rows
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      // Relationship context and the one batched photo-signing call are
      // independent. Running them together removes a full network round-trip
      // from cold Discovery without increasing request count or egress.
      final enrichment = await Future.wait<dynamic>([
        _attachPriorMatchContext(rows),
        photoOwners.isEmpty
            ? Future<Map<String, String>>.value(const {})
            : _loadPublicPhotoUrls(photoOwners),
        candidateIds.isEmpty
            ? Future<Map<String, Map<String, bool>>>.value(const {})
            : _loadTrustSummaries(candidateIds),
      ]);
      final signedUrls = enrichment[1] as Map<String, String>;
      final trustByUser = enrichment[2] as Map<String, Map<String, bool>>;
      for (final row in rows) {
        // Feed rows must never expose private Storage paths as image URLs.
        row.remove('photo_url');
        row.remove('photo_urls');
        final signedUrl = signedUrls[row['user_id']?.toString()];
        if (signedUrl != null && signedUrl.isNotEmpty) {
          row['photo_url'] = signedUrl;
        }
        final trust = trustByUser[row['user_id']?.toString()];
        if (trust != null) {
          row['is_verified'] = trust['photo_verified'] ?? false;
          row['guardian_connected'] = trust['guardian_connected'] ?? false;
          row['guardian_managed'] = trust['guardian_managed'] ?? false;
          row['established_member'] = trust['established_member'] ?? false;
        }
      }
      final contextMs = timings.elapsedMilliseconds - feedMs;
      perfMark('discovery: photo links, context, trust ${contextMs}ms');
      if (!_isCurrentRequest(requestVersion)) return const [];
      final profiles = await compute(parseProfilesInBackground, rows);
      final parseMs = timings.elapsedMilliseconds - feedMs - contextMs;
      if (!_isCurrentRequest(requestVersion)) return const [];
      if (kDebugMode) {
        debugPrint(
          'DiscoveryFeedCubit: ${profiles.length} profiles in '
          '${timings.elapsedMilliseconds}ms '
          '(feed ${feedMs}ms, parallel enrichment ${contextMs}ms, '
          'parse ${parseMs}ms).',
        );
      }
      return profiles;
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: Supabase discovery failed: $e');
      rethrow;
    }
  }

  /// One round trip for a page and, when asked, its revision token. Falls
  /// back to the two-call path while a database without
  /// get_discovery_feed_page is still being served during a rollout.
  Future<List<Map<String, dynamic>>> _fetchFeedRows({
    required String viewerId,
    required Map<String, dynamic> payload,
    required DiscoveryFilter filter,
    ValueChanged<String?>? onRevisionToken,
  }) async {
    final params = <String, dynamic>{
      'p_viewer_id': viewerId,
      'p_cursor_score': _backendCursorScore,
      'p_cursor_id': _backendCursorId,
      'p_page_size': _batchSize,
      'p_filters': payload,
    };
    if (_feedPageAvailable) {
      try {
        final response = await SupabaseService.client.rpc(
          'get_discovery_feed_page',
          params: {...params, 'p_include_revision': onRevisionToken != null},
        );
        final page = Map<String, dynamic>.from(response as Map);
        final token = page['revision_token']?.toString();
        onRevisionToken?.call(token == null || token.isEmpty ? null : token);
        return (page['rows'] as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      } on PostgrestException catch (error) {
        // PGRST202: function not found in the schema cache.
        if (error.code != 'PGRST202') rethrow;
        _feedPageAvailable = false;
      }
    }
    if (onRevisionToken != null) {
      onRevisionToken(await _readDiscoveryRevisionToken(filter));
    }
    final response = await SupabaseService.client.rpc(
      'get_discovery_feed',
      params: params,
    );
    return (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, Map<String, bool>>> _loadTrustSummaries(
    List<String> userIds,
  ) async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_member_trust_summaries',
        params: {'p_user_ids': userIds.take(20).toList(growable: false)},
      );
      final result = <String, Map<String, bool>>{};
      for (final raw in response as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['user_id']?.toString();
        if (id == null || id.isEmpty) continue;
        result[id] = {
          'photo_verified': row['photo_verified'] as bool? ?? false,
          'guardian_connected': row['guardian_connected'] as bool? ?? false,
          'guardian_managed': row['guardian_managed'] as bool? ?? false,
          'established_member': row['established_member'] as bool? ?? false,
        };
      }
      return result;
    } catch (error) {
      // Trust badges are presentational. A failed summary request must not
      // blank an otherwise valid discovery page.
      debugPrint('DiscoveryFeedCubit: trust summary unavailable: $error');
      return const {};
    }
  }

  Future<void> _assertViewerDiscoveryReady(String currentUserId) async {
    final readyAt = _viewerReadyAt;
    if (_readyViewerId == currentUserId &&
        readyAt != null &&
        DateTime.now().difference(readyAt) < _viewerReadinessFreshness) {
      return;
    }
    final profile = await MyAccountSnapshot.instance.profile(currentUserId);

    if (profile == null) {
      throw StateError('Complete your profile before browsing discovery.');
    }

    if (profile['visibility'] != 'visible') {
      throw StateError('Your profile must be visible before discovery.');
    }

    if (profile['onboarding_completed'] != true) {
      throw StateError('Complete your profile before browsing discovery.');
    }

    if (profile['approved_at'] == null) {
      throw StateError(
        'Your primary photo must pass the safety scan before discovery.',
      );
    }

    final profileId = profile['id'] as String?;
    if (profileId == null || profileId.isEmpty) {
      throw StateError('Complete your profile before browsing discovery.');
    }

    final photos = await SupabaseService.client
        .from('photos')
        .select('id')
        .eq('profile_id', profileId)
        .eq('admin_approved', true)
        .eq('nsfw_cleared', true)
        .limit(1);

    if ((photos as List<dynamic>).isEmpty) {
      throw StateError(
        'Add an approved profile photo before browsing discovery.',
      );
    }
    _readyViewerId = currentUserId;
    _viewerReadyAt = DateTime.now();
  }

  /// Adds one bounded card-context projection for candidates already returned
  /// in this page. Relationship history and compatibility preferences share a
  /// single RPC, avoiding both N+1 work and a second enrichment round trip.
  Future<void> _attachPriorMatchContext(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    final candidateIds = rows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (candidateIds.isEmpty) return;

    dynamic response;
    try {
      response = await SupabaseService.client.rpc(
        'get_prior_match_context',
        params: {'p_candidate_user_ids': candidateIds},
      );
    } catch (error) {
      // Relationship context is optional enrichment. The primary feed RPC has
      // already enforced safety visibility, so a transient context failure
      // must not replace valid profiles with a full-screen error.
      debugPrint('DiscoveryFeedCubit: card context unavailable: $error');
      return;
    }
    final contextByUser = <String, Map<String, dynamic>>{
      for (final raw in response as List<dynamic>)
        if ((raw as Map)['candidate_user_id'] != null)
          raw['candidate_user_id'].toString(): Map<String, dynamic>.from(raw),
    };
    for (final row in rows) {
      final prior = contextByUser[row['user_id']?.toString()];
      if (prior != null) row.addAll(prior);
    }
  }

  Future<Map<String, String>> _loadPublicPhotoUrls(
    List<String> ownerUserIds,
  ) async {
    try {
      return await ProfilePhotoService.instance.getAuthorizedPhotoUrls(
        ownerUserIds: ownerUserIds,
      );
    } catch (error) {
      // Profiles remain browsable with a privacy-safe placeholder while a
      // transient signing service failure recovers.
      debugPrint('DiscoveryFeedCubit: failed to batch sign photo URLs: $error');
      return const {};
    }
  }

  /// Reconciles only relationship metadata for cards already in memory. This
  /// avoids re-running ranking, pagination and photo signing when a match is
  /// opened/closed or a profile is blocked/reported.
  Future<void> _refreshRelationshipContext(String revisionToken) async {
    final currentProfiles = state.profiles;
    if (currentProfiles.isEmpty) {
      _loadedRevisionToken = revisionToken;
      return;
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_prior_match_context',
        params: {
          'p_candidate_user_ids': currentProfiles
              .map((entry) => entry.profile.id)
              .toSet()
              .toList(growable: false),
        },
      );
      final contextByUser = <String, Map<String, dynamic>>{
        for (final raw in response as List<dynamic>)
          if ((raw as Map)['candidate_user_id'] != null)
            raw['candidate_user_id'].toString(): Map<String, dynamic>.from(raw),
      };
      final updated = <FeedProfile>[];
      for (final entry in currentProfiles) {
        final prior = contextByUser[entry.profile.id];
        // Missing context means this card is no longer safe/visible to this
        // viewer (block, report, suspension or privacy change).
        if (prior == null) continue;
        final previousAt = _optionalTimestamp(prior['previous_match_at']);
        final endedAt = _optionalTimestamp(prior['previous_match_ended_at']);
        final availableAt = _optionalTimestamp(prior['rematch_available_at']);
        updated.add(FeedProfile(
          profile: entry.profile.copyWith(
            previousMatchAt: previousAt,
            previousMatchEndedAt: endedAt,
            priorMatchCount: (prior['prior_match_count'] as num?)?.toInt() ?? 0,
            rematchAvailableAt: availableAt,
            relationshipState: prior['relationship_state']?.toString(),
            clearPreviousMatchAt: previousAt == null,
            clearPreviousMatchEndedAt: endedAt == null,
            clearRematchAvailableAt: availableAt == null,
          ),
          isWildCard: entry.isWildCard,
          lastActiveAt: entry.lastActiveAt,
        ));
      }
      if (isClosed) return;
      _loadedRevisionToken = revisionToken;
      emit(state.copyWith(
        status: updated.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
        profiles: updated,
        clearFailure: true,
      ));
    } catch (error) {
      // Leave both the existing cards and old token intact so the next check
      // retries safely instead of replacing useful content with an error page.
      debugPrint(
        'DiscoveryFeedCubit: relationship-only refresh unavailable: $error',
      );
    }
  }

  DateTime? _optionalTimestamp(Object? value) {
    if (value is DateTime) return value;
    return value == null ? null : DateTime.tryParse(value.toString());
  }

  Future<void> _emitDiscoveryError(
    Object error, {
    bool keepProfiles = false,
    DiscoveryFilter? fallbackFilter,
  }) async {
    if (isClosed) return;
    final stateError = error is StateError ? error.message : null;
    final normalized = stateError?.toLowerCase() ?? '';
    final profileNotReady = normalized.contains('complete your profile') ||
        normalized.contains('profile must be visible') ||
        normalized.contains('approved profile photo') ||
        normalized.contains('primary photo must pass');
    final authenticationRequired = normalized.contains('sign in') ||
        normalized.contains('authenticated session');

    var isOffline = false;
    if (!profileNotReady &&
        !authenticationRequired &&
        ConnectivityService.isInitialized) {
      await ConnectivityService.instance.checkNow();
      isOffline = !ConnectivityService.instance.hasNetworkInterface;
      if (isClosed) return;
    }

    final kind = profileNotReady
        ? DiscoveryFailureKind.profileNotReady
        : authenticationRequired
            ? DiscoveryFailureKind.authenticationRequired
            : isOffline
                ? DiscoveryFailureKind.offline
                : DiscoveryFailureKind.unavailable;
    final message = switch (kind) {
      DiscoveryFailureKind.offline =>
        'No internet connection. Saved profiles remain available and reconnection is automatic.',
      DiscoveryFailureKind.unavailable =>
        'Profiles are temporarily unavailable. Please try again.',
      DiscoveryFailureKind.profileNotReady =>
        stateError ?? 'Unable to load profiles. Please try again.',
      DiscoveryFailureKind.authenticationRequired =>
        'Please sign in to view discovery profiles.',
    };
    final preserveProfiles = keepProfiles || state.profiles.isNotEmpty;
    emit(state.copyWith(
      status: preserveProfiles ? FeedStatus.loaded : FeedStatus.error,
      profiles: preserveProfiles ? state.profiles : const [],
      hasMore: preserveProfiles ? state.hasMore : false,
      activeFilter: fallbackFilter,
      errorMessage: message,
      failureKind: kind,
    ));
  }

  /// Keeps already loaded cards usable while the device is offline. A later
  /// connectivity transition triggers a normal revision-aware refresh.
  void markOffline() {
    if (isClosed) return;
    final preserveProfiles = state.profiles.isNotEmpty;
    emit(state.copyWith(
      status: preserveProfiles ? FeedStatus.loaded : FeedStatus.error,
      errorMessage:
          'No internet connection. Saved profiles remain available and reconnection is automatic.',
      failureKind: DiscoveryFailureKind.offline,
    ));
  }

  int? _educationRank(String? label) {
    switch (label) {
      case 'Matric':
        return 1;
      case 'Intermediate':
        return 2;
      case "Bachelor's":
        return 3;
      case "Master's":
        return 4;
      case 'PhD':
        return 5;
      case 'Professional Degree':
        return 6;
      case 'Other':
        return 7;
      default:
        return null;
    }
  }
}

/// Holds a future's value or error so it can run alongside other work and be
/// inspected later without an unhandled-error report in between.
class _Outcome<T> {
  const _Outcome._(this._value, this._error, this._stackTrace);

  final T? _value;
  final Object? _error;
  final StackTrace? _stackTrace;

  static Future<_Outcome<T>> of<T>(Future<T> future) => future.then(
        (value) => _Outcome<T>._(value, null, null),
        onError: (Object error, StackTrace stackTrace) =>
            _Outcome<T>._(null, error, stackTrace),
      );

  void throwIfFailed() {
    final error = _error;
    if (error != null) Error.throwWithStackTrace(error, _stackTrace!);
  }

  T get valueOrThrow {
    throwIfFailed();
    return _value as T;
  }
}
