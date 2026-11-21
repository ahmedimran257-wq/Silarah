final RegExp _notificationUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

const _exactNotificationPaths = <String>{
  '/profile-views',
  '/shortlist',
  '/photo-requests',
  '/notifications',
  '/badge-verification',
  '/verify',
  '/edit-profile',
  '/subscription',
  '/help-support',
  '/guardian-dashboard',
  '/guardian-connect',
  '/referral',
  '/delete-account',
  '/block-list',
};

String? _entityPath(String prefix, String? identifier) {
  final id = identifier?.trim();
  if (id == null || !_notificationUuid.hasMatch(id)) return null;
  return '/$prefix/$id';
}

String? _safeInternalNotificationPath(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty || uri.hasFragment) {
    return null;
  }

  if (uri.path == '/home') {
    final tab = uri.queryParameters['tab'];
    return const {'0', '1', '2', '3'}.contains(tab) ? '/home?tab=$tab' : null;
  }
  if (_exactNotificationPaths.contains(uri.path)) {
    if (uri.path == '/edit-profile' && uri.hasQuery) {
      return uri.queryParameters['section'] == 'photos'
          ? '/edit-profile?section=photos'
          : '/edit-profile';
    }
    return uri.hasQuery ? null : uri.path;
  }
  if (uri.pathSegments.length == 2) {
    final section = uri.pathSegments.first;
    if (section == 'chat' || section == 'profile') {
      return _entityPath(section, uri.pathSegments.last);
    }
  }
  return null;
}

/// Converts a server-owned Silarah link into a validated authenticated route.
///
/// Notification rows outlive some relationship records. Only known screens
/// and UUID-backed entity routes are accepted so a stale/corrupt payload can
/// never send GoRouter to an unknown location.
String? notificationPathFromDeepLink(String? deepLink) {
  final link = deepLink?.trim();
  if (link == null || link.isEmpty) return null;
  if (link.startsWith('/')) return _safeInternalNotificationPath(link);

  final uri = Uri.tryParse(link);
  if (uri == null || !{'silarah', 'mithaq'}.contains(uri.scheme)) return null;
  if (uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }

  final host = uri.host;
  if (host == 'discover') return '/home?tab=0';
  if (host == 'interests') return '/home?tab=1';
  if (host == 'chat') {
    return uri.pathSegments.isEmpty
        ? '/home?tab=2'
        : _entityPath(
            'chat',
            uri.pathSegments.length == 1 ? uri.pathSegments.first : null,
          );
  }
  if (host == 'profile') {
    return uri.pathSegments.isEmpty
        ? '/home?tab=3'
        : _entityPath(
            'profile',
            uri.pathSegments.length == 1 ? uri.pathSegments.first : null,
          );
  }
  if (host == 'profile-views') return '/profile-views';
  if (host == 'shortlist') return '/shortlist';
  if (host == 'photo-requests') return '/photo-requests';
  if (host == 'notifications') return '/notifications';
  if (host == 'verify') return '/badge-verification';
  if (host == 'verify-identity') return '/verify';
  if (host == 'photos') return '/edit-profile?section=photos';
  if (host == 'complete-profile') return '/edit-profile';
  if (host == 'subscription' || host == 'membership') {
    return '/subscription';
  }
  if (host == 'support' || host == 'help-support') return '/help-support';
  if (host == 'guardian-dashboard') return '/guardian-dashboard';
  if (host == 'guardian-connect') return '/guardian-connect';
  if (host == 'referral') return '/referral';
  return null;
}

/// One canonical type fallback shared by FCM and the in-app notification list.
/// Deep links remain authoritative, while legacy rows without one still land
/// on a safe, useful screen.
String? notificationDestinationPath({
  required String? type,
  String? deepLink,
  String? matchId,
  String? profileId,
}) {
  if (type == 'referral_reward' || type == 'referral_completed') {
    return '/home?tab=3';
  }

  // A Guardian reads a ward's conversation on the Guardian dashboard, never
  // through the member chat route (they are not a participant, so that route
  // can only say "Conversation no longer available"). Older rows carried a
  // silarah://chat link; the type decides.
  if (type == 'guardian_message_mirror') return '/guardian-dashboard';

  final deepLinkPath = notificationPathFromDeepLink(deepLink);
  if (deepLinkPath != null) return deepLinkPath;

  switch (type) {
    case 'new_message':
      return _entityPath('chat', matchId) ?? '/home?tab=2';
    case 'guardian_sent_message':
      return _entityPath('chat', matchId) ?? '/guardian-dashboard';
    case 'match':
    case 'match_accepted':
    case 'interest_received':
    case 'interest_accepted':
    case 'interest_expiring':
    case 'interest_expired':
      return '/home?tab=1';
    case 'match_ended':
    case 'new_compatible_profiles':
    case 'inactive_nudge':
      return '/home?tab=0';
    case 'admin_announcement':
    case 'festival_greeting':
      return '/notifications';
    case 'profile_live':
    case 'account_restored':
    case 'photo_approved':
    case 'photo_rejected':
    case 'photo_verification_approved':
    case 'boost_ready':
    case 'boost_available':
    case 'profile_returned_to_review':
      return '/home?tab=3';
    case 'profile_view':
      return '/profile-views';
    case 'photo_access_request':
      return '/photo-requests';
    case 'photo_access_granted':
      return _entityPath('profile', profileId) ?? '/home?tab=1';
    case 'profile_nudge':
      return '/edit-profile';
    case 'subscription_active':
    case 'subscription_renewed':
    case 'subscription_updated':
    case 'subscription_cancelled':
    case 'subscription_expired':
    case 'subscription_refunded':
    case 'billing_issue':
      return '/subscription';
    case 'photo_verification_reviewed':
      return '/verify';
    case 'account_suspended':
    case 'account_banned':
    case 'account_limited':
      return '/help-support';
    default:
      return null;
  }
}

/// Notifications the billing webhook sends when a membership changes.
bool isBillingNotificationType(String type) => const {
      'subscription_active',
      'subscription_renewed',
      'subscription_updated',
      'subscription_cancelled',
      'subscription_expired',
      'subscription_refunded',
    }.contains(type);
