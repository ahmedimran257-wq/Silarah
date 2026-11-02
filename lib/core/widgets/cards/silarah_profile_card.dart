// The SILARAH Card — "The Discovery Engine"
// "The most critical component. It must look like a
//  luxury portfolio cover."
//
// Ratio: 7:10 editorial portrait
// Frame: one uninterrupted, theme-aware perimeter above the media.
// Gradient: Transparent (top) → 30% Obsidian (mid) → 100% Obsidian (bottom)
// Name: Playfair Display 24px, bottom-left
// Location: Inter 14px, below name
// Focus effect: center card scale 1.0, adjacent cards scale 0.95
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_curves.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import '../buttons/silarah_pressable.dart';
import '../loaders/silarah_blur_image.dart';
import '../loaders/silarah_shimmer.dart';
import 'profile_card_box.dart';

class SilarahProfileCard extends StatelessWidget {
  const SilarahProfileCard({
    super.key,
    required this.displayName,
    required this.age,
    required this.cityName,
    this.sect,
    this.deenLevel,
    this.profession,
    this.photoUrl,
    this.photoCount = 0,
    this.isPhotoPrivate = false,
    this.isVerified = false,
    this.isGuardianManaged = false,
    this.isFocused = true, // Controls the scale focus effect
    this.onTap,
    this.onSendInterest,
    this.onBookmark,
    this.isBookmarked = false,
    this.interestActionLabel = 'Send Interest',
    this.isInterestActionEnabled = true,
    this.lastActiveLabel,
    this.previousMatchLabel,
    this.cardScale = 1.0,
    this.blurhash,
    this.photoHeroTag,
  });

  final String displayName;
  final int age;
  final String cityName;
  final String? sect;
  final String? deenLevel;
  final String? profession; // blueprint: shown on card below location
  final String? photoUrl;
  final int photoCount;
  final bool isPhotoPrivate;
  final bool isVerified;
  final bool isGuardianManaged;
  final bool isFocused;
  final VoidCallback? onTap;
  final VoidCallback? onSendInterest;
  final VoidCallback? onBookmark;
  final bool isBookmarked;
  final String interestActionLabel;
  final bool isInterestActionEnabled;
  final String? lastActiveLabel;
  final String? previousMatchLabel;
  final double cardScale; // Continuous scale driven by scroll offset
  final String? blurhash;
  final Object? photoHeroTag;

