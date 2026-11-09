// SILARAH - Notifications Cubit
// Bounded notification state backed by Supabase and foreground FCM recovery.
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/supabase_service.dart';
import '../../utils/notification_deep_link.dart';

class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
    this.profileId,
    this.deepLink,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime time;
  final bool isRead;
  final String? profileId;
  final String? deepLink;

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        type: type,
        title: title,
        body: body,
        time: time,
        isRead: isRead ?? this.isRead,
        profileId: profileId,
        deepLink: deepLink,
      );

  @override
  List<Object?> get props =>
      [id, type, title, body, time, isRead, profileId, deepLink];
}

class NotificationsState extends Equatable {
  const NotificationsState({
    this.items = const [],
  });

  final List<NotificationItem> items;
  int get unreadCount => items.where((n) => !n.isRead).length;
  int get bellUnreadCount =>
      items.where((n) => !n.isRead && n.type != 'profile_view').length;
  int get profileViewUnreadAlertCount =>
      items.where((n) => !n.isRead && n.type == 'profile_view').length;

  NotificationsState copyWith({List<NotificationItem>? items}) =>
      NotificationsState(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit() : super(const NotificationsState());

  int _loadVersion = 0;
  bool _loadInFlight = false;
  bool _reloadAfterCurrentLoad = false;
  DateTime? _lastLoadedAt;
  static const _freshness = Duration(minutes: 5);
  static const _maxRetainedNotifications = 100;
  final StreamController<NotificationItem> _inAppNotifications =
      StreamController<NotificationItem>.broadcast();

  Stream<NotificationItem> get inAppNotifications => _inAppNotifications.stream;

  Future<void> loadNotifications({bool force = false}) async {
    if (_loadInFlight) {
      if (force) _reloadAfterCurrentLoad = true;
      return;
    }
    final lastLoadedAt = _lastLoadedAt;
    if (!force &&
        lastLoadedAt != null &&
        DateTime.now().difference(lastLoadedAt) < _freshness) {
      return;
    }
    _loadInFlight = true;
    final loadVersion = ++_loadVersion;
    if (!SupabaseService.isInitialized) {
      clear();
      return;
    }

    final me = SupabaseService.currentUserId;
    if (me == null) {
      clear();
      return;
    }

    try {
      final data = await SupabaseService.client
          .from('notifications')
          .select('id, type, title, body, read_at, created_at, deep_link')
          .eq('user_id', me)
          .order('created_at', ascending: false)
          .limit(_maxRetainedNotifications);

      final items = (data as List)
          .map((row) => _itemFromRow(Map<String, dynamic>.from(row as Map)))
          .toList();

      if (!_isCurrentLoad(loadVersion) || SupabaseService.currentUserId != me) {
        return;
      }
      emit(NotificationsState(items: items));
      _lastLoadedAt = DateTime.now();
    } catch (error) {
      // Keep what is already on screen; _lastLoadedAt stays old so the next
      // load tries again.
      debugPrint('[NotificationsCubit] load failed: $error');
    } finally {
      _loadInFlight = false;
      if (_reloadAfterCurrentLoad &&
          !isClosed &&
          SupabaseService.currentUserId != null) {
        _reloadAfterCurrentLoad = false;
        unawaited(loadNotifications(force: true));
      }
    }
  }

  /// Shows a foreground push immediately and then reconciles the bounded list
  /// with the authoritative notification row. This replaces an always-on
  /// Postgres Changes channel, preserving responsive UI without consuming one
  /// Realtime connection for every signed-in member.
  void reconcileForegroundPush({
    required String type,
    String? notificationId,
    String? title,
    String? body,
    String? deepLink,
  }) {
    final fallback = _copyForType(type);
    final item = _itemFromRow({
      'id': _cleanText(notificationId) ??
          'foreground_${DateTime.now().microsecondsSinceEpoch}',
      'type': type,
      'title': _cleanText(title) ?? fallback.$1,
      'body': _cleanText(body) ?? fallback.$2,
      'read_at': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'deep_link': deepLink,
    });
    if (state.items.any((notification) => notification.id == item.id)) return;
    if (!isClosed) {
      emit(NotificationsState(
        items: [item, ...state.items]
            .take(_maxRetainedNotifications)
            .toList(growable: false),
      ));
      _inAppNotifications.add(item);
    }
    unawaited(loadNotifications(force: true));
  }

  NotificationItem _itemFromRow(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final type = row['type'] as String? ?? 'general';
    final fallback = _copyForType(type);
    final title = _cleanText(row['title']) ?? fallback.$1;
    final body = _cleanText(row['body']) ?? fallback.$2;
    final readAt = row['read_at'];
    final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
    final deepLink = row['deep_link'] as String?;

    String? profileId;
    if (deepLink != null && deepLink.contains('profile/')) {
      profileId = deepLink.split('profile/').last;
    }

    return NotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      time: createdAt,
      isRead: readAt != null,
      profileId: profileId,
      deepLink: deepLink,
    );
  }

