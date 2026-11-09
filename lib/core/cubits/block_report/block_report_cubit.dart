// SILARAH - Block / Report Cubit (Supabase production flow)
//
//   "Blocking is silent. The blocked person is not notified.
//    They cannot find the blocker in search, their interests
//    disappear, and the chat is removed from both sides."
//
//   "A report button is accessible from every profile (three-dot
//    menu) and from within every conversation. Reporting immediately
//    hides that profile from the reporter."
//
// Real mode uses checked RPC boundaries. Blocks soft-close matches so safety
// evidence is preserved; reports are queued for explicit staff decisions.
//
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/supabase_service.dart';
import '../../services/authorized_profile_service.dart';
import 'block_report_state.dart';

class BlockReportCubit extends Cubit<BlockReportState> {
  BlockReportCubit() : super(const BlockReportState());

  bool _loadInFlight = false;
  DateTime? _lastLoadedAt;
  static const _freshness = Duration(minutes: 5);

  bool get _isRealMode => SupabaseService.isInitialized;

  // Initial load

  Future<void> loadData({bool force = false}) async {
    if (!_isRealMode || _loadInFlight) return;
    final lastLoadedAt = _lastLoadedAt;
    if (!force &&
        lastLoadedAt != null &&
        DateTime.now().difference(lastLoadedAt) < _freshness) {
      return;
    }
    _loadInFlight = true;
    try {
      await _loadFromDb();
      _lastLoadedAt = DateTime.now();
    } finally {
      _loadInFlight = false;
    }
  }