  @override
  Widget build(BuildContext context) {
    // A hairline edge reads as finish; a coloured outline reads as a widget.
    final frameColor =
        AppColors.onMedia.withValues(alpha: isFocused ? .12 : .08);

    return Transform.scale(
      scale: cardScale,
      child: SilarahPressable(
        onTap: onTap,
        child: ProfileCardBox(
          child: Container(
            key: const Key('discovery_profile_card_frame'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfacePanelTop,
                  AppColors.obsidianNight,
                ],
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 32,
                        spreadRadius: -10,
                        offset: const Offset(0, 18),
                      ),
                    ]
                  : null,
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(
                color: frameColor,
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo Layer
                if (photoHeroTag != null)
                  Hero(
                    tag: photoHeroTag!,
                    child: _ProfileCardPhoto(
                      photoUrl: photoUrl,
                      blurhash: blurhash,
                      photoCount: photoCount,
                      isPhotoPrivate: isPhotoPrivate,
                    ),
                  )
                else
                  _ProfileCardPhoto(
                    photoUrl: photoUrl,
                    blurhash: blurhash,
                    photoCount: photoCount,
                    isPhotoPrivate: isPhotoPrivate,
                  ),

                // ── Gradient Overlay (always on top of photo)
                const _GradientOverlay(),

                // Content Layer
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    child: Column(
                      children: [
                        // Top row: photo count + activity, clear of the portrait.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Photo count pill — public, multiple photos
                            if (!isPhotoPrivate && photoCount > 1)
                              _PhotoCountPill(count: photoCount)
                            else if (isPhotoPrivate && photoCount > 0)
                              _PrivatePhotoCountPill(count: photoCount),

                            // Activity remains independent of ID verification.
                            const Spacer(),
                            if (lastActiveLabel != null &&
                                lastActiveLabel!.isNotEmpty)
                              _LastActivePill(label: lastActiveLabel!)
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                        const Spacer(),

                        // Names + location + chips — bottom
                        Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              UiText(
                                displayName,
                                style: AppTypography.userName.copyWith(
                                  color: AppColors.onMedia,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  height: 1.12,
                                  shadows: const [
                                    Shadow(
                                      color: AppColors.overlayBlack55,
                                      blurRadius: 12,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppDimensions.space6),

                              // Age · City
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 15,
                                    color: Color(0xD9F8F8FA),
                                  ),
                                  const SizedBox(width: AppDimensions.space4),
                                  Expanded(
                                    child: UiText(
                                      '$age · $cityName',
                                      style:
                                          AppTypography.cardLocation.copyWith(
                                        color: AppColors.onMedia.withValues(
                                          alpha: 0.88,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(
                                      width: AppDimensions.space8,
                                    ),
                                    _VerifiedBadge(),
                                  ],
                                ],
                              ),

                              if (previousMatchLabel != null) ...[
                                const SizedBox(height: AppDimensions.space8),
                                _PreviousMatchPill(label: previousMatchLabel!),
                              ],

                              if (isGuardianManaged) ...[
                                const SizedBox(height: AppDimensions.space8),
                                const _GuardianManagedPill(),
                              ],

                              // Profession line
                              if (profession != null &&
                                  previousMatchLabel == null &&
                                  !isGuardianManaged) ...[
                                const SizedBox(height: AppDimensions.space8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.work_outline_rounded,
                                      size: 14,
                                      color: AppColors.onMedia.withValues(
                                        alpha: 0.68,
                                      ),
                                    ),
                                    const SizedBox(width: AppDimensions.space6),
                                    Expanded(
                                      child: UiText(
                                        profession!,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.onMedia.withValues(
                                            alpha: 0.74,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // Chips row
                              if (sect != null || deenLevel != null) ...[
                                const SizedBox(height: AppDimensions.space10),
                                Wrap(
                                  spacing: AppDimensions.space8,
                                  runSpacing: AppDimensions.space6,
                                  children: [
                                    if (sect != null)
                                      _InfoChip(label: _formatSect(sect!)),
                                    if (deenLevel != null)
                                      _InfoChip(label: _formatDeen(deenLevel!)),
                                  ],
                                ),
                              ],

                              const SizedBox(height: AppDimensions.space14),

                              // Action row: bookmark + send interest
                              SizedBox(
                                child: Row(
                                  children: [
                                    _IconActionButton(
                                      icon: isBookmarked
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_outline_rounded,
                                      isActive: isBookmarked,
                                      onTap: onBookmark,
                                      tooltip: isBookmarked
                                          ? 'Remove saved profile'
                                          : 'Save profile',
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.space8,
                                    ),
                                    Expanded(
                                      child: _SendInterestButton(
                                        label: interestActionLabel,
                                        enabled: isInterestActionEnabled,
                                        onTap: onSendInterest,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Stored sects can be upper-case enum names; chips read in title case.
  String _formatSect(String raw) {
    if (raw != raw.toUpperCase()) return raw;
    return raw.toLowerCase().replaceAllMapped(
          RegExp(r'(^|[\s/(-])([a-z])'),
          (m) => '${m[1]}${m[2]!.toUpperCase()}',
        );
  }

  String _formatDeen(String raw) {
    switch (raw) {
      case 'practicing':
        return 'Practicing';
      case 'moderate':
        return 'Moderate';
      case 'cultural':
        return 'Cultural';
      default:
        return raw;
    }
  }
}

class _ProfileCardPhoto extends StatelessWidget {
  const _ProfileCardPhoto({
    required this.photoUrl,
    required this.blurhash,
    required this.photoCount,
    required this.isPhotoPrivate,
  });

  final String? photoUrl;
  final String? blurhash;
  final int photoCount;
  final bool isPhotoPrivate;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && !isPhotoPrivate) {
      return _PhotoLayer(url: photoUrl!, blurhash: blurhash);
    }
    return _PrivatePhotoPlaceholder(
      photoCount: photoCount,
      isPrivate: isPhotoPrivate,
    );
  }
}

// Sub-widgets
class _PhotoLayer extends StatelessWidget {
  const _PhotoLayer({required this.url, this.blurhash});
  final String url;
  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    return SilarahBlurImage(
      imageUrl: url,
      blurhash: blurhash,
      fit: BoxFit.cover,
    );
  }
}

class _PrivatePhotoPlaceholder extends StatelessWidget {
  const _PrivatePhotoPlaceholder({
    required this.photoCount,
    required this.isPrivate,
  });
  final int photoCount;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceGlassHover,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gold ring silhouette placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldBorder,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: AppColors.slateMist,
                size: 40,
              ),
            ),
            if (isPrivate && photoCount > 0) ...[
              const SizedBox(height: AppDimensions.space12),
              UiText(
                '$photoCount photo${photoCount > 1 ? 's' : ''} · visible after acceptance',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x08000000),
            Color(0x18000000),
            Color(0xB8000000),
            Color(0xFA000000),
          ],
          stops: [0.0, 0.38, 0.68, 1.0],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trustColor = AppColors.verifiedTeal;

    return Semantics(
      label: context.uiCopy('Profile photo verified'),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space8,
          vertical: AppDimensions.space4,
        ),
        decoration: BoxDecoration(
          color: AppColors.overlayBlack55,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: trustColor.withValues(alpha: 0.72),
            width: AppDimensions.borderThin,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.face_retouching_natural_rounded,
              color: trustColor,
              size: 13,
            ),
            const SizedBox(width: AppDimensions.space4),
            UiText(
              context.uiCopy('Photo'),
              style: AppTypography.caption.copyWith(
                color: trustColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianManagedPill extends StatelessWidget {
  const _GuardianManagedPill();

  @override
  Widget build(BuildContext context) {
    final color = AppColors.champagneLight;
    return Semantics(
      label: context.uiCopy('Guardian-managed profile'),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space8,
          vertical: AppDimensions.space4,
        ),
        decoration: BoxDecoration(
          color: AppColors.overlayBlack55,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(color: color.withValues(alpha: 0.72)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom_rounded, color: color, size: 13),
            const SizedBox(width: AppDimensions.space4),
            UiText(
              context.uiCopy('Guardian-managed profile'),
              style: AppTypography.caption.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviousMatchPill extends StatelessWidget {
  const _PreviousMatchPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space10,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack55,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.onMedia.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history_rounded,
            color: AppColors.onMedia.withValues(alpha: 0.88),
            size: 14,
          ),
          const SizedBox(width: AppDimensions.space6),
          Expanded(
            child: UiText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.onMedia.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCountPill extends StatelessWidget {
  const _PhotoCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack45,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.onMedia.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined,
              color: AppColors.onMedia, size: 12),
          const SizedBox(width: AppDimensions.space4),
          UiText(
            '$count',
            style: AppTypography.caption.copyWith(
              color: AppColors.onMedia,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivatePhotoCountPill extends StatelessWidget {
  const _PrivatePhotoCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack45,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.onMedia.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.onMedia,
            size: 12,
          ),
          const SizedBox(width: AppDimensions.space4),
          UiText(
            '$count',
            style: AppTypography.caption.copyWith(
              color: AppColors.onMedia,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.onMedia.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.onMedia.withValues(alpha: 0.20),
          width: 0.75,
        ),
      ),
      child: UiText(
        label,
        style: AppTypography.chipLabel.copyWith(
          color: AppColors.onMedia.withValues(alpha: 0.94),
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SendInterestButton extends StatelessWidget {
  const _SendInterestButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSending = label == 'Sending...';
    final isConfirmed = label == 'Interest Sent';
    final isInteractive = enabled && onTap != null;
    final enabledColors = [
      AppColors.champagneLight,
      AppColors.champagneGold,
      AppColors.antiqueGold,
    ];
    final foreground = isInteractive
        ? AppColors.readableOn(enabledColors[1])
        : AppColors.onMedia.withValues(alpha: 0.88);
    final glowColor = AppColors.champagneGold.withValues(alpha: 0.3);

    return SilarahPressable(
      onTap: onTap,
      enabled: isInteractive,
      semanticLabel: label,
      child: AnimatedContainer(
        key: const Key('discovery_interest_action'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 50,
        decoration: BoxDecoration(
          gradient: !isInteractive
              ? const LinearGradient(
                  colors: [
                    Color(0xFF323235),
                    Color(0xFF202023),
                    AppColors.overlayBlack87,
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: enabledColors,
                ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: !isInteractive
                ? AppColors.onMedia.withValues(alpha: 0.16)
                : AppColors.champagneLight.withValues(alpha: 0.45),
            width: 0.75,
          ),
          boxShadow: !isInteractive
              ? null
              : [
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 22,
                    spreadRadius: -5,
                    offset: const Offset(0, 10),
                  ),
                  const BoxShadow(
                    color: AppColors.overlayBlack45,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            reverseDuration: const Duration(milliseconds: 180),
            switchInCurve: AppCurves.tactile,
            switchOutCurve: AppCurves.dismiss,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: .975, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: Row(
              key: ValueKey(label),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSending) ...[
                  SilarahActivityIndicator(
                    size: 16,
                    color: foreground,
                  ),
                  const SizedBox(width: AppDimensions.space8),
                ] else if (isConfirmed) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: AppDimensions.space8),
                ] else ...[
                  Icon(
                    Icons.favorite_rounded,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: AppDimensions.space8),
                ],
                Flexible(
                  child: UiText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.button.copyWith(
                      color: foreground,
                      fontSize: 14.5,
                      fontWeight:
                          isInteractive ? FontWeight.w800 : FontWeight.w700,
                      letterSpacing: isInteractive ? 0.1 : 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    this.isActive = false,
    this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: onTap,
      semanticLabel: tooltip,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.onMedia
              : AppColors.onMedia.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.onMedia.withValues(alpha: isActive ? 0 : 0.24),
            width: 0.75,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.overlayBlack87 : AppColors.onMedia,
          size: AppDimensions.iconSizeMedium,
        ),
      ),
    );
  }
}

// Last active stays visible alongside the identity badge.
class _LastActivePill extends StatelessWidget {
  const _LastActivePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isOnline = label == 'Online now';
    final activeColor = isOnline
        ? AppColors.onlineGreen
        : AppColors.onMedia.withValues(alpha: 0.58);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack45,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.onMedia.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeColor,
            ),
          ),
          const SizedBox(width: AppDimensions.space4),
          UiText(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.onMedia,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