  String? _cleanText(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  (String, String) _copyForType(String type) {
    switch (type) {
      case 'new_compatible_profiles':
        return (
          'New compatible profiles are available',
          'Open Discovery to view profiles selected for your preferences.'
        );
      case 'profile_live':
        return (
          'Your profile is now live! 🎉',
          'Muslims in your area can now find you on Silarah.'
        );
      case 'photo_access_request':
        return (
          'Photo access request',
          'A member would like permission to view your private photos.'
        );
      case 'photo_access_granted':
        return (
          'Photo access granted',
          'You can now view the photos that were shared with you.'
        );
      case 'profile_returned_to_review':
        return (
          'Profile needs review',
          'Please update the requested details before your profile goes live.'
        );
      case 'account_restored':
        return (
          'Profile restored',
          'Your Silarah profile has been restored and is visible again.'
        );
      case 'account_suspended':
        return (
          'Profile suspended',
          'Your profile is paused while our team reviews your account.'
        );
      case 'account_banned':
        return (
          'Account blocked',
          'This account is no longer allowed to use Silarah.'
        );
      case 'account_limited':
        return (
          'Account visibility limited',
          'Your profile visibility has been limited while our team reviews it.'
        );
      case 'photo_approved':
        return ('Photo approved', 'Your profile photo is now visible.');
      case 'photo_rejected':
        return (
          'Photo not approved',
          'Please upload a clear, respectful profile photo.'
        );
      case 'photo_verification_approved':
        return (
          'Photo verified',
          'Your photo check is approved and its temporary captures are being deleted.'
        );
      case 'photo_verification_reviewed':
        return (
          'Photo check reviewed',
          'Open your profile to see the result and any next step.'
        );
      case 'interest_received':
        return ('New interest', 'Someone is interested in your profile.');
      case 'interest_accepted':
        return ('Interest accepted', 'You can now start a conversation.');
      case 'interest_expiring':
        return (
          'Interest expires soon',
          'Open Interests to review it before the response window closes.'
        );
      case 'interest_expired':
        return (
          'Interest expired',
          'The interest closed because no response was received in time.'
        );
      case 'match_ended':
        return (
          'Match ended',
          'You can reconnect after the 7-day cooling-off period.'
        );
      case 'new_message':
        return ('New message', 'You have a new message.');
      case 'profile_view':
        return ('New profile activity', 'Someone viewed your profile.');
      case 'boost_ready':
        return ('Boost ready', 'Your profile boost is ready to use.');
      default:
        return ('Notification', 'Open Silarah to view the latest update.');
    }
  }

  Future<void> markRead(String id) async {
    final updated = state.items
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    emit(state.copyWith(items: updated));

    if (!SupabaseService.isInitialized) return;

    try {
      await SupabaseService.client
          .rpc('mark_notification_read', params: {'p_notification_id': id});
    } catch (error, stackTrace) {
      debugPrint('[NotificationsCubit] mark read failed: $error\n$stackTrace');
    }
  }

  Future<void> markAllRead() async {
    final updated = state.items.map((n) => n.copyWith(isRead: true)).toList();
    emit(state.copyWith(items: updated));

    if (!SupabaseService.isInitialized) return;

    final me = SupabaseService.currentUserId;
    if (me == null) return;

    try {
      await SupabaseService.client.rpc('mark_all_notifications_read');
    } catch (error, stackTrace) {
      debugPrint(
          '[NotificationsCubit] mark all read failed: $error\n$stackTrace');
    }
  }

  /// Marks unread notifications read once the member has handled what they
  /// point to elsewhere (opened the chat, viewed received interests), so the
  /// bell does not keep advertising work that is already done.
  void markHandled(bool Function(NotificationItem item) handled) {
    final ids = state.items
        .where((n) => !n.isRead && handled(n))
        .map((n) => n.id)
        .toList(growable: false);
    for (final id in ids) {
      unawaited(markRead(id));
    }
  }

  /// Reconciles local notification history after the dedicated profile-view
  /// read cursor has been advanced server-side.
  void reconcileProfileViewsSeen() {
    var changed = false;
    final updated = state.items.map((notification) {
      if (notification.type != 'profile_view' || notification.isRead) {
        return notification;
      }
      changed = true;
      return notification.copyWith(isRead: true);
    }).toList(growable: false);
    if (changed) emit(state.copyWith(items: updated));
  }

  Future<bool> deleteNotification(String id) async {
    final me = SupabaseService.currentUserId;
    final previous = state.items;
    emit(state.copyWith(
        items: previous.where((item) => item.id != id).toList()));

    if (!SupabaseService.isInitialized || me == null) return true;
    try {
      await SupabaseService.client
          .rpc('delete_my_notification', params: {'p_notification_id': id});
      return true;
    } catch (_) {
      if (!isClosed && SupabaseService.currentUserId == me) {
        emit(state.copyWith(items: previous));
      }
      return false;
    }
  }

  Future<bool> clearAllNotifications() async {
    final me = SupabaseService.currentUserId;
    final previous = state.items;
    if (previous.isEmpty) return true;
    emit(const NotificationsState());

    if (!SupabaseService.isInitialized || me == null) return true;
    try {
      await SupabaseService.client.rpc('clear_my_notifications');
      return true;
    } catch (_) {
      if (!isClosed && SupabaseService.currentUserId == me) {
        emit(NotificationsState(items: previous));
      }
      return false;
    }
  }

  void clear() {
    _loadVersion++;
    _lastLoadedAt = null;
    _loadInFlight = false;
    _reloadAfterCurrentLoad = false;
    if (!isClosed) emit(const NotificationsState());
  }

  @override
  Future<void> close() async {
    _loadVersion++;
    await _inAppNotifications.close();
    await super.close();
  }

  bool _isCurrentLoad(int version) => !isClosed && version == _loadVersion;
}

String? notificationPathFor(NotificationItem item) {
  return notificationDestinationPath(
    type: item.type,
    deepLink: item.deepLink,
    profileId: item.profileId,
  );
}
