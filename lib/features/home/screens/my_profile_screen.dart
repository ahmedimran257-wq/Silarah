// SILARAH — My Profile Screen
// Self-view: completeness bar, boost section, profile views
// row, saved profiles, settings sections, sign out.
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/cubits/subscription/subscription_state.dart';
import '../../../core/cubits/account_standing/account_standing_cubit.dart';
import '../../../core/cubits/account_standing/account_standing_state.dart';
import '../../../core/cubits/notifications/notifications_cubit.dart';
import '../../../core/models/discovery_profile.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/services/billing_portal_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/my_account_snapshot.dart';
import '../../../core/services/authorized_profile_service.dart';
import '../../../core/services/incognito_service.dart';
import '../../../core/services/photo_verification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/silarah_empty_state.dart';
import '../../../core/widgets/loaders/silarah_blur_image.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import 'profile_views_screen.dart';
import 'profile_detail_screen.dart';
import 'notifications_screen.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/services/profile_view_service.dart';
import '../../../core/services/wali_mode_service.dart';
import '../../onboarding/screens/photo_upload_screen.dart';
import '../widgets/profile_header_action_rail.dart';
import '../widgets/profile_quality_card.dart';

// Completeness score
({int score, ProfileQualityStep? next}) _calcCompleteness(
  OnboardingData d, {
  required int approvedPhotoCount,
}) {
  int score = 0;
  final hasPrimaryPhoto = approvedPhotoCount > 0;
  if (hasPrimaryPhoto) score += 25;
  final hasBio = (d.bio?.length ?? 0) >= 50;
  if (hasBio) score += 15;
  final hasIslamic = d.sect != null && d.deenLevel != null;
  if (hasIslamic) score += 15;
  final hasEduPro = (d.educationLabel != null || d.educationRank != null) &&
      (d.profession?.isNotEmpty ?? false);
  if (hasEduPro) score += 10;
  final hasFamily = d.familyType != null;
  if (hasFamily) score += 10;
  final hasPartnerPrefs =
      d.preferredAgeMin != null && d.preferredAgeMax != null;
  if (hasPartnerPrefs) score += 10;
  final hasSecondPhoto = approvedPhotoCount >= 2;
  if (hasSecondPhoto) score += 8;
  final hasIncome = d.incomeBracketId != null;
  if (hasIncome) score += 4;
  final hasLangs = d.languages != null && d.languages!.isNotEmpty;
  if (hasLangs) score += 3;

  // The first missing item, in the order the card suggests them.
  final missing = [
    (hasPrimaryPhoto, ProfileQualityStep.photo),
    (hasBio, ProfileQualityStep.bio),
    (hasIslamic, ProfileQualityStep.deen),
    (hasEduPro, ProfileQualityStep.education),
    (hasFamily, ProfileQualityStep.family),
    (hasPartnerPrefs, ProfileQualityStep.partnerPreferences),
    (hasSecondPhoto, ProfileQualityStep.secondPhoto),
    (hasIncome, ProfileQualityStep.income),
    (hasLangs, ProfileQualityStep.languages),
  ].where((item) => !item.$1);
  final next = missing.isEmpty ? null : missing.first.$2;

  return (score: score.clamp(0, 100), next: next);
}

