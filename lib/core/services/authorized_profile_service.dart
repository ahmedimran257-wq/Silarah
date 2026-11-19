import 'package:flutter/foundation.dart';

import '../models/discovery_profile.dart';
import '../utils/silarah_compute.dart';
import 'profile_photo_service.dart';
import 'supabase_service.dart';

/// Reads the server's explicit member projection. The RPC proves that each
/// requested profile came from discovery or an existing member relationship;
/// callers never receive the base profiles row.
class AuthorizedProfileService {
  AuthorizedProfileService._();

  static Future<List<Map<String, dynamic>>> load(
    Iterable<String> userIds,
  ) async {
    final ids = userIds
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(50)
        .toList(growable: false);
    if (ids.isEmpty) return const [];
    final raw = await SupabaseService.client.rpc(
      'get_authorized_member_profiles',
      params: {'p_user_ids': ids},
    );
    if (raw is! List) return const [];
    return raw.map<Map<String, dynamic>>((item) {
      if (item is Map && item.length == 1) {
        final nested = item['get_authorized_member_profiles'];
        if (nested is Map) return Map<String, dynamic>.from(nested);
      }
      return Map<String, dynamic>.from(item as Map);
    }).toList(growable: false);
  }

  /// Resolves a bounded set of authorized members and their approved primary
  /// photos in three batched calls. Shortlists and saved-profile surfaces use
  /// this method so they never issue one profile or signing request per card.
  static Future<List<DiscoveryProfile>> loadDiscoveryProfiles(
    Iterable<String> userIds,
  ) async {
    final mappedRows = await load(userIds);
    if (mappedRows.isEmpty) return const [];

    final profileIds = mappedRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    if (profileIds.isEmpty) return const [];

    final photos = await SupabaseService.client
        .from('photos')
        .select('profile_id, blurhash')
        .inFilter('profile_id', profileIds)
        .eq('status', 'active')
        .eq('admin_approved', true)
        .eq('nsfw_cleared', true)
        .order('order_index');

    final photosByProfile = <String, List<Map<String, dynamic>>>{};
    for (final photo in (photos as List<dynamic>).whereType<Map>()) {
      final mapped = Map<String, dynamic>.from(photo);
      final profileId = mapped['profile_id']?.toString();
      if (profileId == null) continue;
      photosByProfile.putIfAbsent(profileId, () => []).add(mapped);
    }

    final ownersWithPhotos = mappedRows
        .where(
            (row) => photosByProfile[row['id']?.toString()]?.isNotEmpty == true)
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    // A photo-signing failure (offline, an expired session, a rate limit)
    // must not hide the profiles themselves: they open with their photo
    // placeholder instead of failing as "not available".
    var signedUrls = const <String, String>{};
    try {
      signedUrls = await ProfilePhotoService.instance.getAuthorizedPhotoUrls(
        ownerUserIds: ownersWithPhotos,
      );
    } catch (error) {
      debugPrint('[AuthorizedProfileService] photo links skipped: $error');
    }

    for (final row in mappedRows) {
      final profileId = row['id']?.toString();
      final profilePhotos =
          profileId == null ? null : photosByProfile[profileId];
      row['photo_count'] = profilePhotos?.length ?? 0;
      if (profilePhotos?.isNotEmpty == true) {
        final ownerUserId = row['user_id']?.toString();
        if (ownerUserId != null && ownerUserId.isNotEmpty) {
          row['photo_url'] = signedUrls[ownerUserId];
          row['blurhash'] = profilePhotos!.first['blurhash'];
        }
      }
    }
    return mappedRows.map(mapDbRowToDiscoveryProfile).toList(growable: false);
  }
}
