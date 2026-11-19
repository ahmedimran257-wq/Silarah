import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import '../utils/member_name.dart';

enum ProfilePhotoPrivacy {
  public,
  mutualOnly,
  requestOnly;

  static ProfilePhotoPrivacy fromDatabase(Object? value) {
    return switch (value?.toString()) {
      'mutual_only' => ProfilePhotoPrivacy.mutualOnly,
      'request_only' => ProfilePhotoPrivacy.requestOnly,
      _ => ProfilePhotoPrivacy.public,
    };
  }
}

class PhotoAccessContext {
  const PhotoAccessContext({
    required this.privacy,
    required this.isMutual,
    required this.canView,
    required this.photoCount,
    this.requestStatus,
  });

  final ProfilePhotoPrivacy privacy;
  final bool isMutual;
  final bool canView;
  final int photoCount;
  final String? requestStatus;

  bool get isPending => requestStatus == 'pending';
  bool get isGranted => requestStatus == 'granted';

  PhotoAccessContext copyWith({
    ProfilePhotoPrivacy? privacy,
    bool? isMutual,
    bool? canView,
    int? photoCount,
    String? requestStatus,
  }) {
    return PhotoAccessContext(
      privacy: privacy ?? this.privacy,
      isMutual: isMutual ?? this.isMutual,
      canView: canView ?? this.canView,
      photoCount: photoCount ?? this.photoCount,
      requestStatus: requestStatus ?? this.requestStatus,
    );
  }
}

class IncomingPhotoAccessRequest {
  const IncomingPhotoAccessRequest({
    required this.id,
    required this.requesterId,
    required this.firstName,
    required this.lastNameInitial,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String requesterId;
  final String firstName;
  final String lastNameInitial;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  String get displayName => memberDisplayName(firstName, lastNameInitial);

  IncomingPhotoAccessRequest copyWith({String? status}) {
    return IncomingPhotoAccessRequest(
      id: id,
      requesterId: requesterId,
      firstName: firstName,
      lastNameInitial: lastNameInitial,
      status: status ?? this.status,
      createdAt: createdAt,
      respondedAt: respondedAt,
    );
  }
}

class PhotoAccessService {
  PhotoAccessService._();

  static final instance = PhotoAccessService._();

  Future<PhotoAccessContext> getContext(String ownerId) async {
    _requireSession();
    final response = await SupabaseService.client.rpc(
      'get_photo_access_context',
      params: {'p_owner_id': ownerId},
    );
    final rows = response as List<dynamic>;
    if (rows.isEmpty) throw StateError('Photo privacy is unavailable.');
    final row = Map<String, dynamic>.from(rows.first as Map);
    return PhotoAccessContext(
      privacy: ProfilePhotoPrivacy.fromDatabase(row['photo_privacy']),
      isMutual: row['is_mutual'] == true,
      requestStatus: row['request_status']?.toString(),
      canView: row['can_view'] == true,
      photoCount: (row['photo_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<PhotoAccessContext> requestAccess(String ownerId) async {
    _requireSession();
    try {
      await SupabaseService.client.rpc(
        'request_photo_access',
        params: {'p_owner_id': ownerId},
      );
      return getContext(ownerId);
    } on PostgrestException catch (error) {
      throw StateError(_cleanMessage(error.message));
    }
  }

  Future<PhotoAccessContext> cancelRequest(String ownerId) async {
    _requireSession();
    try {
      await SupabaseService.client.rpc(
        'cancel_photo_access_request',
        params: {'p_owner_id': ownerId},
      );
      return getContext(ownerId);
    } on PostgrestException catch (error) {
      throw StateError(_cleanMessage(error.message));
    }
  }

  Future<List<IncomingPhotoAccessRequest>> getIncomingRequests() async {
    _requireSession();
    final response =
        await SupabaseService.client.rpc('get_incoming_photo_access_requests');
    return (response as List<dynamic>).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      return IncomingPhotoAccessRequest(
        id: row['request_id'].toString(),
        requesterId: row['requester_id'].toString(),
        firstName: row['first_name']?.toString().trim().isNotEmpty == true
            ? row['first_name'].toString().trim()
            : 'Member',
        lastNameInitial: row['last_name_initial']?.toString() ?? '',
        status: row['status']?.toString() ?? 'pending',
        createdAt: DateTime.parse(row['created_at'].toString()).toLocal(),
        respondedAt: row['responded_at'] == null
            ? null
            : DateTime.parse(row['responded_at'].toString()).toLocal(),
      );
    }).toList(growable: false);
  }

  Future<String> respond(String requestId, {required bool grant}) async {
    _requireSession();
    try {
      final result = await SupabaseService.client.rpc(
        'respond_to_photo_access_request',
        params: {
          'p_request_id': requestId,
          'p_decision': grant ? 'granted' : 'denied',
        },
      );
      return result.toString();
    } on PostgrestException catch (error) {
      throw StateError(_cleanMessage(error.message));
    }
  }

  Future<String> revoke(String requestId) async {
    _requireSession();
    try {
      final result = await SupabaseService.client.rpc(
        'revoke_photo_access',
        params: {'p_request_id': requestId},
      );
      return result.toString();
    } on PostgrestException catch (error) {
      throw StateError(_cleanMessage(error.message));
    }
  }

  void _requireSession() {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null) {
      throw StateError('Please sign in again to manage photo privacy.');
    }
  }

  String _cleanMessage(String message) {
    final firstLine = message.split('\n').first.trim();
    return firstLine.isEmpty
        ? 'Photo privacy could not be updated.'
        : firstLine;
  }
}