// Screen
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key, this.refreshToken = 0});

  final int refreshToken;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<DiscoveryProfile> _savedProfiles = [];
  bool _guardianEnabled = false;
  bool _hasVerificationBadge = false;
  bool _verificationLoading = true;
  bool _trustStateLoading = true;
  bool _emailVerified = false;
  PhotoVerificationStatus _photoVerificationStatus =
      const PhotoVerificationStatus.notStarted();
  bool _establishedMember = false;
  String? _accountEmail;
  String? _primaryPhotoUrl;
  int _approvedPhotoCount = 0;
  // False until the server has answered once, so a failed read is never
  // shown as "you have no photos".
  bool _photoCountKnown = false;
  bool _profileRefreshFailed = false;
  Timer? _profileRetryTimer;
  bool _profileQuietRetryUsed = false;
  bool _photoRefreshInFlight = false;
  bool _profilePreviewOpening = false;
  bool _profileRefreshInFlight = false;
  IncognitoSetting? _incognito;
  DateTime? _lastProfileRefreshAt;
  static const _profileFreshness = Duration(minutes: 5);

  int _unseenViewCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshProfileFromDb());
    _loadBookmarks();
  }

  @override
  void didUpdateWidget(covariant MyProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_refreshProfileFromDb(force: true));
      unawaited(_loadBookmarks(force: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshProfileFromDb());
      unawaited(_loadViewActivity());
      unawaited(_loadIncognito(force: true));
    }
  }

  @override
  void dispose() {
    _profileRetryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadBookmarks({bool force = false}) async {
    try {
      final ids = await BookmarkService.load(force: force);
      await _loadSavedProfiles(ids);
    } catch (_) {
      if (mounted) setState(() => _savedProfiles = []);
    }
  }

  Future<void> _loadSavedProfiles(Set<String> ids) async {
    if (ids.isEmpty || !SupabaseService.isInitialized) {
      if (mounted) setState(() => _savedProfiles = []);
      return;
    }

    try {
      final profiles =
          await AuthorizedProfileService.loadDiscoveryProfiles(ids.take(20));
      if (mounted) setState(() => _savedProfiles = profiles);
    } catch (_) {
      if (mounted) setState(() => _savedProfiles = []);
    }
  }

  Future<void> _loadGuardian() async {
    if (SupabaseService.isInitialized) {
      final info = await WaliModeService.instance.getMyGuardianInfo();
      if (mounted) setState(() => _guardianEnabled = info?.isLinked == true);
    }
  }

  Future<void> _loadIncognito({bool force = false}) async {
    try {
      final setting = await IncognitoService.instance.load(force: force);
      if (mounted) setState(() => _incognito = setting);
    } catch (_) {}
  }

  Future<void> _loadVerificationBadge() async {
    var hasBadge = false;
    if (SupabaseService.isInitialized) {
      try {
        final status = await PhotoVerificationService.instance.fetchStatus();
        hasBadge = status.isApproved;
        _photoVerificationStatus = status;
      } catch (_) {
        hasBadge = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _hasVerificationBadge = hasBadge;
      _verificationLoading = false;
    });
  }

  Future<void> _openVerification() async {
    await context.push(AppRoutes.badgeVerification);
    if (!mounted) return;
    await Future.wait([_loadVerificationBadge(), _loadTrustState()]);
  }

  Future<void> _openGuardianSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(initialSection: 'guardian'),
      ),
    );
    if (!mounted) return;
    await Future.wait([_loadGuardian(), _loadTrustState()]);
  }

  Future<void> _openEditProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const EditProfileScreen(),
      ),
    );
    if (changed == true && mounted) await _refreshProfileFromDb(force: true);
  }

  Future<void> _openManagePhotos() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PhotoUploadScreen(returnToPreviousOnSave: true),
      ),
    );
    if (saved == true && mounted) {
      await _refreshProfileFromDb(force: true);
    }
  }

  Future<void> _openOwnProfilePreview() async {
    if (_profilePreviewOpening) return;
    setState(() => _profilePreviewOpening = true);
    try {
      await _performOpenOwnProfilePreview();
    } finally {
      if (mounted) setState(() => _profilePreviewOpening = false);
    }
  }

  Future<void> _performOpenOwnProfilePreview() async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (!mounted || userId == null) return;
    Map<int, String> photoSlots;
    try {
      photoSlots = await ProfilePhotoService.instance.getMyPhotoSlots();
    } catch (_) {
      if (!mounted) return;
      var offline = false;
      if (ConnectivityService.isInitialized) {
        await ConnectivityService.instance.checkNow();
        offline = !ConnectivityService.instance.hasNetworkInterface;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(
            offline
                ? 'No internet connection. Connect to open your photo gallery.'
                : 'Your photo gallery could not be opened. Try again.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    final orderedPhotoUrls = photoSlots.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final galleryUrls = orderedPhotoUrls
        .map((entry) => entry.value)
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    final refreshedPhotoUrl = galleryUrls.isEmpty ? null : galleryUrls.first;
    if (refreshedPhotoUrl != null && refreshedPhotoUrl.isNotEmpty) {
      setState(() => _primaryPhotoUrl = refreshedPhotoUrl);
    }
    final data = context.read<OnboardingCubit>().currentData;
    final lastName = data.lastName?.trim() ?? '';
    final profile = DiscoveryProfile(
      id: userId,
      firstName: data.firstName?.trim().isNotEmpty == true
          ? data.firstName!.trim()
          : 'Your profile',
      lastNameInitial: lastName.isEmpty ? '' : lastName.characters.first,
      lastName: lastName.isEmpty ? null : lastName,
      age: data.age ?? 18,
      cityName: data.cityName?.trim().isNotEmpty == true
          ? data.cityName!.trim()
          : 'Location not set',
      countryCode: data.countryCode,
      sect: data.sect?.name,
      deenLevel: data.deenLevel?.name,
      photoUrl: refreshedPhotoUrl ?? _primaryPhotoUrl,
      photoUrls: galleryUrls,
      photoCount: galleryUrls.length,
      photoPrivacy: data.photoPrivacy == PhotoPrivacy.mutualOnly
          ? 'mutual_only'
          : data.photoPrivacy == PhotoPrivacy.requestOnly
              ? 'request_only'
              : 'public',
      isVerified: _hasVerificationBadge,
      occupation: data.profession,
      education: data.educationLabel,
      bio: data.bio,
      languages: data.languages,
      maritalStatus: data.maritalStatus?.name,
      familyType: data.familyType?.name,
      interests: data.interests,
      partnerAgeMin: data.preferredAgeMin,
      partnerAgeMax: data.preferredAgeMax,
      partnerSect: data.preferredSect,
      partnerDeenLevel: data.preferredDeenLevel,
      partnerEducationMinRank: data.minEducationRank,
      heightCm: data.heightCm,
      complexion: data.complexion,
      motherTongue: data.motherTongue,
      smokingHabit: data.smokingHabit,
      vapingHabit: data.vapingHabit,
      hookahHabit: data.hookahHabit,
      isGuardianProfile: data.profileOwnerType == ProfileOwnerType.guardian ||
          data.isGuardianMode,
      community: data.community,
      dietType: data.dietType,
      livingExpectation: data.livingExpectation,
      quranMemorization: data.quranMemorization,
      religiousEducation: data.religiousEducation,
      marriageTimeline: data.marriageTimeline,
      willingToRelocate: data.willingToRelocate,
      gender: data.gender?.name,
      hasChildren: data.hasChildren ?? false,
      incomeBracket: data.incomeBracketLabel,
    );

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailScreen(
          profile: profile,
          heroTag: 'own-profile-preview-$userId',
          isOwnProfile: true,
          onEditOwnProfile: () {
            Navigator.of(context).pop();
            unawaited(_openEditProfile());
          },
          onManageOwnPhotos: () {
            Navigator.of(context).pop();
            unawaited(_openManagePhotos());
          },
        ),
      ),
    );
  }

  Future<void> _loadTrustState() async {
    if (!SupabaseService.isInitialized) return;
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) return;

    try {
      final photo = await PhotoVerificationService.instance.fetchStatus();
      final authUser = SupabaseService.client.auth.currentUser;
      final accountCreatedAt = authUser == null
          ? null
          : DateTime.tryParse(authUser.createdAt)?.toLocal();
      if (!mounted) return;
      setState(() {
        _photoVerificationStatus = photo;
        _hasVerificationBadge = photo.isApproved;
        _accountEmail = authUser?.email;
        _emailVerified = authUser?.emailConfirmedAt != null;
        _establishedMember = accountCreatedAt != null &&
            DateTime.now().difference(accountCreatedAt).inDays >= 30;
        _trustStateLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _trustStateLoading = false);
    }
  }

  Future<void> _refreshProfileFromDb({bool force = false}) async {
    if (!SupabaseService.isInitialized || _profileRefreshInFlight) return;
    final lastRefresh = _lastProfileRefreshAt;
    if (!force &&
        lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < _profileFreshness) {
      return;
    }
    _profileRefreshInFlight = true;
    try {
      await context.read<OnboardingCubit>().refreshProfileFromDb(force: force);
      await Future.wait([
        _loadPrimaryPhoto(),
        _loadApprovedPhotoCount(),
        _loadViewActivity(),
        _loadGuardian(),
        _loadVerificationBadge(),
        _loadTrustState(),
        _loadIncognito(force: force),
      ]);
      _lastProfileRefreshAt = DateTime.now();
      _profileQuietRetryUsed = false;
      if (mounted && _profileRefreshFailed) {
        setState(() => _profileRefreshFailed = false);
      }
    } catch (error) {
      // Usually the network waking up after unlock or resume. Say so and
      // try again once, shortly, instead of showing an empty-looking
      // profile. Only once per failure streak: while offline a repeating
      // timer would keep re-reading seven endpoints every few seconds. The
      // notice's Retry button, resume and tab revisits still refresh.
      debugPrint('[MyProfile] Profile refresh failed: $error');
      if (mounted) {
        setState(() => _profileRefreshFailed = true);
        _profileRetryTimer?.cancel();
        if (!_profileQuietRetryUsed) {
          _profileQuietRetryUsed = true;
          _profileRetryTimer = Timer(const Duration(seconds: 8), () {
            if (mounted) unawaited(_refreshProfileFromDb(force: true));
          });
        }
      }
    } finally {
      _profileRefreshInFlight = false;
    }
  }

  Future<void> _loadPrimaryPhoto() async {
    try {
      final url = await ProfilePhotoService.instance.getPrimaryPhotoUrl();
      if (mounted && url != null && url.isNotEmpty) {
        setState(() => _primaryPhotoUrl = url);
      }
    } catch (_) {}
  }

  Future<void> _recoverPrimaryPhoto(String failedUrl) async {
    if (_photoRefreshInFlight || failedUrl != _primaryPhotoUrl) return;
    _photoRefreshInFlight = true;
    try {
      final refreshedUrl =
          await ProfilePhotoService.instance.getPrimaryPhotoUrl(
        forceRefresh: true,
      );
      if (!mounted || refreshedUrl == null || refreshedUrl.isEmpty) return;
      setState(() => _primaryPhotoUrl = refreshedUrl);
    } finally {
      _photoRefreshInFlight = false;
    }
  }

  Future<void> _loadViewActivity() async {
    try {
      final summary = await ProfileViewService.instance.activitySummary();
      if (mounted) {
        setState(() => _unseenViewCount = summary.unseenViewerCount);
      }
    } catch (_) {}
  }

  Future<void> _openProfileViews() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileViewsScreen()),
    );
    if (mounted) await _loadViewActivity();
  }

  Future<void> _loadApprovedPhotoCount() async {
    try {
      final myUserId = await SupabaseService.currentUserIdOrRefresh();
      if (myUserId == null) return;
      final profile = await MyAccountSnapshot.instance.profile(myUserId);
      final profileId = profile?['id']?.toString();
      if (profileId == null || profileId.isEmpty) return;
      final rows = await SupabaseService.client
          .from('photos')
          .select('id')
          .eq('profile_id', profileId)
          .eq('status', 'active')
          .eq('admin_approved', true)
          .eq('nsfw_cleared', true);
      if (mounted) {
        setState(() {
          _approvedPhotoCount = rows.length;
          _photoCountKnown = true;
        });
      }
    } catch (_) {
      // Keep the last known count; an unreachable server is not zero photos.
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentProfile = context.watch<OnboardingCubit>().currentData;
    final guardianManaged =
        currentProfile.profileOwnerType == ProfileOwnerType.guardian ||
            currentProfile.isGuardianMode;
    return BlocListener<NotificationsCubit, NotificationsState>(
      listenWhen: (previous, current) =>
          previous.profileViewUnreadAlertCount !=
          current.profileViewUnreadAlertCount,
      listener: (context, state) {
        if (state.profileViewUnreadAlertCount > 0) {
          unawaited(_loadViewActivity());
        }
      },
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UiText(context.uiCopy('Profile'),
                            style: AppTypography.screenTitle),
                        const SizedBox(height: 2),
                        UiText(
                          'Your presence on Silarah',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  ProfileHeaderActionRail(
                    unseenViewCount: _unseenViewCount,
                    onProfileViews: _openProfileViews,
                    onNotifications: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                    onSettings: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                      if (!context.mounted) return;
                      await context.read<AccountStandingCubit>().refresh();
                      await _loadTrustState();
                      await _loadIncognito(force: true);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.space20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: BlocBuilder<AccountStandingCubit, AccountStandingState>(
                builder: (context, standing) => _ProfileLifecycleCard(
                  standing: standing,
                  incognitoEnabled: _incognito?.enabled == true,
                  onResume: () =>
                      context.read<AccountStandingCubit>().resumeProfile(),
                  onContactSupport: () => context.push(AppRoutes.helpSupport),
                  onManagePhotos: _openManagePhotos,
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.space16),

            // A failed renewal needs attention, so it stands apart at the top.
            const _SubscriptionCard.status(),

            BlocBuilder<SubscriptionCubit, SubscriptionState>(
              builder: (context, subscription) {
                if (!subscription.isTemporaryPromotional) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: _ReferralPremiumProfileBanner(
                    expiresAt: subscription.expiresAt,
                    isTest: subscription.isTestOnly,
                    onTap: () => context.push(AppRoutes.subscription),
                  ),
                );
              },
            ),

            if (_profileRefreshFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: _ProfileRefreshNotice(
                  onRetry: () => _refreshProfileFromDb(force: true),
                ),
              ),

            // Profile card preview (live completeness)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: BlocBuilder<OnboardingCubit, OnboardingState>(
                builder: (context, _) {
                  final data = context.read<OnboardingCubit>().currentData;
                  final result = _calcCompleteness(
                    data,
                    approvedPhotoCount: _approvedPhotoCount,
                  );
                  return _ProfilePreviewCard(
                    score: result.score,
                    nextStep: _photoCountKnown ? result.next : null,
                    data: data,
                    guardianManaged: guardianManaged,
                    hasVerificationBadge: _hasVerificationBadge,
                    verificationLoading: _verificationLoading,
                    onVerify: _openVerification,
                    onManagePhotos: _openManagePhotos,
                    onEditProfile: _openEditProfile,
                    onGuardian: _openGuardianSettings,
                    approvedPhotoCount: _approvedPhotoCount,
                    guardianLinked: _guardianEnabled,
                    primaryPhotoUrl: _primaryPhotoUrl,
                    onPhotoLoadFailed: _recoverPrimaryPhoto,
                  );
                },
              ),
            ),

            const SizedBox(height: AppDimensions.space16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ProfilePrimaryActions(
                onEdit: _openEditProfile,
                onPreview: _openOwnProfilePreview,
                previewOpening: _profilePreviewOpening,
              ),
            ),

            const SizedBox(height: AppDimensions.space16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _TrustCenterCard(
                loading: _trustStateLoading,
                photoStatus: _photoVerificationStatus,
                guardianConnected: _guardianEnabled,
                guardianManaged: guardianManaged,
                establishedMember: _establishedMember,
                email: _accountEmail,
                emailVerified: _emailVerified,
                onPhotoVerification: _openVerification,
                onGuardianConnection: _openGuardianSettings,
              ),
            ),

            const SizedBox(height: AppDimensions.space16),

            // Upgrade prompt for members without Premium.
            const _SubscriptionCard.upgrade(),

            // Boost Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _BoostSection(),
            ),

            const SizedBox(height: AppDimensions.space16),

            // Saved profiles section — always shown (empty state if none)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SavedProfilesSection(
                savedProfiles: _savedProfiles,
                onChanged: _loadBookmarks,
                onManage: () => context.push(AppRoutes.shortlist),
              ),
            ),

            const SizedBox(height: AppDimensions.space16),

            // Referral is intentionally below personal activity tools. It is a
            // growth action, not part of the member's primary profile workflow.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SilarahPressable(
                semanticLabel: context.uiCopy('Refer a Friend'),
                onTap: () => context.push(AppRoutes.referral),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color: AppColors.goldBorder.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.champagneGold.withValues(alpha: 0.02),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.space8),
                        decoration: BoxDecoration(
                          color:
                              AppColors.champagneGold.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.goldBorder),
                        ),
                        child: Icon(
                          Icons.card_giftcard_rounded,
                          color: AppColors.champagneGold,
                          size: AppDimensions.iconSizeMedium,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UiText(
                              context.uiCopy('Refer a Friend'),
                              style: AppTypography.bodyMedium,
                            ),
                            UiText(
                              context.uiCopy('Get 3 days of Premium for free'),
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.slateMist,
                        size: AppDimensions.iconSizeMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.space20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _HelpAndGrievanceCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(
                      initialSection: 'help',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _IFoundMyMatchButton(),
            ),
            const SizedBox(height: AppDimensions.space16),

            // Sign out
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              // A quiet exit: sign-out should not outweigh the actions above.
              child: SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(Icons.logout_rounded,
                      color: AppColors.softCoral,
                      size: AppDimensions.iconSizeMedium),
                  label: UiText(context.uiCopy('Sign Out'),
                      style: AppTypography.buttonSecondary
                          .copyWith(color: AppColors.softCoral)),
                  onPressed: () => context.read<AuthCubit>().signOut(),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space40),
          ],
        ),
      ),
    );
  }
}