  /// Load blocks from Supabase
  Future<void> _loadFromDb() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        SupabaseService.client
            .from('blocks')
            .select('blocked_id, created_at')
            .eq('blocker_id', userId)
            .limit(200),
        SupabaseService.client
            .from('reports')
            .select('id, reported_user_id, reason, description, created_at')
            .eq('reporter_id', userId)
            .order('created_at', ascending: false)
            .limit(100),
      ]);
      final blockedRows = results[0] as List<dynamic>;
      final reportRows = results[1] as List<dynamic>;
      final relatedUserIds = <String>{
        for (final row in blockedRows) row['blocked_id'] as String,
        for (final row in reportRows) row['reported_user_id'] as String,
      };
      final profileRows = await AuthorizedProfileService.load(relatedUserIds);
      final profilesByUser = <String, Map<String, dynamic>>{
        for (final raw in profileRows)
          if ((raw as Map)['user_id'] != null)
            raw['user_id'].toString(): Map<String, dynamic>.from(raw),
      };

      final blockedUsers = <BlockedUser>[];
      final hiddenIds = <String>{};

      for (final row in blockedRows) {
        final blockedId = row['blocked_id'] as String;
        hiddenIds.add(blockedId);

        final profile = profilesByUser[blockedId];
        final name = (profile?['first_name'] as String?) ?? 'User';
        final lastInitial = (profile?['last_name_initial'] as String?) ?? '';

        blockedUsers.add(BlockedUser(
          userId: blockedId,
          name: name,
          lastInitial: lastInitial,
          blockedAt:
              DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
        ));
      }

      final reportHistory = <ReportEntry>[];
      for (final row in reportRows) {
        final reportedUserId = row['reported_user_id'] as String;
        hiddenIds.add(reportedUserId);

        final reportedName =
            (profilesByUser[reportedUserId]?['first_name'] as String?) ??
                'User';

        reportHistory.add(ReportEntry(
          reportId: row['id'] as String,
          reportedUserId: reportedUserId,
          reportedName: reportedName,
          reason: ReportReason.values.firstWhere(
            (r) => r.key == (row['reason'] as String),
            orElse: () => ReportReason.other,
          ),
          description: row['description'] as String?,
          submittedAt:
              DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
        ));
      }

      if (!isClosed) {
        emit(state.copyWith(
          blockedUsers: blockedUsers,
          reportHistory: reportHistory,
          hiddenProfileIds: hiddenIds,
        ));
      }
    } catch (e) {
      debugPrint('[BlockReportCubit] Error loading from DB: $e');
    }
  }

  // Block

  /// Silently block a user.
  Future<bool> blockUser({
    required String userId,
    required String name,
    required String lastInitial,
  }) async {
    if (state.isBlocked(userId)) return true;
    if (!_isRealMode) return false;

    emit(state.copyWith(isSubmitting: true));
    final activeUserId = SupabaseService.currentUserId;
    if (activeUserId == null) {
      emit(state.copyWith(isSubmitting: false));
      return false;
    }

    if (_isRealMode) {
      try {
        await SupabaseService.client.rpc('block_member', params: {
          'p_user_id': userId,
          'p_reason': 'profile_block',
        });
      } catch (e) {
        debugPrint('[BlockReportCubit] Error blocking user: $e');
        emit(state.copyWith(isSubmitting: false));
        return false;
      }
    }

    if (isClosed) return false;

    final blocked = BlockedUser(
      userId: userId,
      name: name,
      lastInitial: lastInitial,
      blockedAt: DateTime.now(),
    );

    final updatedBlocks = [blocked, ...state.blockedUsers];
    final updatedHidden = {...state.hiddenProfileIds, userId};

    emit(state.copyWith(
      isSubmitting: false,
      blockedUsers: updatedBlocks,
      hiddenProfileIds: updatedHidden,
      successMessage: 'User blocked. They can no longer contact you.',
    ));
    return true;
  }

  /// Unblock a previously blocked user.
  Future<void> unblockUser(String userId) async {
    if (!_isRealMode) return;

    emit(state.copyWith(isSubmitting: true));
    final activeUserId = SupabaseService.currentUserId;
    if (activeUserId == null) {
      emit(state.copyWith(isSubmitting: false));
      return;
    }

    if (_isRealMode) {
      try {
        await SupabaseService.client.rpc(
          'unblock_member',
          params: {'p_user_id': userId},
        );
      } catch (e) {
        debugPrint('[BlockReportCubit] Error unblocking user: $e');
        emit(state.copyWith(isSubmitting: false));
        return;
      }
    }

    if (isClosed) return;

    final updatedBlocks =
        state.blockedUsers.where((b) => b.userId != userId).toList();
    final updatedHidden = {...state.hiddenProfileIds}..remove(userId);

    emit(state.copyWith(
      isSubmitting: false,
      blockedUsers: updatedBlocks,
      hiddenProfileIds: updatedHidden,
    ));
  }

  // Report

  /// Report a user with a predefined reason.
  Future<bool> reportUser({
    required String reportedUserId,
    required String reportedName,
    required ReportReason reason,
    String? description,
  }) async {
    if (!_isRealMode || state.isSubmitting) return false;

    emit(state.copyWith(isSubmitting: true, clearError: true));
    final activeUserId = SupabaseService.currentUserId;
    if (activeUserId == null) {
      emit(state.copyWith(
        isSubmitting: false,
        error: 'Please sign in again before submitting this report.',
      ));
      return false;
    }

    String? reportId;

    if (_isRealMode) {
      try {
        final result =
            await SupabaseService.client.rpc('submit_user_report', params: {
          'p_reported_user_id': reportedUserId,
          'p_reason': reason.key,
          'p_description': description,
        });
        reportId = result?.toString();
      } catch (e) {
        debugPrint('[BlockReportCubit] Error reporting user: $e');
        emit(state.copyWith(
          isSubmitting: false,
          error:
              'Report could not be submitted. Check your connection and retry.',
        ));
        return false;
      }
    }

    if (isClosed) return false;
    if (reportId == null || reportId.trim().isEmpty) {
      emit(state.copyWith(
        isSubmitting: false,
        error: 'Report could not be confirmed. Please retry.',
      ));
      return false;
    }

    final entry = ReportEntry(
      reportId: reportId,
      reportedUserId: reportedUserId,
      reportedName: reportedName,
      reason: reason,
      description: description,
      submittedAt: DateTime.now(),
    );

    final updatedHidden = {...state.hiddenProfileIds, reportedUserId};

    emit(state.copyWith(
      isSubmitting: false,
      reportHistory: [entry, ...state.reportHistory],
      hiddenProfileIds: updatedHidden,
      successMessage:
          'Report submitted. JazakAllah for keeping the community safe.',
    ));
    return true;
  }

  void clearMessages() {
    emit(state.copyWith(clearSuccess: true, clearError: true));
  }

  void clear() {
    if (!isClosed) emit(const BlockReportState());
  }
}
