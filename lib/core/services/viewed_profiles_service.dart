import 'package:flutter/foundation.dart';

import '../utils/member_name.dart';
import 'profile_photo_service.dart';
import 'supabase_service.dart';

/// One profile the member opened in discovery during the last 30 days.
@immutable
class ViewedProfileEntry {
  const ViewedProfileEntry({
    required this.userId,
    required this.firstName,
    required this.lastNameInitial,
    required this.age,
    required this.cityName,
    required this.isVerified,
    required this.photoPrivacy,
    required this.photoCount,
    required this.lastViewedAt,
    this.blurhash,
    this.photoUrl,
  });

  factory ViewedProfileEntry.fromRow(Map<String, dynamic> row) {
    return ViewedProfileEntry(
      userId: row['user_id']?.toString() ?? '',
      firstName: row['first_name']?.toString() ?? '',
      lastNameInitial: row['last_name_initial']?.toString() ?? '',
      age: (row['age'] as num?)?.toInt() ?? 0,
      cityName: row['city_name']?.toString() ?? '',
      isVerified: row['is_verified'] == true,
      photoPrivacy: row['photo_privacy']?.toString() ?? 'public',
      photoCount: (row['photo_count'] as num?)?.toInt() ?? 0,
      blurhash: row['blurhash']?.toString(),
      lastViewedAt:
          DateTime.tryParse(row['last_viewed_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  final String userId;
  final String firstName;
  final String lastNameInitial;
  final int age;
  final String cityName;
  final bool isVerified;
  final String photoPrivacy;
  final int photoCount;
  final String? blurhash;
  final DateTime lastViewedAt;
  final String? photoUrl;

  String get displayName => memberDisplayName(firstName, lastNameInitial);

  bool get hasPhotos => photoCount > 0;

  ViewedProfileEntry withPhotoUrl(String? url) => ViewedProfileEntry(
        userId: userId,
        firstName: firstName,
        lastNameInitial: lastNameInitial,
        age: age,
        cityName: cityName,
        isVerified: isVerified,
        photoPrivacy: photoPrivacy,
        photoCount: photoCount,
        lastViewedAt: lastViewedAt,
        blurhash: blurhash,
        photoUrl: url,
      );
}

/// Reads the member's own recently viewed profiles. The server decides what
/// is listed (live, unblocked, not hidden by incognito) and the photo signer
/// still enforces each owner's photo privacy, so a private photo stays
/// private here exactly as it does in discovery.
class ViewedProfilesService {
  ViewedProfilesService._();

  static final ViewedProfilesService instance = ViewedProfilesService._();

  static const int pageLimit = 60;
  static const int _photoBatch = 50;

  Future<List<ViewedProfileEntry>> load() async {
    if (!SupabaseService.isInitialized) return const [];
    final raw = await SupabaseService.client.rpc(
      'get_my_viewed_profiles',
      params: {'p_limit': pageLimit},
    );
    if (raw is! List) return const [];
    final entries = raw
        .whereType<Map>()
        .map((row) => ViewedProfileEntry.fromRow(Map<String, dynamic>.from(row)))
        .where((entry) => entry.userId.isNotEmpty)
        .toList(growable: false);

    final withPhotos = entries
        .where((entry) => entry.hasPhotos)
        .map((entry) => entry.userId)
        .toList(growable: false);
    final urls = <String, String>{};
    for (var start = 0; start < withPhotos.length; start += _photoBatch) {
      final end = (start + _photoBatch).clamp(0, withPhotos.length);
      try {
        urls.addAll(await ProfilePhotoService.instance.getAuthorizedPhotoUrls(
          ownerUserIds: withPhotos.sublist(start, end),
        ));
      } catch (error) {
        // A failed signing batch leaves those tiles on their placeholder;
        // the names and details still load.
        debugPrint('[ViewedProfilesService] photo links skipped: $error');
      }
    }
    return entries
        .map((entry) => entry.withPhotoUrl(urls[entry.userId]))
        .toList(growable: false);
  }
}