// Boost Section
class _ProfilePrimaryActions extends StatelessWidget {
  const _ProfilePrimaryActions({
    required this.onEdit,
    required this.onPreview,
    required this.previewOpening,
  });

  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final bool previewOpening;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: SilarahPressable(
            semanticLabel: context.uiCopy('Edit your profile'),
            onTap: onEdit,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.champagneLight, AppColors.champagneGold],
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.champagneGold.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded,
                      size: 19, color: AppColors.obsidianNight),
                  const SizedBox(width: AppDimensions.space8),
                  UiText(context.uiCopy('Edit profile'),
                      style: AppTypography.button),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.space10),
        Expanded(
          flex: 5,
          child: SilarahPressable(
            semanticLabel: context.uiCopy('View your public profile'),
            onTap: previewOpening ? null : onPreview,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (previewOpening)
                    SilarahActivityIndicator(
                      size: 18,
                      color: AppColors.champagneGold,
                    )
                  else
                    Icon(
                      Icons.visibility_outlined,
                      size: 19,
                      color: AppColors.champagneGold,
                    ),
                  const SizedBox(width: AppDimensions.space8),
                  Flexible(
                    child: UiText(context.uiCopy('View profile'),
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.buttonSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileLifecycleCard extends StatelessWidget {
  const _ProfileLifecycleCard({
    required this.standing,
    required this.onResume,
    required this.onContactSupport,
    required this.onManagePhotos,
    required this.incognitoEnabled,
  });

  final AccountStandingState standing;
  final VoidCallback onResume;
  final VoidCallback onContactSupport;
  final VoidCallback onManagePhotos;
  final bool incognitoEnabled;

  @override
  Widget build(BuildContext context) {
    final isBanned = standing.kind == AccountStandingKind.banned;
    final isSuspended = standing.kind == AccountStandingKind.suspended;
    final isDeactivated = standing.kind == AccountStandingKind.deactivated;
    final isPaused = standing.kind == AccountStandingKind.paused;
    final isActive = standing.kind == AccountStandingKind.active;
    final isRestricted = isBanned || isSuspended || isDeactivated;
    final needsPhoto = !standing.hasPublishedPhoto && !isRestricted;
    final color = isRestricted
        ? AppColors.softCoral
        : isActive && !needsPhoto
            ? AppColors.verifiedTeal
            : AppColors.champagneGold;
    final icon = isBanned
        ? Icons.block_rounded
        : isSuspended
            ? Icons.gpp_maybe_outlined
            : isDeactivated
                ? Icons.person_off_outlined
                : isPaused
                    ? Icons.pause_circle_outline_rounded
                    : needsPhoto
                        ? Icons.add_photo_alternate_outlined
                        : incognitoEnabled
                            ? Icons.visibility_off_rounded
                            : Icons.public_rounded;
    final title = isBanned
        ? 'Account banned'
        : isSuspended
            ? 'Profile suspended'
            : isDeactivated
                ? 'Profile deactivated'
                : isPaused
                    ? 'Profile paused'
                    : needsPhoto
                        ? 'Primary photo required'
                        : isActive
                            ? incognitoEnabled
                                ? 'Incognito discovery'
                                : 'Live in discovery'
                            : 'Checking account status';
    final body = isBanned
        ? 'An enforced account restriction is active. Your profile is not shown and protected actions are unavailable. You can contact Support to appeal.'
        : isSuspended
            ? 'Your profile is hidden while the account is under review. This status remains here until the restriction is resolved.'
            : isDeactivated
                ? 'Your profile is not active. Support can guide you through restoring access.'
                : isPaused
                    ? standing.hasPublishedPhoto
                        ? 'You are hidden from discovery. Resume whenever you are ready—your profile information and matches remain intact.'
                        : 'Your profile is hidden and needs a safe primary photo before it can return to discovery.'
                    : needsPhoto
                        ? 'Add a primary photo that passes the safety scan to publish your profile.'
                        : isActive
                            ? incognitoEnabled
                                ? 'You are hidden from general discovery and remain visible only to people you contact or already know.'
                                : 'Your profile is visible and eligible to appear in discovery.'
                            : 'We are confirming your current visibility with Silarah.';
    final actionLabel = isRestricted
        ? 'Contact support'
        : isPaused && standing.hasPublishedPhoto
            ? 'Resume profile'
            : needsPhoto
                ? 'Manage photos'
                : null;
    final action = isRestricted
        ? onContactSupport
        : isPaused && standing.hasPublishedPhoto
            ? onResume
            : needsPhoto
                ? onManagePhotos
                : null;

    // A healthy public profile needs one calm line, not a full status panel.
    final isQuiet = isActive &&
        !needsPhoto &&
        !incognitoEnabled &&
        standing.errorMessage == null;
    if (isQuiet) {
      return Semantics(
        liveRegion: true,
        label: '${context.uiCopy(title)}. ${context.uiCopy(body)}',
        child: AnimatedContainer(
          duration: AppDimensions.durationReveal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space12,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppDimensions.space10),
              Expanded(
                child: UiText(
                  title,
                  style: AppTypography.bodyMedium.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      liveRegion: true,
      label: '${context.uiCopy(title)}. ${context.uiCopy(body)}',
      child: AnimatedContainer(
        duration: AppDimensions.durationReveal,
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UiText(
                  context.uiCopy('ACCOUNT STANDING'),
                  style: AppTypography.sectionLabel,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: UiText(
                    isRestricted
                        ? 'RESTRICTED'
                        : isActive && !needsPhoto
                            ? incognitoEnabled
                                ? 'PRIVATE'
                                : 'ACTIVE'
                            : 'ATTENTION',
                    style: AppTypography.badge.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText(
                        title,
                        style: AppTypography.bodyMedium.copyWith(color: color),
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      UiText(
                        standing.errorMessage ?? body,
                        style: AppTypography.caption.copyWith(height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (actionLabel != null && action != null) ...[
              const SizedBox(height: AppDimensions.space14),
              Align(
                alignment: Alignment.centerRight,
                child: SilarahPressable(
                  semanticLabel: actionLabel,
                  onTap: standing.updating ? null : action,
                  enabled: !standing.updating,
                  child: Container(
                    height: 42,
                    constraints: const BoxConstraints(minWidth: 142),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isRestricted ? Colors.transparent : color,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(color: color),
                    ),
                    child: standing.updating
                        ? SilarahActivityIndicator(
                            size: 18,
                            color:
                                isRestricted ? color : AppColors.obsidianNight,
                          )
                        : UiText(
                            actionLabel,
                            style: AppTypography.captionMedium.copyWith(
                              color: isRestricted
                                  ? color
                                  : AppColors.obsidianNight,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrustCenterCard extends StatelessWidget {
  const _TrustCenterCard({
    required this.loading,
    required this.photoStatus,
    required this.guardianConnected,
    required this.guardianManaged,
    required this.establishedMember,
    required this.email,
    required this.emailVerified,
    required this.onPhotoVerification,
    required this.onGuardianConnection,
  });

  final bool loading;
  final PhotoVerificationStatus photoStatus;
  final bool guardianConnected;
  final bool guardianManaged;
  final bool establishedMember;
  final String? email;
  final bool emailVerified;
  final VoidCallback onPhotoVerification;
  final VoidCallback onGuardianConnection;

  @override
  Widget build(BuildContext context) {
    final photoPresentation = switch (photoStatus.state) {
      PhotoVerificationState.approved when photoStatus.pausedAt == null => (
          status: 'Verified',
          subtitle: 'Temporary captures matched your current profile photo',
          color: AppColors.verifiedTeal,
        ),
      PhotoVerificationState.pending => (
          status: 'In review',
          subtitle: 'Captures delete after review or within 48 hours',
          color: AppColors.champagneGold,
        ),
      PhotoVerificationState.rejected => (
          status: 'Not approved',
          subtitle: photoStatus.reason ?? 'You can submit a new photo check',
          color: AppColors.softCoral,
        ),
      PhotoVerificationState.resubmit => (
          status: 'Action needed',
          subtitle: photoStatus.reason ?? 'New guided captures are needed',
          color: AppColors.softCoral,
        ),
      PhotoVerificationState.expired => (
          status: 'Expired',
          subtitle: 'Temporary captures were deleted; submit again',
          color: AppColors.champagneGold,
        ),
      PhotoVerificationState.approved || PhotoVerificationState.revoked => (
          status: 'Paused',
          subtitle: 'Verify again after changing your primary photo',
          color: AppColors.champagneGold,
        ),
      _ => (
          status: 'Start',
          subtitle: 'Easy look, smile and blink guide with human review',
          color: AppColors.champagneGold,
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: AppColors.champagneGold, size: 20),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText(context.uiCopy('Trust checks'),
                          style: AppTypography.bodyMedium),
                      const SizedBox(height: 2),
                      UiText(
                          context.uiCopy(
                              'Independent checks that strengthen your profile'),
                          style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.cardBorder),
          _TrustRow(
            icon: Icons.face_retouching_natural_outlined,
            title: 'Profile photo check',
            subtitle: photoPresentation.subtitle,
            status: photoPresentation.status,
            statusColor: photoPresentation.color,
            onTap: photoStatus.isApproved || photoStatus.isPending || loading
                ? null
                : onPhotoVerification,
          ),
          Divider(height: 1, indent: 56, color: AppColors.cardBorder),
          _TrustRow(
            icon: Icons.alternate_email_rounded,
            title: 'Account email',
            subtitle: _maskedAccountEmail(email),
            status: emailVerified ? 'Verified' : 'Check email',
            statusColor: emailVerified
                ? AppColors.verifiedTeal
                : AppColors.champagneGold,
          ),
          Divider(height: 1, indent: 56, color: AppColors.cardBorder),
          if (guardianManaged) ...[
            _TrustRow(
              icon: Icons.manage_accounts_outlined,
              title: 'Profile management',
              subtitle: 'Managed by you for a family member',
              status: 'Guardian-managed',
              statusColor: AppColors.champagneGold,
            ),
            Divider(height: 1, indent: 56, color: AppColors.cardBorder),
          ],
          _TrustRow(
            icon: Icons.family_restroom_rounded,
            title: guardianManaged
                ? 'Additional guardian oversight'
                : 'Guardian connection',
            subtitle: guardianConnected
                ? 'Guardian invitation accepted and connected'
                : guardianManaged
                    ? 'Optional separate Guardian for chat oversight'
                    : 'Optional consent-based guardian connection',
            status: guardianConnected ? 'Manage' : 'Set up',
            statusColor: guardianConnected
                ? AppColors.verifiedTeal
                : AppColors.champagneGold,
            onTap: loading ? null : onGuardianConnection,
          ),
          Divider(height: 1, indent: 56, color: AppColors.cardBorder),
          _TrustRow(
            icon: Icons.history_toggle_off_rounded,
            title: 'Established member',
            subtitle: 'Based on account age and good standing',
            status: establishedMember ? 'Established' : 'Building history',
            statusColor: establishedMember
                ? AppColors.verifiedTeal
                : AppColors.slateMist,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Color(0x12000000),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.radiusCard),
                bottomRight: Radius.circular(AppDimensions.radiusCard),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mark_email_read_outlined,
                    color: AppColors.slateMist, size: 16),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: UiText(
                    'Official sign-in emails are sent from noreply@mail.silarah.com. Silarah will never ask for your verification code.',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.slateMist, size: 21),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(title, style: AppTypography.body),
                const SizedBox(height: 2),
                UiText(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
          UiText(status,
              style: AppTypography.captionMedium.copyWith(color: statusColor)),
          if (onTap != null) ...[
            const SizedBox(width: AppDimensions.space4),
            Icon(Icons.chevron_right_rounded, color: statusColor, size: 18),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return SilarahPressable(onTap: onTap, child: content);
  }
}

String _maskedAccountEmail(String? email) {
  if (email == null || !email.contains('@')) return 'Email unavailable';
  final parts = email.split('@');
  final local = parts.first;
  final visible =
      local.length <= 2 ? local.substring(0, 1) : local.substring(0, 2);
  final hiddenCount = (local.length - visible.length).clamp(2, 8);
  final hidden = List.filled(hiddenCount, '•').join();
  return '$visible$hidden@${parts.last}';
}

String _profileActionError(Object error) {
  final raw = error.toString();
  final messageMatch = RegExp(r'message:\s*([^,\)]+)').firstMatch(raw);
  final cleaned = (messageMatch?.group(1) ?? raw)
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
  return cleaned.isEmpty
      ? 'Could not complete this action. Try again.'
      : cleaned;
}

class _BoostSection extends StatefulWidget {
  @override
  State<_BoostSection> createState() => _BoostSectionState();
}

class _BoostSectionState extends State<_BoostSection> {
  DateTime? _boostedAt;
  DateTime? _nextBoostAvailableAt;
  bool _boosting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadBoostState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBoostState() async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (SupabaseService.isInitialized && userId != null) {
      final row = await MyAccountSnapshot.instance.profile(userId);
      final expiresAt = row?['boost_expires_at'] == null
          ? null
          : DateTime.tryParse(row!['boost_expires_at'] as String)?.toLocal();
      final activatedAt = row?['boost_last_activated_at'] == null
          ? null
          : DateTime.tryParse(
              row!['boost_last_activated_at'].toString(),
            )?.toLocal();
      final nextAvailable = activatedAt?.add(const Duration(days: 7));
      if (mounted &&
          nextAvailable != null &&
          nextAvailable.isAfter(DateTime.now())) {
        setState(() => _nextBoostAvailableAt = nextAvailable);
        _startTimer();
      }
      if ((row?['is_boosted'] as bool? ?? false) &&
          expiresAt != null &&
          expiresAt.isAfter(DateTime.now())) {
        if (mounted) {
          setState(
              () => _boostedAt = expiresAt.subtract(const Duration(hours: 2)));
          _startTimer();
        }
        return;
      }

      return;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final boostExpired = _boostedAt != null &&
          (const Duration(hours: 2) - now.difference(_boostedAt!)).isNegative;
      final cooldownExpired =
          _nextBoostAvailableAt != null && !_nextBoostAvailableAt!.isAfter(now);
      if (boostExpired || cooldownExpired) {
        setState(() {
          if (boostExpired) _boostedAt = null;
          if (cooldownExpired) _nextBoostAvailableAt = null;
        });
      } else if (_boostedAt != null || _nextBoostAvailableAt != null) {
        setState(() {});
      }
      if (_boostedAt == null && _nextBoostAvailableAt == null) {
        _timer?.cancel();
      }
    });
  }

  Future<void> _activate() async {
    if (_boosting || _boostedAt != null || _isCoolingDown) return;
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (!mounted) return;
    if (!SupabaseService.isInitialized || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: UiText(context
                .uiCopy('Profile boost requires a backend connection.'))),
      );
      return;
    }

    setState(() => _boosting = true);
    final now = DateTime.now();
    try {
      final response =
          await SupabaseService.client.rpc('activate_profile_boost');
      final rows = response as List<dynamic>;
      if (rows.isEmpty) {
        throw StateError('The boost service returned no activation state.');
      }
      final expiresAt = DateTime.tryParse(
        (rows.first as Map)['boost_expires_at']?.toString() ?? '',
      )?.toLocal();
      if (expiresAt == null || !expiresAt.isAfter(now)) {
        throw StateError('The boost activation response was incomplete.');
      }
      if (!mounted) return;
      setState(() {
        _boosting = false;
        _boostedAt = expiresAt.subtract(const Duration(hours: 2));
        _nextBoostAvailableAt = now.add(const Duration(days: 7));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _boosting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UiText(_profileActionError(error))),
      );
      return;
    }

    if (mounted) {
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(Icons.rocket_launch_rounded,
                color: AppColors.champagneGold, size: 16),
            const SizedBox(width: 8),
            UiText(context.uiCopy('Your profile is boosted for 2 hours!'),
                style: AppTypography.body.copyWith(
                  color: AppColors.readableOn(AppColors.surfaceGlassHover),
                )),
          ]),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: BorderSide(color: AppColors.goldBorder),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _countdown() {
    if (_boostedAt == null) return '';
    final remaining =
        const Duration(hours: 2) - DateTime.now().difference(_boostedAt!);
    if (remaining.isNegative) return '00:00:00';
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  bool get _isCoolingDown =>
      _nextBoostAvailableAt != null &&
      _nextBoostAvailableAt!.isAfter(DateTime.now());

  String _availabilityCountdown() {
    final next = _nextBoostAvailableAt;
    if (next == null) return '';
    final remaining = next.difference(DateTime.now());
    if (remaining.isNegative) return 'Ready now';
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    if (days > 0) return 'Available in ${days}d ${hours}h';
    if (hours > 0) return 'Available in ${hours}h ${minutes}m';
    return 'Available in ${remaining.inMinutes + 1}m';
  }

  @override
  Widget build(BuildContext context) {
    // Boost is Premium-only for everyone (paid, referral or test Premium).
    // Women's free messaging is a separate rule and does not apply here.
    final authState = context.watch<AuthCubit>().state;
    final gender =
        authState is AuthAuthenticated ? (authState.gender ?? 'male') : 'male';

    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, subState) {
        final isActive = _boostedAt != null;
        final isCoolingDown = _isCoolingDown && !isActive;

        // Without Premium: locked card that opens the plans. A boost that is
        // already running keeps showing its countdown until it ends.
        final showAsSubscribed = subState.canBoostProfile(gender) || isActive;

        return AnimatedContainer(
          duration: AppDimensions.durationTransition,
          padding: const EdgeInsets.all(AppDimensions.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            gradient: showAsSubscribed
                ? LinearGradient(
                    colors: [
                      AppColors.champagneGold.withValues(alpha: 0.18),
                      AppColors.champagneGold.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: showAsSubscribed ? null : AppColors.surfaceGlass,
            border: Border.all(
              color: showAsSubscribed
                  ? AppColors.goldBorder
                  : AppColors.cardBorder,
            ),
          ),
          child: showAsSubscribed
              ? _BoostActiveOrAvailable(
                  isActive: isActive,
                  isCoolingDown: isCoolingDown,
                  countdown: _countdown(),
                  availabilityCountdown: _availabilityCountdown(),
                  onActivate: _activate,
                )
              : _BoostLocked(
                  onNavigate: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SubscriptionScreen()),
                  ),
                ),
        );
      },
    );
  }
}

class _BoostActiveOrAvailable extends StatelessWidget {
  const _BoostActiveOrAvailable({
    required this.isActive,
    required this.isCoolingDown,
    required this.countdown,
    required this.availabilityCountdown,
    required this.onActivate,
  });
  final bool isActive;
  final bool isCoolingDown;
  final String countdown;
  final String availabilityCountdown;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.rocket_launch_rounded,
                color: AppColors.champagneGold, size: 22),
            const SizedBox(width: AppDimensions.space8),
            UiText(context.uiCopy('Boost Profile'),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.champagneGold)),
            const Spacer(),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: UiText(context.uiCopy('ACTIVE'),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.champagneGold,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    )),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        UiText(
          isActive
              ? 'Your profile is at the top of searches.'
              : isCoolingDown
                  ? 'One profile boost is available every 7 days.'
                  : 'Appear at the top of searches for 2 hours.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppDimensions.space12),
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightSmall,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive
                  ? AppColors.surfaceGlassHover
                  : AppColors.champagneGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              ),
            ),
            onPressed: isActive || isCoolingDown ? null : onActivate,
            child: UiText(
              isActive
                  ? countdown
                  : isCoolingDown
                      ? availabilityCountdown
                      : 'Activate Boost',
              style: AppTypography.button.copyWith(
                color: isActive ? AppColors.slateMist : AppColors.obsidianNight,
                fontVariations: [const FontVariation('wght', 700)],
                letterSpacing: isActive ? 2 : 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoostLocked extends StatelessWidget {
  const _BoostLocked({required this.onNavigate});
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: onNavigate,
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              color: AppColors.slateMist, size: 22),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(context.uiCopy('Profile Boost'),
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.slateMist)),
                const SizedBox(height: AppDimensions.space4),
                UiText(context.uiCopy('Subscribe to unlock profile boosts.'),
                    style: AppTypography.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.slateMist, size: AppDimensions.iconSizeMedium),
        ],
      ),
    );
  }
}

class _ReferralPremiumProfileBanner extends StatelessWidget {
  const _ReferralPremiumProfileBanner({
    required this.expiresAt,
    required this.onTap,
    this.isTest = false,
  });

  final DateTime? expiresAt;
  final VoidCallback onTap;
  final bool isTest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final remaining = expiresAt?.toLocal().difference(DateTime.now());
    final days = remaining?.inDays ?? 3;
    final hours = remaining?.inHours.remainder(24) ?? 0;
    final minutes = remaining?.inMinutes.remainder(60) ?? 0;
    final remainingText = days > 0
        ? l10n.referral_premiumRemainingDaysHours(days, hours)
        : hours > 0
            ? l10n.referral_premiumRemainingHoursMinutes(hours, minutes)
            : l10n.referral_premiumRemainingMinutes(
                remaining?.inMinutes.clamp(1, 59) ?? 1,
              );

    return SilarahPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.champagneGold.withValues(alpha: 0.16),
              AppColors.verifiedTeal.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.goldBorder, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.champagneGold.withValues(alpha: 0.06),
              blurRadius: 22,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.champagneGold.withValues(alpha: 0.14),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.champagneGold,
                size: 26,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    isTest
                        ? context.uiCopy('Test Premium is active')
                        : l10n.referral_premiumActiveTitle,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.champagneGold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  UiText(
                    remainingText,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.verifiedTeal,
                    ),
                  ),
                  UiText(
                    l10n.referral_premiumFeaturesUnlocked,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.champagneGold,
              size: AppDimensions.iconSizeMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// Subscription Card
/// Paid Premium status (and payment problems) sit near the top of Profile,
/// where a member looks first; the upgrade prompt for non-members stays
/// lower, beside the Premium features it unlocks.
enum _SubscriptionCardPlacement { status, upgrade }

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard.status()
      : placement = _SubscriptionCardPlacement.status;
  const _SubscriptionCard.upgrade()
      : placement = _SubscriptionCardPlacement.upgrade;

  final _SubscriptionCardPlacement placement;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final gender =
        authState is AuthAuthenticated ? (authState.gender ?? 'male') : 'male';

    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, state) {
        final Widget card;
        if (placement == _SubscriptionCardPlacement.upgrade) {
          // Women message free, so they are not shown the upgrade prompt.
          if (state.status != SubscriptionStatus.none || gender == 'female') {
            return const SizedBox.shrink();
          }
          card = _buildUpgrade(context);
        } else {
          // Healthy paid Premium lives inside the profile card; referral and
          // test Premium have their own banner.
          if (state.status != SubscriptionStatus.grace) {
            return const SizedBox.shrink();
          }
          card = _buildGrace(context);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: card,
        );
      },
    );
  }

  Widget _buildGrace(BuildContext context) {
    return _CardShell(
      borderColor: AppColors.premiumGold,
      glowColor: AppColors.premiumGold.withValues(alpha: 0.1),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded,
            color: AppColors.premiumGold, size: 22),
        const SizedBox(width: 10),
        Expanded(
            child: UiText(
                context.uiCopy('Payment issue — subscription in grace period.'),
                style: AppTypography.caption)),
        TextButton(
          onPressed: () => _openGooglePlaySubscriptions(context),
          child: UiText(context.uiCopy('Manage Subscription'),
              style: AppTypography.captionMedium
                  .copyWith(color: AppColors.premiumGold)),
        ),
      ]),
    );
  }

  Widget _buildUpgrade(BuildContext context) {
    return SilarahPressable(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen())),
      child: _CardShell(
        borderColor: AppColors.goldBorder,
        glowColor: AppColors.goldGlow,
        child: Row(children: [
          Icon(Icons.lock_outline_rounded,
              color: AppColors.champagneGold, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiText('Upgrade to Silarah Premium',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.champagneGold)),
              UiText(context.uiCopy('Unlock messaging and profile boosts'),
                  style: AppTypography.caption),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.champagneGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: UiText(context.uiCopy('Plans'),
                style: AppTypography.caption.copyWith(
                    color: AppColors.obsidianNight,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

/// Google Play's subscription page, where members cancel or renew.
Future<void> _openGooglePlaySubscriptions(BuildContext context) async {
  final opened = await BillingPortalService.openGooglePlaySubscriptions();
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: UiText(
        context.uiCopy(
          'Unable to open Google Play subscriptions. Try again.',
        ),
      ),
    ),
  );
}

/// Paid Premium inside the profile card, for men and women alike.
class _PremiumMembership extends StatelessWidget {
  const _PremiumMembership();

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _date(DateTime value) {
    final date = value.toLocal();
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, state) {
        final expiry = state.expiresAt;
        if (state.status != SubscriptionStatus.active ||
            !state.hasPaidPremium ||
            expiry == null) {
          return const SizedBox.shrink();
        }
        final cancelled = state.willRenew == false;
        final String detail;
        if (cancelled) {
          detail = AppLocalizations.of(context)
              .referral_premiumEndsAt(_date(expiry));
        } else if (state.willRenew == true) {
          detail = context.uiRenewsDate(_date(expiry));
        } else {
          // The store has not answered, so promise neither renewal nor end.
          detail = _date(expiry);
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space16),
          child: ProfileMembershipStrip(
            detail: detail,
            actionLabel: context.uiCopy(
              cancelled ? 'Manage or renew' : 'Manage or cancel',
            ),
            onTap: () => _openGooglePlaySubscriptions(context),
          ),
        );
      },
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell(
      {required this.child,
      required this.borderColor,
      required this.glowColor});
  final Widget child;
  final Color borderColor;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        color: AppColors.surfaceGlass,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.primaryPhotoUrl,
    required this.onPhotoLoadFailed,
  });

  static const size = ProfileQualityCard.avatarSize;

  final String? primaryPhotoUrl;
  final ValueChanged<String> onPhotoLoadFailed;

  @override
  Widget build(BuildContext context) {
    Widget child = Icon(
      Icons.person_outline_rounded,
      color: AppColors.slateMist,
      size: 32,
    );

    if (primaryPhotoUrl != null && primaryPhotoUrl!.isNotEmpty) {
      child = SilarahBlurImage(
        imageUrl: primaryPhotoUrl!,
        key: ValueKey(primaryPhotoUrl),
        fit: BoxFit.cover,
        width: size,
        height: size,
        onImageError: () => onPhotoLoadFailed(primaryPhotoUrl!),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceGlassHover,
      ),
      child: ClipOval(child: child),
    );
  }
}

class _ProfilePreviewCard extends StatelessWidget {
  const _ProfilePreviewCard({
    required this.score,
    required this.nextStep,
    required this.data,
    required this.guardianManaged,
    required this.hasVerificationBadge,
    required this.verificationLoading,
    required this.onVerify,
    required this.onManagePhotos,
    required this.onEditProfile,
    required this.onGuardian,
    required this.approvedPhotoCount,
    required this.guardianLinked,
    required this.primaryPhotoUrl,
    required this.onPhotoLoadFailed,
  });
  final int score;
  final ProfileQualityStep? nextStep;
  final OnboardingData data;
  final bool guardianManaged;
  final bool hasVerificationBadge;
  final bool verificationLoading;
  final VoidCallback onVerify;
  final VoidCallback onManagePhotos;
  final VoidCallback onEditProfile;
  final VoidCallback onGuardian;
  final int approvedPhotoCount;
  final bool guardianLinked;
  final String? primaryPhotoUrl;
  final ValueChanged<String> onPhotoLoadFailed;

  @override
  Widget build(BuildContext context) {
    // Derive display name from real OnboardingData fields
    final displayName = [data.firstName, data.lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    // Compute age from dateOfBirth
    final dob = data.dateOfBirth;
    int? age;
    if (dob != null) {
      final now = DateTime.now();
      age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
    }
    return ProfileQualityCard(
      score: score,
      nextStep: nextStep,
      onNextStep: (step) =>
          step.opensPhotos ? onManagePhotos() : onEditProfile(),
      avatar: _ProfileAvatar(
        primaryPhotoUrl: primaryPhotoUrl,
        onPhotoLoadFailed: onPhotoLoadFailed,
      ),
      name: displayName.isEmpty
          ? AppLocalizations.of(context).profile_quality_name_fallback
          : displayName,
      subtitle: _buildSubtitle(context, age),
      nameBadge: guardianManaged
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: UiText(context.uiCopy('Guardian-managed'),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.champagneGold,
                    fontSize: 10,
                  )),
            )
          : null,
      identityStatus: verificationLoading
          ? null
          : _VerificationIdentityStatus(
              isVerified: hasVerificationBadge,
              onVerify: onVerify,
            ),
      membership: const _PremiumMembership(),
      tips: verificationLoading
          ? null
          : ProfileRankTips(
              photoVerified: hasVerificationBadge,
              approvedPhotoCount: approvedPhotoCount,
              bioLength: data.bio?.trim().length ?? 0,
              guardianLinked: guardianLinked,
              onVerify: onVerify,
              onPhotos: onManagePhotos,
              onBio: onEditProfile,
              onGuardian: onGuardian,
            ),
    );
  }

  String _buildSubtitle(BuildContext context, int? age) {
    final parts = <String>[];
    if (age != null) parts.add(context.uiAgeYears(age));
    if (data.cityName?.isNotEmpty == true) parts.add(data.cityName!);
    return parts.isEmpty
        ? AppLocalizations.of(context).profile_quality_subtitle_fallback
        : parts.join(' · ');
  }
}

// Saved Profiles
class _VerificationIdentityStatus extends StatelessWidget {
  const _VerificationIdentityStatus({
    required this.isVerified,
    required this.onVerify,
  });

  final bool isVerified;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    if (isVerified) {
      return Semantics(
        label: 'Profile photo verified',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded,
                color: AppColors.verifiedTeal, size: 16),
            const SizedBox(width: AppDimensions.space4),
            UiText(
              context.uiCopy('Photo verified'),
              style: AppTypography.captionMedium.copyWith(
                color: AppColors.verifiedTeal,
              ),
            ),
          ],
        ),
      );
    }

    return SilarahPressable(
      onTap: onVerify,
      child: Semantics(
        button: true,
        label: 'Verify profile photo with guided smile and blink captures',
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.space10,
            AppDimensions.space4,
            AppDimensions.space8,
            AppDimensions.space4,
          ),
          decoration: BoxDecoration(
            color: AppColors.champagneGold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.champagneGold.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined,
                  color: AppColors.champagneGold, size: 14),
              const SizedBox(width: AppDimensions.space6),
              UiText(
                context.uiCopy('Verify photo'),
                style: AppTypography.captionMedium.copyWith(
                  color: AppColors.champagneGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppDimensions.space4),
              Icon(Icons.arrow_forward_rounded,
                  color: AppColors.champagneGold, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedProfilesSection extends StatelessWidget {
  const _SavedProfilesSection({
    required this.savedProfiles,
    required this.onChanged,
    required this.onManage,
  });
  final List<DiscoveryProfile> savedProfiles;
  final VoidCallback onChanged;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: UiText(context.uiCopy('SAVED PROFILES'),
                  style: AppTypography.sectionLabel),
            ),
            TextButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.lock_outline_rounded, size: 15),
              label: UiText(context.uiCopy('Organize')),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space12),
        if (savedProfiles.isEmpty)
          const SilarahEmptyState(
            visual: SilarahEmptyVisual.savedProfiles,
            title: 'No saved profiles yet',
            subtitle: 'Tap the bookmark icon on any\nprofile to save it here.',
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: savedProfiles.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppDimensions.space12),
              itemBuilder: (context, i) {
                final p = savedProfiles[i];
                return SilarahPressable(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileDetailScreen(
                          profile: p,
                          heroTag: 'saved-profile-${p.id}',
                        ),
                      ),
                    );
                    onChanged();
                  },
                  child: Container(
                    width: 90,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar circle — 52 px
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceGlassHover,
                            border: Border.all(
                                color: AppColors.goldBorder, width: 1.5),
                          ),
                          child: ClipOval(
                            child: p.photoUrl == null
                                ? Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.slateMist,
                                    size: 24,
                                  )
                                : SilarahBlurImage(
                                    imageUrl: p.photoUrl!,
                                    blurhash: p.blurhash,
                                    width: 52,
                                    height: 52,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Name
                        UiText(
                          p.firstName,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.pearlWhite,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        // City
                        UiText(
                          p.cityName,
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _HelpAndGrievanceCard extends StatelessWidget {
  const _HelpAndGrievanceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      semanticLabel: '${context.uiCopy('Help & Support')}. '
          '${context.uiCopy('Help Center, contact and grievances')}',
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Icon(
                Icons.support_agent_outlined,
                color: AppColors.champagneGold,
                size: AppDimensions.iconSizeMedium,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    context.uiCopy('Help & Support'),
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  UiText(
                    context.uiCopy('Help Center, contact and grievances'),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.slateMist,
              size: AppDimensions.iconSizeMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// Found a match
class _IFoundMyMatchButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: () => _showConfirmation(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          gradient: LinearGradient(
            colors: [
              AppColors.champagneGold.withValues(alpha: 0.12),
              AppColors.champagneGold.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.space8),
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: AppColors.champagneGold,
                size: AppDimensions.iconSizeMedium,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    context.uiCopy('I Found My Match'),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.champagneGold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  UiText(
                    context.uiCopy('Pause your profile and sign out.'),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.champagneGold,
                size: AppDimensions.iconSizeMedium),
          ],
        ),
      ),
    );
  }

  void _showConfirmation(BuildContext context) {
    showSilarahBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(AppDimensions.space16),
        padding: const EdgeInsets.all(AppDimensions.space24),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
                child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: AppDimensions.space24),
            Icon(Icons.favorite_rounded,
                color: AppColors.champagneGold, size: 48),
            const SizedBox(height: AppDimensions.space16),
            UiText(
              context.uiCopy('Alhamdulillah!'),
              style: AppTypography.screenTitle.copyWith(
                color: AppColors.champagneGold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            UiText(
              context.uiCopy(
                  'May Allah bless your union with\nlove, mercy, and barakah.'),
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space6),
            UiText(
              context.uiCopy(
                  'Your profile will be hidden from searches.\nYou can reactivate anytime.'),
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space24),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  try {
                    await SupabaseService.client.rpc(
                      'set_profile_pause',
                      params: {'p_paused': true},
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    await context.read<AuthCubit>().signOut();
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(content: UiText(_profileActionError(error))),
                      );
                  }
                },
                child: UiText(context.uiCopy('Confirm & Pause Profile'),
                    style: AppTypography.button),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeightSmall,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: UiText(context.uiCopy('Cancel'),
                    style: AppTypography.button
                        .copyWith(color: AppColors.slateMist)),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
          ],
        ),
      ),
    );
  }
}

class _ProfileRefreshNotice extends StatelessWidget {
  const _ProfileRefreshNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded,
              color: AppColors.slateMist, size: AppDimensions.iconSizeSmall),
          const SizedBox(width: 10),
          Expanded(
            child: UiText(
              context.uiCopy('We could not refresh your profile.'),
              style: AppTypography.caption,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: UiText(
              context.uiCopy('Retry'),
              style: AppTypography.captionMedium
                  .copyWith(color: AppColors.champagneGold),
            ),
          ),
        ],
      ),
    );
  }
}
