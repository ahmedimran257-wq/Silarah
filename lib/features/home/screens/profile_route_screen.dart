import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';

import '../../../core/models/discovery_profile.dart';
import '../../../core/services/photo_access_service.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/services/authorized_profile_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/silarah_compute.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'profile_detail_screen.dart';

/// The member cannot see this profile (hidden, blocked, deleted).
class _ProfileUnavailable implements Exception {
  const _ProfileUnavailable();
}

class ProfileRouteScreen extends StatefulWidget {
  const ProfileRouteScreen({super.key, required this.profileIdentifier});

  final String profileIdentifier;

  /// What the member is told when the profile cannot be shown: one of two
  /// plain messages, never an internal error's text.
  @visibleForTesting
  static String messageFor(Object error) => error is _ProfileUnavailable
      ? 'This profile is unavailable.'
      : 'This profile could not be opened.';

  /// The failure when the server returns no profile this member may see.
  @visibleForTesting
  static const Exception unavailable = _ProfileUnavailable();

  @override
  State<ProfileRouteScreen> createState() => _ProfileRouteScreenState();
}

class _ProfileRouteScreenState extends State<ProfileRouteScreen> {
  DiscoveryProfile? _profile;
  bool _isMutual = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.profileIdentifier.trim();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      setState(() => _error = 'This profile link is invalid.');
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        PhotoAccessService.instance.getContext(id),
        AuthorizedProfileService.load([id]),
        SupabaseService.client.rpc(
          'get_prior_match_context',
          params: {
            'p_candidate_user_ids': [id],
          },
        ),
      ]);
      final context = results[0] as PhotoAccessContext;
      final authorized = results[1] as List<Map<String, dynamic>>;
      final raw = authorized.isEmpty ? null : authorized.first;
      if (raw == null) throw ProfileRouteScreen.unavailable;
      final row = Map<String, dynamic>.from(raw);
      final relationshipRows = results[2] as List<dynamic>;
      if (relationshipRows.isNotEmpty) {
        row.addAll(
          Map<String, dynamic>.from(relationshipRows.first as Map),
        );
      }
      row['photo_count'] = context.photoCount;
      row['photo_privacy'] = switch (context.privacy) {
        ProfilePhotoPrivacy.mutualOnly => 'mutual_only',
        ProfilePhotoPrivacy.requestOnly => 'request_only',
        ProfilePhotoPrivacy.public => 'public',
      };
      if (context.canView) {
        final ownerId = row['user_id'].toString();
        final slots = await ProfilePhotoService.instance
            .getVisiblePhotoSlots(ownerUserId: ownerId);
        final urls = slots.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        row['photo_urls'] =
            urls.map((entry) => entry.value).toList(growable: false);
        if (urls.isNotEmpty) row['photo_url'] = urls.first.value;
      }
      final profile = mapDbRowToDiscoveryProfile(row);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isMutual = context.isMutual;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ProfileRouteScreen.messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile != null) {
      return ProfileDetailScreen(
        profile: profile,
        heroTag: 'linked-profile-${profile.id}',
        isMutualMatch: _isMutual,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianNight,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Center(
        child: _error == null
            ? const SilarahPulseLoader(size: 52)
            : Padding(
                padding: const EdgeInsets.all(AppDimensions.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off_outlined,
                        color: AppColors.slateMist, size: 46),
                    const SizedBox(height: AppDimensions.space16),
                    UiText(_error!,
                        style: AppTypography.bodyMuted,
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppDimensions.space16),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _error = null);
                        _load();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: UiText(
                          AppLocalizations.of(context).common_button_retry),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
