// The Calls tab's history list (docs/voice_calling_spec.md 12.5): pages of
// the member's own call log from the server, a filter, a name search,
// "Remove from history" with undo, and the photos the member may see.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/profile_photo_service.dart';
import 'call_api.dart';
import 'call_controller.dart';
import 'call_log.dart';

typedef PhotoLoader = Future<Map<String, String>> Function(List<String> ownerUserIds);

class CallLogController extends ChangeNotifier {
  CallLogController({CallApi? api, PhotoLoader? photos, this.pageSize = 40})
      : _api = api ?? CallApi.instance,
        _photos = photos ?? _defaultPhotos {
    CallController.historyVersion.addListener(_onHistoryChanged);
  }

  static Future<Map<String, String>> _defaultPhotos(List<String> ids) =>
      ProfilePhotoService.instance.getAuthorizedPhotoUrls(ownerUserIds: ids);

  final CallApi _api;
  final PhotoLoader _photos;
  final int pageSize;

  CallLogFilter filter = CallLogFilter.all;
  String query = '';
  List<CallLogEntry> entries = const [];

  /// Photo URLs the server allows this member to see, by user id.
  final Map<String, String> photoUrls = {};

  /// All plans (open and past) for the Planned filter.
  List<CallPlan> plans = const [];

  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  bool failed = false;

  // Rows removed locally while their undo is still possible.
  final Set<String> _pendingHide = {};
  int _generation = 0;
  Timer? _searchDebounce;
  bool _disposed = false;

  List<CallLogEntry> get visibleEntries =>
      entries.where((e) => !_pendingHide.contains(e.requestId)).toList(growable: false);

  bool get isEmpty => filter == CallLogFilter.planned ? plans.isEmpty : visibleEntries.isEmpty;

  void _onHistoryChanged() => unawaited(load(quiet: true));

  /// First page (or the Planned list). [quiet] keeps the current rows on
  /// screen while it loads.
  Future<void> load({bool quiet = false}) async {
    final generation = ++_generation;
    if (!quiet || entries.isEmpty) {
      loading = true;
      failed = false;
      _notify();
    }
    try {
      if (filter == CallLogFilter.planned) {
        final next = await _api.plans();
        if (generation != _generation) return;
        plans = next;
        hasMore = false;
        unawaited(loadPhotosFor(next.where((p) => !p.memberUnavailable).map((p) => p.otherUserId).whereType<String>()));
      } else {
        final next = await _api.log(filter: filter, query: query, limit: pageSize);
        if (generation != _generation) return;
        entries = next;
        hasMore = next.length >= pageSize;
        unawaited(_loadPhotos(next, generation));
      }
      failed = false;
    } catch (error) {
      if (generation != _generation) return;
      debugPrint('[CallLogController] load failed: $error');
      failed = true;
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore || filter == CallLogFilter.planned || entries.isEmpty) return;
    final generation = _generation;
    loadingMore = true;
    _notify();
    try {
      final next = await _api.log(filter: filter, query: query, after: entries.last, limit: pageSize);
      if (generation != _generation) return;
      final known = {for (final e in entries) e.requestId};
      entries = [...entries, ...next.where((e) => !known.contains(e.requestId))];
      hasMore = next.length >= pageSize;
      unawaited(_loadPhotos(next, generation));
    } catch (error) {
      debugPrint('[CallLogController] more failed: $error');
    } finally {
      if (generation == _generation) {
        loadingMore = false;
        _notify();
      }
    }
  }

  void setFilter(CallLogFilter next) {
    if (next == filter) return;
    filter = next;
    entries = const [];
    hasMore = true;
    unawaited(load());
  }

  void setQuery(String next) {
    final trimmed = next.trim();
    if (trimmed == query) return;
    query = trimmed;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () => unawaited(load(quiet: true)));
  }

  Future<void> _loadPhotos(List<CallLogEntry> page, int generation) => loadPhotosFor(
        page.where((e) => !e.memberUnavailable).map((e) => e.otherUserId).whereType<String>(),
        generation: generation,
      );

  /// One batched, privacy-checked photo request for members not loaded yet
  /// (history rows, planned calls).
  Future<void> loadPhotosFor(Iterable<String> userIds, {int? generation}) async {
    final ids = userIds.where((id) => id.isNotEmpty && !photoUrls.containsKey(id)).toSet().toList(growable: false);
    if (ids.isEmpty) return;
    try {
      final urls = await _photos(ids);
      if ((generation != null && generation != _generation) || _disposed) return;
      photoUrls.addAll(urls);
      _notify();
    } catch (_) {
      // Initials stand in for a photo that could not be loaded.
    }
  }

  /// Removes [row] from view now; [commit] makes it final on the server.
  /// Returns an undo that restores it (only before [commit] runs).
  ({VoidCallback undo, Future<bool> Function() commit}) removeRow(CallLogRow row) {
    final ids = row.requestIds;
    _pendingHide.addAll(ids);
    _notify();
    var done = false;
    return (
      undo: () {
        if (done) return;
        done = true;
        _pendingHide.removeAll(ids);
        _notify();
      },
      commit: () async {
        if (done) return true;
        done = true;
        final ok = await _api.hide(ids);
        if (ok) {
          entries = entries.where((e) => !ids.contains(e.requestId)).toList(growable: false);
        }
        _pendingHide.removeAll(ids);
        _notify();
        return ok;
      },
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    CallController.historyVersion.removeListener(_onHistoryChanged);
    super.dispose();
  }
}
