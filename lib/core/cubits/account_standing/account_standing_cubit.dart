import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/my_account_snapshot.dart';
import '../../services/supabase_service.dart';
import '../../services/connectivity_service.dart';
import 'account_standing_state.dart';

/// One authoritative account-standing source for the whole app.
///
/// Deliberately does not read or expose shadowban fields. A shadowban is a
/// silent abuse-control mechanism; user-visible enforcement belongs in the
/// suspended or banned states.
class AccountStandingCubit extends Cubit<AccountStandingState> {
  AccountStandingCubit() : super(const AccountStandingState());

  String? _userId;
  int _loadVersion = 0;

  Future<void> start(String userId) async {
    if (_userId == userId) {
      await refresh();
      return;
    }
    await stop();
    _userId = userId;
    emit(const AccountStandingState(loading: true));

    // Account changes are reconciled after publication, foreground FCM,
    // reconnect and app resume. Avoiding an always-on database channel keeps
    // idle members from consuming scarce Realtime connections.
    // The first load for a session joins the account rows auth is already
    // fetching; every later refresh reads them from the server.
    await _refresh(force: false);
  }

  Future<void> refresh() => _refresh(force: true);

  Future<void> _refresh({required bool force}) async {
    final userId = _userId;
    if (userId == null || !SupabaseService.isInitialized) return;
    final version = ++_loadVersion;
    try {
      // Independent reads run together; sequential awaits tripled latency
      // on every resume and reconnect.
      final reads = await Future.wait<Map<String, dynamic>?>([
        MyAccountSnapshot.instance.profile(userId, force: force),
        MyAccountSnapshot.instance.user(userId, force: force),
      ]);
      final profile = reads[0];
      final user = reads[1];

      var hasPublishedPhoto = false;
      final profileId = profile?['id']?.toString();
      if (profileId != null && profileId.isNotEmpty) {
        final photo = await SupabaseService.client
            .from('photos')
            .select('id')
            .eq('profile_id', profileId)
            .eq('order_index', 0)
            .eq('status', 'active')
            .eq('admin_approved', true)
            .eq('nsfw_cleared', true)
            .limit(1);
        hasPublishedPhoto = (photo as List<dynamic>).isNotEmpty;
      }
      if (isClosed || version != _loadVersion || _userId != userId) return;

      final visibility = profile?['visibility']?.toString() ?? 'paused';
      final isBanned = user?['is_banned'] == true;
      final kind = isBanned
          ? AccountStandingKind.banned
          : switch (visibility) {
              'visible' => AccountStandingKind.active,
              'suspended' => AccountStandingKind.suspended,
              'deactivated' => AccountStandingKind.deactivated,
              _ => AccountStandingKind.paused,
            };
      emit(AccountStandingState(
        kind: kind,
        hasPublishedPhoto: hasPublishedPhoto,
      ));
    } catch (_) {
      if (isClosed || version != _loadVersion || _userId != userId) return;
      var offline = false;
      if (ConnectivityService.isInitialized) {
        await ConnectivityService.instance.checkNow();
        offline = !ConnectivityService.instance.hasNetworkInterface;
      }
      if (isClosed || version != _loadVersion || _userId != userId) return;
      emit(state.copyWith(
        loading: false,
        errorMessage: offline
            ? 'No internet connection. Showing your last known account status.'
            : 'Account status could not be refreshed.',
      ));
    }
  }

  Future<bool> resumeProfile() async {
    if (state.updating || state.kind != AccountStandingKind.paused) {
      return false;
    }
    emit(state.copyWith(updating: true, clearError: true));
    try {
      await SupabaseService.client.rpc(
        'set_profile_pause',
        params: {'p_paused': false},
      );
      await refresh();
      // A failed refresh keeps the previous state, which is still updating.
      if (!isClosed && state.updating) {
        emit(state.copyWith(updating: false));
      }
      return state.kind == AccountStandingKind.active;
    } on PostgrestException catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          updating: false,
          errorMessage: error.message.split('\n').first,
        ));
      }
      return false;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(
          updating: false,
          errorMessage: 'Your profile could not be resumed. Please try again.',
        ));
      }
      return false;
    }
  }

  Future<void> stop() async {
    _userId = null;
    _loadVersion++;
    if (!isClosed) emit(const AccountStandingState());
  }

  void markOffline() {
    if (isClosed || _userId == null) return;
    emit(state.copyWith(
      loading: false,
      errorMessage:
          'No internet connection. Showing your last known account status.',
    ));
  }

  @override
  Future<void> close() async {
    await stop();
    return super.close();
  }
}
