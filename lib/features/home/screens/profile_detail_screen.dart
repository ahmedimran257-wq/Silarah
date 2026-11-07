//
//   • Full-screen hero photo: 55% of screen height
//   • Stretch + parallax via SliverAppBar stretchModes
//   • Multiple photos swipeable horizontally with dot indicators
//   • Tapping photo → full-screen viewer
//   • Back (top-left) + Share (top-right) + three-dot menu
//   • Three-dot → Report / Block (bottom sheet)
//   • Bio in italic Playfair Display ("their own words")
//   • Interests as outlined GOLD chips
//   • Compatibility indicator: "You match N of their M preferences"
//   • Sticky bottom bar: bookmark + gold "Send Interest"
import 'package:silarah/l10n/ui_copy.dart';
import 'package:silarah/l10n/premium_relationship_ui_copy.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/loaders/silarah_blur_image.dart';
import '../../../core/models/discovery_profile.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/interests/interests_state.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/services/compatibility_service.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/services/shortlist_service.dart';
import '../../../core/services/photo_access_service.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/services/profile_view_service.dart';
import '../../../core/services/platform_action_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../core/widgets/overlays/silarah_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/interest_ceremony_overlay.dart';
import '../widgets/interest_note_sheet.dart';
import '../widgets/report_bottom_sheet.dart';
import 'chat_screen.dart';
import 'paywall_gate_screen.dart';
import 'shortlist_screen.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({
    super.key,
    required this.profile,
    required this.heroTag,
    this.isMutualMatch = false,
    this.isOwnProfile = false,
    this.onEditOwnProfile,
    this.onManageOwnPhotos,
  });

  final DiscoveryProfile profile;
  final String heroTag;
  final bool isMutualMatch;
  final bool isOwnProfile;
  final VoidCallback? onEditOwnProfile;
  final VoidCallback? onManageOwnPhotos;

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  bool _bookmarked = false;
  bool _bookmarkUpdating = false;
  // Covers the quota check, note sheet and send, so a double tap cannot
  // stack two note sheets or send twice.
  bool _sendingInterest = false;
  ShortlistDetail? _shortlistDetail;
  bool _shortlistLoading = false;
  int _photoPage = 0;
  late final PageController _photoController;
  late List<String?> _photoUrls;
  bool _isGalleryLoading = false;
  bool _galleryLoadFailed = false;
  PhotoAccessContext? _photoAccess;
  bool _photoAccessLoading = false;
  bool _photoRequestUpdating = false;
  String? _photoAccessError;
  final Set<int> _refreshingPhotoIndexes = <int>{};
  final Set<int> _refreshedPhotoIndexes = <int>{};
  // The full-screen viewer is a separate route. It listens to this instead of
  // copying the URL list, so slots that finish loading after it opens appear.
  late final ValueNotifier<_GallerySnapshot> _gallery;
  Timer? _rematchCountdownTimer;

  int get _totalPhotos => _photoUrls.length;

  bool get _requiresPhotoAuthorization =>
      !widget.isOwnProfile && widget.profile.effectivePhotoPrivacy != 'public';

  bool get _canViewPhotos =>
      widget.isOwnProfile ||
      !_requiresPhotoAuthorization ||
      (_photoAccess?.canView ?? false);

  bool get _effectiveMutualMatch =>
      widget.isMutualMatch || (_photoAccess?.isMutual ?? false);

  @override
  void initState() {
    super.initState();
    _photoController = PageController();
    _photoUrls = _initialPhotoUrls(widget.profile);
    _gallery = ValueNotifier(_snapshotGallery());
    if (!widget.isOwnProfile) {
      unawaited(ProfileViewService.instance.record(widget.profile.id));
    }
    if (_requiresPhotoAuthorization) {
      _loadPhotoAccessContext();
    } else if (_photoUrls.whereType<String>().length < _photoUrls.length) {
      _loadAuthorizedGallery();
    }
    _scheduleRematchCountdown();
    // Load persisted bookmark state
    BookmarkService.load().then((ids) {
      if (mounted) {
        setState(() => _bookmarked = ids.contains(widget.profile.id));
      }
    }).catchError((_) {});
    unawaited(_loadShortlistDetail());
  }

  Future<void> _loadPhotoAccessContext() async {
    if (_photoAccessLoading) return;
    setState(() {
      _photoAccessLoading = true;
      _photoAccessError = null;
    });
    try {
      final context = await PhotoAccessService.instance.getContext(
        widget.profile.id,
      );
      if (!mounted) return;
      setState(() {
        _photoAccess = context;
        _photoAccessLoading = false;
        final total =
            math.max(context.photoCount, _photoUrls.length).clamp(1, 4);
        if (total != _photoUrls.length) {
          _photoUrls = List<String?>.generate(
            total,
            (index) => index < _photoUrls.length ? _photoUrls[index] : null,
            growable: false,
          );
        }
      });
      _publishGallery();
      if (context.canView) await _loadAuthorizedGallery();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _photoAccessLoading = false;
        _photoAccessError = 'Photo privacy could not be verified.';
      });
    }
  }

  Future<void> _requestPhotoAccess() async {
    if (_photoRequestUpdating) return;
    setState(() => _photoRequestUpdating = true);
    try {
      final context = await PhotoAccessService.instance.requestAccess(
        widget.profile.id,
      );
      if (!mounted) return;
      setState(() {
        _photoAccess = context;
        _photoRequestUpdating = false;
        _photoAccessError = null;
      });
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: UiText(
            this.context.uiPhotoRequestSent(widget.profile.firstName),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _photoRequestUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(error.toString().replaceFirst('Bad state: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancelPhotoRequest() async {
    if (_photoRequestUpdating) return;
    setState(() => _photoRequestUpdating = true);
    try {
      final context = await PhotoAccessService.instance.cancelRequest(
        widget.profile.id,
      );
      if (!mounted) return;
      setState(() {
        _photoAccess = context;
        _photoRequestUpdating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _photoRequestUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(error.toString().replaceFirst('Bad state: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  _GallerySnapshot _snapshotGallery() => _GallerySnapshot(
        urls: List<String?>.unmodifiable(_photoUrls),
        isLoading: _isGalleryLoading,
        loadFailed: _galleryLoadFailed,
      );

  void _publishGallery() => _gallery.value = _snapshotGallery();

  List<String?> _initialPhotoUrls(DiscoveryProfile profile) {
    final urls = profile.orderedPhotoUrls;
    final total = math.max(profile.photoCount, urls.length).clamp(1, 4);
    return List<String?>.generate(
      total,
      (index) => index < urls.length ? urls[index] : null,
      growable: false,
    );
  }

  Future<void> _loadAuthorizedGallery() async {
    if (_isGalleryLoading || !_canViewPhotos) return;
    setState(() {
      _isGalleryLoading = true;
      _galleryLoadFailed = false;
    });
    _publishGallery();
    try {
      final slots = await ProfilePhotoService.instance.getVisiblePhotoSlots(
        ownerUserId: widget.profile.id,
      );
      final entries = slots.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final urls = entries.map((entry) => entry.value).toList(growable: false);
      if (!mounted) return;
      final total =
          math.max(widget.profile.photoCount, urls.length).clamp(1, 4);
      setState(() {
        _photoUrls = List<String?>.generate(
          total,
          (index) => index < urls.length ? urls[index] : null,
          growable: false,
        );
        _isGalleryLoading = false;
      });
      _publishGallery();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isGalleryLoading = false;
        _galleryLoadFailed = true;
      });
      _publishGallery();
    }
  }

  Future<void> _refreshExpiredPhoto(int index) async {
    if (!_canViewPhotos ||
        index < 0 ||
        index >= _photoUrls.length ||
        _refreshingPhotoIndexes.contains(index) ||
        _refreshedPhotoIndexes.contains(index)) {
      return;
    }
    _refreshingPhotoIndexes.add(index);
    _refreshedPhotoIndexes.add(index);
    try {
      final refreshed =
          await ProfilePhotoService.instance.getAuthorizedPhotoUrl(
        ownerUserId: widget.profile.id,
        orderIndex: index,
        forceRefresh: true,
      );
      if (!mounted || refreshed == null || refreshed.isEmpty) return;
      setState(() => _photoUrls[index] = refreshed);
      _publishGallery();
    } finally {
      _refreshingPhotoIndexes.remove(index);
    }
  }

  @override
  void dispose() {
    _rematchCountdownTimer?.cancel();
    _photoController.dispose();
    _gallery.dispose();
    super.dispose();
  }

  void _scheduleRematchCountdown() {
    _rematchCountdownTimer?.cancel();
    final now = DateTime.now();
    final availableAt = widget.profile.rematchAvailableAt;
    if (availableAt == null || !availableAt.isAfter(now)) return;
    final remaining = availableAt.difference(now);
    final days =
        (remaining.inMilliseconds / const Duration(days: 1).inMilliseconds)
            .ceil();
    final nextTick = days <= 1
        ? availableAt
        : availableAt.subtract(Duration(days: days - 1));
    _rematchCountdownTimer = Timer(
      nextTick.difference(now) + const Duration(milliseconds: 150),
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleRematchCountdown();
      },
    );
  }

  // Actions
  Future<void> _handleSendInterest() async {
    if (_sendingInterest) return;
    _sendingInterest = true;
    final bool sent;
    try {
      sent = await _sendInterestWithNote();
    } finally {
      _sendingInterest = false;
    }
    if (!mounted || !sent) return;
    HapticFeedback.mediumImpact();
    await showInterestCeremony(context, firstName: widget.profile.firstName);
  }

  Future<bool> _sendInterestWithNote() async {
    if (!await context.read<InterestsCubit>().canStartInterest() || !mounted) {
      return false;
    }
    // D1: Show note sheet before sending
    final note = await showInterestNoteSheet(
      context,
      firstName: widget.profile.firstName,
    );
    // null = user cancelled
    if (note == null || !mounted) return false;

    // M6: Sync interest to cubit so feed state stays consistent
    return context.read<InterestsCubit>().sendInterest(
          widget.profile,
          note: note.isNotEmpty ? note : null,
        );
  }

  Future<void> _handleBookmark() async {
    if (_bookmarkUpdating) return;
    _bookmarkUpdating = true;
    HapticFeedback.selectionClick();
    final previous = _bookmarked;
    setState(() => _bookmarked = !_bookmarked);

    try {
      final ids =
          await BookmarkService.setSaved(widget.profile.id, _bookmarked);
      if (mounted) {
        setState(() {
          _bookmarked = ids.contains(widget.profile.id);
          if (!_bookmarked) _shortlistDetail = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _bookmarked = previous);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: UiText(context
                .uiCopy('Saved profiles could not be updated. Try again.')),
          ));
      }
    } finally {
      _bookmarkUpdating = false;
    }
  }

  Future<void> _loadShortlistDetail({bool force = false}) async {
    final subscription = context.read<SubscriptionCubit?>()?.state;
    if (subscription?.canOrganizeShortlists != true) return;
    try {
      final details = await ShortlistService.instance.load(force: force);
      if (mounted) {
        setState(() => _shortlistDetail = details[widget.profile.id]);
      }
    } catch (_) {}
  }

  Future<void> _openShortlistEditor() async {
    final subscription = context.read<SubscriptionCubit?>()?.state;
    if (subscription?.canOrganizeShortlists != true) {
      await PaywallGateSheet.show(context);
      return;
    }
    if (_shortlistLoading) return;
    setState(() => _shortlistLoading = true);
    try {
      if (!_bookmarked) {
        final ids = await BookmarkService.setSaved(widget.profile.id, true);
        if (!mounted) return;
        setState(() => _bookmarked = ids.contains(widget.profile.id));
      }
      if (!mounted || !_bookmarked) return;
      final result = await showShortlistEditor(
        context,
        savedUserId: widget.profile.id,
        firstName: widget.profile.firstName,
        initial: _shortlistDetail,
      );
      if (result != null && mounted) {
        setState(() => _shortlistDetail = result);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _shortlistLoading = false);
    }
  }

  Future<void> _openMatchedConversation() async {
    final chatCubit = context.read<ChatCubit>();
    final conversationId = await chatCubit.openOrCreateConversation(
      widget.profile.id,
      widget.profile.firstName,
      widget.profile.lastNameInitial,
    );
    if (!mounted) return;
    if (conversationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: UiText(context
            .uiCopy('Your conversation is still being prepared. Try again.')),
      ));
      return;
    }
    final access = await chatCubit.checkChatAccess(conversationId);
    if (!mounted) return;
    if (access.requiresSubscription) {
      await PaywallGateSheet.show(context);
      return;
    }
    if (!access.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: UiText(
            context.uiCopy('This conversation is not available right now.')),
      ));
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(conversationId: conversationId),
      ),
    );
  }

  Future<void> _handleShare() async {
    HapticFeedback.selectionClick();
    // TD4: Copy a share link to clipboard
    final shareText = 'Check out ${widget.profile.firstName} on Silarah — '
        'silarah.com/profile/${widget.profile.id}';
    await PlatformActionService.instance.shareText(
      text: shareText,
      subject: 'Silarah profile',
    );
  }

  Future<void> _confirmAndBlock() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final profile = widget.profile;
    final confirmed = await showSilarahDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: UiText(l10n.safety_blockTitle(profile.firstName)),
            content: UiText(l10n.safety_blockBody(profile.firstName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: UiText(l10n.common_button_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: UiText(l10n.safety_blockAction),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final blocked = await context.read<BlockReportCubit>().blockUser(
          userId: profile.id,
          name: profile.firstName,
          lastInitial: profile.lastNameInitial,
        );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!blocked) {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: UiText(context
            .uiCopy('We could not block this member. Please try again.')),
      ));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: UiText(
          l10n.safety_blocked(profile.firstName),
          style: AppTypography.body.copyWith(
            color: AppColors.readableOn(AppColors.surfaceGlassHover),
          ),
        ),
        backgroundColor: AppColors.surfaceGlassHover,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    // A blocked profile should not stay on screen, as after a report.
    Navigator.of(context).maybePop();
  }

  void _showMoreMenu() {
    HapticFeedback.selectionClick();
    showSilarahBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // The card floats on its own; the theme's bordered sheet shape would
      // draw a second outline around it.
      shape: const RoundedRectangleBorder(),
      elevation: 0,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BlockReportCubit>(),
        child: _ReportBlockSheet(
          profile: widget.profile,
          onBlock: _confirmAndBlock,
          onReport: () async {
            final reported = await ReportBottomSheet.show(
              context,
              reportedUserId: widget.profile.id,
              reportedName: widget.profile.firstName,
            );
            if (reported && mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // Build
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = widget.profile;
    var interaction = context.select<InterestsCubit, ProfileInteractionState>(
      (cubit) => cubit.state.interactionWith(p.id),
    );
    if (widget.isMutualMatch) {
      interaction = ProfileInteractionState.matched;
    }
    final cooldownDays = interaction == ProfileInteractionState.none
        ? p.rematchCooldownDaysRemaining
        : null;

    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: Stack(
        children: [
          // Scrollable content
          CustomScrollView(
            slivers: [
              // Photo hero with parallax + carousel
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.55,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.obsidianNight,
                title: widget.isOwnProfile ? const _PreviewModeTitle() : null,
                centerTitle: true,
                leading: _HeaderButton(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: l10n.common_button_back,
                  onTap: () => Navigator.pop(context),
                ),
                actions: [
                  _HeaderButton(
                    icon: Icons.ios_share_rounded,
                    semanticLabel: l10n.profile_share,
                    onTap: _handleShare,
                  ),
                  if (!widget.isOwnProfile) ...[
                    const SizedBox(width: AppDimensions.space4),
                    _HeaderButton(
                      icon: Icons.more_vert_rounded,
                      semanticLabel:
                          MaterialLocalizations.of(context).showMenuTooltip,
                      onTap: _showMoreMenu,
                    ),
                  ],
                  const SizedBox(width: AppDimensions.space8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  // The feed card and gallery use different crops, gradients,
                  // and privacy affordances. A Hero swaps those mid-flight and
                  // flashes an uncropped image on pop. Keep the media inside
                  // the opaque page so the route owns the entire movement.
                  background: HeroMode(
                    enabled: false,
                    child: _PhotoCarousel(
                      profile: p,
                      controller: _photoController,
                      photoUrls: _photoUrls,
                      totalPhotos: _totalPhotos,
                      currentPage: _photoPage,
                      onPageChanged: (i) => setState(() => _photoPage = i),
                      canViewPhotos: _canViewPhotos,
                      privacy: _photoAccess?.privacy ??
                          ProfilePhotoPrivacy.fromDatabase(
                            p.effectivePhotoPrivacy,
                          ),
                      requestStatus: _photoAccess?.requestStatus,
                      accessLoading: _photoAccessLoading,
                      requestUpdating: _photoRequestUpdating,
                      accessError: _photoAccessError,
                      onRequestAccess: _requestPhotoAccess,
                      onCancelRequest: _cancelPhotoRequest,
                      onRetryAccess: _loadPhotoAccessContext,
                      isLoading: _isGalleryLoading,
                      loadFailed: _galleryLoadFailed,
                      onRetry: _loadAuthorizedGallery,
                      onPhotoLoadError: _refreshExpiredPhoto,
                      gallery: _gallery,
                    ),
                  ),
                ),
              ),

              // Profile content
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.space24,
                  AppDimensions.space24,
                  AppDimensions.space24,
                  // The sticky bar is ~92dp plus the system navigation area;
                  // a fixed gap let the last section slide under it on
                  // phones with button navigation.
                  116 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Name + age + location
                    _NameBlock(profile: p),
                    const SizedBox(height: AppDimensions.space20),

                    // Compatibility indicator
                    if (widget.isOwnProfile)
                      _OwnProfilePreviewNotice(photoCount: _totalPhotos)
                    else
                      _CompatibilityIndicator(profile: p),
                    if (!widget.isOwnProfile) ...[
                      const SizedBox(height: AppDimensions.space12),
                      _PrivateShortlistCard(
                        detail: _shortlistDetail,
                        loading: _shortlistLoading,
                        onTap: _openShortlistEditor,
                      ),
                    ],
                    const SizedBox(height: AppDimensions.space28),

                    // About — bio in italic Playfair Display
                    if (p.bio != null) ...[
                      const _SectionHeader(label: 'About'),
                      const SizedBox(height: AppDimensions.space12),
                      UiText(p.bio!, style: AppTypography.bio),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Islamic Background
                    if (p.sect != null ||
                        p.deenLevel != null ||
                        p.motherTongue != null ||
                        p.smokingHabit != null ||
                        p.quranMemorization != null ||
                        p.religiousEducation != null) ...[
                      const _SectionHeader(label: 'Islamic Life'),
                      const SizedBox(height: AppDimensions.space12),
                      _DetailGrid(items: [
                        if (p.sect != null)
                          _DetailItem(label: 'Sect', value: p.sect!),
                        if (p.deenLevel != null)
                          _DetailItem(
                              label: 'Deen Level',
                              value: _formatDeen(p.deenLevel!)),
                        if (p.motherTongue != null)
                          _DetailItem(
                              label: 'Mother Tongue', value: p.motherTongue!),
                        if (p.quranMemorization != null)
                          _DetailItem(
                              label: 'Quran',
                              value: _formatQuran(p.quranMemorization!)),
                        if (p.religiousEducation != null)
                          _DetailItem(
                              label: 'Religious Education',
                              value:
                                  _formatReligiousEdu(p.religiousEducation!)),
                        if (p.smokingHabit != null)
                          _DetailItem(label: 'Smoking', value: p.smokingHabit!),
                        if (p.vapingHabit != null)
                          _DetailItem(label: 'Vaping', value: p.vapingHabit!),
                        if (p.hookahHabit != null)
                          _DetailItem(label: 'Hookah', value: p.hookahHabit!),
                      ]),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Background
                    // Education & Career (no marital/family — those go in Family)
                    if (p.occupation != null ||
                        p.education != null ||
                        p.incomeBracket != null) ...[
                      const _SectionHeader(label: 'Education & Career'),
                      const SizedBox(height: AppDimensions.space12),
                      _DetailGrid(items: [
                        if (p.occupation != null)
                          _DetailItem(
                              label: 'Occupation', value: p.occupation!),
                        if (p.education != null)
                          _DetailItem(label: 'Education', value: p.education!),
                        if (p.incomeBracket != null)
                          _DetailItem(
                            label: 'Income Bracket',
                            value: _effectiveMutualMatch
                                ? p.incomeBracket!
                                : '🔒 Locked (Mutual match only)',
                          ),
                      ]),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Family — blueprint section 5 of 6
                    if (p.familyType != null ||
                        p.maritalStatus != null ||
                        p.marriageTimeline != null ||
                        p.willingToRelocate != null ||
                        p.familyOriginCity != null) ...[
                      const _SectionHeader(label: 'Family & Future'),
                      const SizedBox(height: AppDimensions.space12),
                      _DetailGrid(items: [
                        if (p.familyType != null)
                          _DetailItem(
                              label: 'Family Type', value: p.familyType!),
                        if (p.maritalStatus != null)
                          _DetailItem(
                              label: 'Marital Status', value: p.maritalStatus!),
                        if (p.marriageTimeline != null)
                          _DetailItem(
                              label: 'Timeline',
                              value: _formatTimeline(p.marriageTimeline!)),
                        if (p.willingToRelocate != null)
                          _DetailItem(
                              label: 'Relocate',
                              value: _formatRelocate(p.willingToRelocate!)),
                        if (p.livingExpectation != null)
                          _DetailItem(
                              label: 'Living',
                              value: _formatLiving(p.livingExpectation!)),
                        if (p.familyOriginCity != null)
                          _DetailItem(
                            label: 'Origin City',
                            value: _effectiveMutualMatch
                                ? p.familyOriginCity!
                                : '🔒 Locked (Mutual match only)',
                          ),
                      ]),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Interests — gold outlined chips (blueprint: after Family)
                    if (p.interests != null && p.interests!.isNotEmpty) ...[
                      const _SectionHeader(label: 'Interests'),
                      const SizedBox(height: AppDimensions.space12),
                      Wrap(
                        spacing: AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: p.interests!
                            .map((i) => _GoldChip(label: i))
                            .toList(),
                      ),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Languages
                    if (p.languages != null && p.languages!.isNotEmpty) ...[
                      const _SectionHeader(label: 'Languages'),
                      const SizedBox(height: AppDimensions.space12),
                      Wrap(
                        spacing: AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: p.languages!
                            .map((l) => _DetailChip(label: l))
                            .toList(),
                      ),
                      const SizedBox(height: AppDimensions.space28),
                    ],
                  ]),
                ),
              ),
            ],
          ),

          // Sticky bottom bar
          if (!widget.isOwnProfile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CtaBar(
                firstName: p.firstName,
                interaction: interaction,
                rematchCooldownDays: cooldownDays,
                isRematchCandidate: p.isRematchCandidate,
                isBookmarked: _bookmarked,
                onSendInterest: interaction == ProfileInteractionState.none &&
                        cooldownDays == null
                    ? _handleSendInterest
                    : null,
                onOpenInterests: () => context.go('/home?tab=1'),
                onOpenConversation:
                    interaction == ProfileInteractionState.matched
                        ? _openMatchedConversation
                        : null,
                onBookmark: _handleBookmark,
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _OwnProfileActionBar(
                onEdit: widget.onEditOwnProfile,
                onManagePhotos: widget.onManageOwnPhotos,
              ),
            ),
        ],
      ),
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

  String _formatQuran(String raw) {
    switch (raw) {
      case 'none':
        return 'None';
      case 'some_surahs':
        return 'Some Surahs';
      case 'partial':
        return 'Partial';
      case 'hafiz':
        return 'Hafiz';
      default:
        return raw;
    }
  }

  String _formatReligiousEdu(String raw) {
    switch (raw) {
      case 'self_taught':
        return 'Self-taught';
      case 'madrasa':
        return 'Madrasa';
      case 'islamic_uni':
        return 'Islamic University';
      case 'alim_course':
        return 'Alim Course';
      case 'none':
        return 'None';
      default:
        return raw;
    }
  }

  String _formatTimeline(String raw) {
    switch (raw) {
      case 'asap':
        return 'ASAP';
      case '6_months':
        return '6 Months';
      case '1_year':
        return '1 Year';
      case '2_plus_years':
        return '2+ Years';
      case 'not_sure':
        return 'Not Sure';
      default:
        return raw;
    }
  }

  String _formatRelocate(String raw) {
    switch (raw) {
      case 'yes':
        return 'Yes';
      case 'no':
        return 'No';
      case 'open_to_discussion':
        return 'Open';
      default:
        return raw;
    }
  }

  String _formatLiving(String raw) {
    switch (raw) {
      case 'with_inlaws':
        return 'With In-Laws';
      case 'separate':
        return 'Separate';
      case 'open_to_discussion':
        return 'Flexible';
      default:
        return raw;
    }
  }
}

// Photo Carousel
class _PhotoCarousel extends StatelessWidget {
  const _PhotoCarousel({
    required this.profile,
    required this.controller,
    required this.photoUrls,
    required this.totalPhotos,
    required this.currentPage,
    required this.onPageChanged,
    required this.canViewPhotos,
    required this.privacy,
    required this.requestStatus,
    required this.accessLoading,
    required this.requestUpdating,
    required this.accessError,
    required this.onRequestAccess,
    required this.onCancelRequest,
    required this.onRetryAccess,
    required this.isLoading,
    required this.loadFailed,
    required this.onRetry,
    required this.onPhotoLoadError,
    required this.gallery,
  });

  final DiscoveryProfile profile;
  final PageController controller;
  final List<String?> photoUrls;
  final int totalPhotos;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final bool canViewPhotos;
  final ProfilePhotoPrivacy privacy;
  final String? requestStatus;
  final bool accessLoading;
  final bool requestUpdating;
  final String? accessError;
  final VoidCallback onRequestAccess;
  final VoidCallback onCancelRequest;
  final VoidCallback onRetryAccess;
  final bool isLoading;
  final bool loadFailed;
  final VoidCallback onRetry;
  final ValueChanged<int> onPhotoLoadError;
  final ValueListenable<_GallerySnapshot> gallery;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Page-swipeable photo area
        PageView.builder(
          controller: controller,
          physics: const BouncingScrollPhysics(),
          itemCount: totalPhotos,
          onPageChanged: onPageChanged,
          itemBuilder: (_, i) => _SinglePhotoSlide(
            profile: profile,
            index: i,
            photoUrl: i < photoUrls.length ? photoUrls[i] : null,
            gallery: gallery,
            canViewPhotos: canViewPhotos,
            privacy: privacy,
            requestStatus: requestStatus,
            accessLoading: accessLoading,
            requestUpdating: requestUpdating,
            accessError: accessError,
            onRequestAccess: onRequestAccess,
            onCancelRequest: onCancelRequest,
            onRetryAccess: onRetryAccess,
            isLoading: isLoading,
            loadFailed: loadFailed,
            onRetry: onRetry,
            onPhotoLoadError: onPhotoLoadError,
          ),
        ),

        // Bottom gradient fade
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.obsidianNight],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
        ),

        if (totalPhotos > 1) ...[
          Positioned(
            right: AppDimensions.space16,
            top: MediaQuery.of(context).padding.top + 64,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space10,
                  vertical: AppDimensions.space6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.overlayBlack55,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: UiText(
                  '${currentPage + 1} / $totalPhotos',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onMedia,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (currentPage > 0)
            Positioned(
              left: AppDimensions.space12,
              top: 0,
              bottom: 0,
              child: _GalleryNavButton(
                icon: Icons.chevron_left_rounded,
                semanticLabel: context.uiCopy('Previous photo'),
                onTap: () => controller.previousPage(
                  duration: AppDimensions.durationTransition,
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
          if (currentPage < totalPhotos - 1)
            Positioned(
              right: AppDimensions.space12,
              top: 0,
              bottom: 0,
              child: _GalleryNavButton(
                icon: Icons.chevron_right_rounded,
                semanticLabel: context.uiCopy('Next photo'),
                onTap: () => controller.nextPage(
                  duration: AppDimensions.durationTransition,
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
        ],

        // Photo dot indicators — bottom center
        if (totalPhotos > 1)
          Positioned(
            bottom: AppDimensions.space20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < totalPhotos; i++)
                  AnimatedContainer(
                    duration: AppDimensions.durationTransition,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == currentPage ? 16 : 6,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i == currentPage
                          ? AppColors.champagneGold
                          : AppColors.onMedia.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SinglePhotoSlide extends StatelessWidget {
  const _SinglePhotoSlide({
    required this.profile,
    required this.index,
    required this.photoUrl,
    required this.gallery,
    required this.canViewPhotos,
    required this.privacy,
    required this.requestStatus,
    required this.accessLoading,
    required this.requestUpdating,
    required this.accessError,
    required this.onRequestAccess,
    required this.onCancelRequest,
    required this.onRetryAccess,
    required this.isLoading,
    required this.loadFailed,
    required this.onRetry,
    required this.onPhotoLoadError,
  });
  final DiscoveryProfile profile;
  final int index;
  final String? photoUrl;
  final ValueListenable<_GallerySnapshot> gallery;
  final bool canViewPhotos;
  final ProfilePhotoPrivacy privacy;
  final String? requestStatus;
  final bool accessLoading;
  final bool requestUpdating;
  final String? accessError;
  final VoidCallback onRequestAccess;
  final VoidCallback onCancelRequest;
  final VoidCallback onRetryAccess;
  final bool isLoading;
  final bool loadFailed;
  final VoidCallback onRetry;
  final ValueChanged<int> onPhotoLoadError;

  @override
  Widget build(BuildContext context) {
    final isPrivate = profile.isPhotoPrivate && !canViewPhotos;

    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.obsidianDeep, AppColors.obsidianNight],
          ),
        ),
        child: isPrivate
            ? _PrivateSlide(
                photoCount: profile.photoCount,
                privacy: privacy,
                requestStatus: requestStatus,
                accessLoading: accessLoading,
                requestUpdating: requestUpdating,
                accessError: accessError,
                onRequestAccess: onRequestAccess,
                onCancelRequest: onCancelRequest,
                onRetryAccess: onRetryAccess,
              )
            : _PublicSlide(
                photoUrl: photoUrl,
                blurhash: index == 0 ? profile.blurhash : null,
                isLoading: isLoading,
                loadFailed: loadFailed,
                onRetry: onRetry,
                onImageError: () => onPhotoLoadError(index),
              ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    // Full-screen viewer — tapping a photo zooms it
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: AppColors.overlayBlack87,
        barrierDismissible: true,
        pageBuilder: (ctx, animation, _) => FadeTransition(
          opacity: animation,
          child: _FullScreenPhotoViewer(
            profile: profile,
            initialIndex: index,
            gallery: gallery,
            canViewPhotos: canViewPhotos,
            onRetry: onRetry,
            onPhotoLoadError: onPhotoLoadError,
          ),
        ),
      ),
    );
  }
}

class _PublicSlide extends StatelessWidget {
  const _PublicSlide({
    required this.photoUrl,
    required this.isLoading,
    required this.loadFailed,
    required this.onRetry,
    required this.onImageError,
    this.blurhash,
  });
  final String? photoUrl;
  final String? blurhash;
  final bool isLoading;
  final bool loadFailed;
  final VoidCallback onRetry;
  final VoidCallback onImageError;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null) {
      return SilarahBlurImage(
        imageUrl: photoUrl!,
        blurhash: blurhash,
        fit: BoxFit.cover,
        onImageError: onImageError,
      );
    }
    if (isLoading) {
      return Center(
        child: SilarahActivityIndicator(
          size: 30,
          color: AppColors.champagneGold,
        ),
      );
    }
    if (loadFailed) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: UiText(context.uiCopy('Reload photo')),
        ),
      );
    }
    return const _PersonPlaceholder();
  }
}

class _GalleryNavButton extends StatelessWidget {
  const _GalleryNavButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.overlayBlack55,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Icon(icon, color: AppColors.onMedia, size: 28),
          ),
        ),
      ),
    );
  }
}

class _PrivateSlide extends StatelessWidget {
  const _PrivateSlide({
    required this.photoCount,
    required this.privacy,
    required this.requestStatus,
    required this.accessLoading,
    required this.requestUpdating,
    required this.accessError,
    required this.onRequestAccess,
    required this.onCancelRequest,
    required this.onRetryAccess,
  });
  final int photoCount;
  final ProfilePhotoPrivacy privacy;
  final String? requestStatus;
  final bool accessLoading;
  final bool requestUpdating;
  final String? accessError;
  final VoidCallback onRequestAccess;
  final VoidCallback onCancelRequest;
  final VoidCallback onRetryAccess;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppDimensions.durationTransition,
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBorder, width: 2),
              color: AppColors.surfaceGlass,
            ),
            child: accessLoading
                ? Padding(
                    padding: const EdgeInsets.all(30),
                    child: SilarahActivityIndicator(
                      size: 28,
                      color: AppColors.champagneGold,
                    ),
                  )
                : Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.champagneGold,
                    size: 38,
                  ),
          ),
          const SizedBox(height: AppDimensions.space16),
          UiText(
            _title,
            style: AppTypography.userName.copyWith(
              color: AppColors.pearlWhite,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.space6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: UiText(
              accessError ?? _description(context),
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ),
          if (!accessLoading) ...[
            const SizedBox(height: AppDimensions.space16),
            _action,
          ],
        ],
      ),
    );
  }

  String get _title {
    if (accessError != null) return 'Privacy check interrupted';
    if (privacy == ProfilePhotoPrivacy.mutualOnly) {
      return 'Shared after mutual interest';
    }
    return switch (requestStatus) {
      'pending' => 'Request awaiting review',
      'denied' => 'Photos remain private',
      'revoked' => 'Access was withdrawn',
      _ => 'Private photo library',
    };
  }

  String _description(BuildContext context) {
    if (privacy == ProfilePhotoPrivacy.mutualOnly) {
      return context.uiPhotoUnlock(photoCount);
    }
    return switch (requestStatus) {
      'pending' => 'You will be notified as soon as access is approved.',
      'denied' => 'You can send another respectful request when appropriate.',
      'revoked' => 'The owner controls who can view their private photos.',
      _ => context.uiAskPhotoPermission(photoCount),
    };
  }

  Widget get _action {
    if (accessError != null) {
      return _PrivacyActionButton(
        label: 'Check again',
        icon: Icons.refresh_rounded,
        onTap: onRetryAccess,
      );
    }
    if (privacy == ProfilePhotoPrivacy.mutualOnly) {
      return const SizedBox.shrink();
    }
    if (requestStatus == 'pending') {
      return _PrivacyActionButton(
        label: requestUpdating ? 'Cancelling…' : 'Cancel request',
        icon: Icons.close_rounded,
        onTap: requestUpdating ? null : onCancelRequest,
        outlined: true,
      );
    }
    return _PrivacyActionButton(
      label: requestUpdating ? 'Sending…' : 'Request access',
      icon: Icons.lock_open_rounded,
      onTap: requestUpdating ? null : onRequestAccess,
    );
  }
}

class _PrivacyActionButton extends StatelessWidget {
  const _PrivacyActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: onTap,
      enabled: onTap != null,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: outlined ? AppColors.surfaceGlass : AppColors.champagneGold,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color:
                  outlined ? AppColors.champagneGold : AppColors.obsidianNight,
            ),
            const SizedBox(width: 8),
            UiText(
              label,
              style: AppTypography.button.copyWith(
                color: outlined
                    ? AppColors.champagneGold
                    : AppColors.obsidianNight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonPlaceholder extends StatelessWidget {
  const _PersonPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.person_outline_rounded,
          color: AppColors.slateMist, size: 80),
    );
  }
}

// Full-Screen Photo Viewer
@immutable
class _GallerySnapshot {
  const _GallerySnapshot({
    required this.urls,
    required this.isLoading,
    required this.loadFailed,
  });

  final List<String?> urls;
  final bool isLoading;
  final bool loadFailed;
}

/// Media viewer: always dark regardless of theme, like any photo viewer, so
/// its controls use the theme-independent media colours.
class _FullScreenPhotoViewer extends StatefulWidget {
  const _FullScreenPhotoViewer({
    required this.profile,
    required this.initialIndex,
    required this.gallery,
    required this.canViewPhotos,
    required this.onRetry,
    required this.onPhotoLoadError,
  });
  final DiscoveryProfile profile;
  final int initialIndex;
  final ValueListenable<_GallerySnapshot> gallery;
  final bool canViewPhotos;
  final VoidCallback onRetry;
  final ValueChanged<int> onPhotoLoadError;

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPrivate = widget.profile.isPhotoPrivate && !widget.canViewPhotos;

    // A route pushed with PageRouteBuilder has no Material of its own; without
    // one, text falls back to the debug style (yellow double underline). Its
    // scrim over the route barrier makes the backdrop near-black, so the
    // profile page behind does not show through the photo.
    return Material(
      color: AppColors.overlayBlack87,
      child: ValueListenableBuilder<_GallerySnapshot>(
        valueListenable: widget.gallery,
        builder: (context, gallery, _) {
          final totalPhotos = gallery.urls.length;
          return Stack(
            children: [
              PageView.builder(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                itemCount: totalPhotos,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (_, index) => _ViewerPhoto(
                  url: gallery.urls[index],
                  blurhash: index == 0 ? widget.profile.blurhash : null,
                  isPrivate: isPrivate,
                  isLoading: gallery.isLoading,
                  loadFailed: gallery.loadFailed,
                  onRetry: widget.onRetry,
                  onImageError: () => widget.onPhotoLoadError(index),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space12,
                    vertical: AppDimensions.space8,
                  ),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _ViewerCloseButton(
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        if (totalPhotos > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.space12,
                              vertical: AppDimensions.space6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.overlayBlack55,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    AppColors.onMedia.withValues(alpha: 0.24),
                              ),
                            ),
                            child: UiText(
                              '${_page + 1} / $totalPhotos',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.onMedia,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ViewerPhoto extends StatelessWidget {
  const _ViewerPhoto({
    required this.url,
    required this.blurhash,
    required this.isPrivate,
    required this.isLoading,
    required this.loadFailed,
    required this.onRetry,
    required this.onImageError,
  });

  final String? url;
  final String? blurhash;
  final bool isPrivate;
  final bool isLoading;
  final bool loadFailed;
  final VoidCallback onRetry;
  final VoidCallback onImageError;

  @override
  Widget build(BuildContext context) {
    if (isPrivate) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: AppColors.onMedia, size: 56),
            const SizedBox(height: 12),
            UiText(
              context.uiCopy('Locked'),
              style: AppTypography.bodyMuted.copyWith(color: AppColors.onMedia),
            ),
          ],
        ),
      );
    }
    final photoUrl = url;
    if (photoUrl != null) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: SizedBox.expand(
          child: SilarahBlurImage(
            imageUrl: photoUrl,
            blurhash: blurhash,
            fit: BoxFit.contain,
            onImageError: onImageError,
          ),
        ),
      );
    }
    if (isLoading) {
      return const Center(
        child: SilarahActivityIndicator(size: 30, color: AppColors.onMedia),
      );
    }
    if (loadFailed) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: AppColors.onMedia),
          icon: const Icon(Icons.refresh_rounded),
          label: UiText(context.uiCopy('Reload photo')),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.person_outline_rounded,
          color: AppColors.onMedia, size: 80),
    );
  }
}

class _ViewerCloseButton extends StatelessWidget {
  const _ViewerCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).closeButtonTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.overlayBlack55,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.onMedia.withValues(alpha: 0.24),
            ),
          ),
          child: const Icon(Icons.close_rounded,
              color: AppColors.onMedia, size: 22),
        ),
      ),
    );
  }
}

// Header Icon Button
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(AppDimensions.space4),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Icon(icon,
              color: AppColors.pearlWhite, size: AppDimensions.iconSizeMedium),
        ),
      ),
    );
  }
}

// Name Block
class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.profile});
  final DiscoveryProfile profile;

  @override
  Widget build(BuildContext context) {
    // Height display helper
    String? heightStr;
    if (profile.heightCm != null) {
      final cm = profile.heightCm!;
      final totalInches = cm / 2.54;
      final feet = totalInches ~/ 12;
      final inches = totalInches.round() % 12;
      heightStr = '$cm cm ($feet ft $inches in)';
    }

    final displayName = profile.displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: UiText(
                displayName,
                style: AppTypography.screenTitle.copyWith(fontSize: 30),
              ),
            ),
            if (profile.isVerified) _VerifiedPill(),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        UiText(
          [
            '${profile.age}',
            profile.cityName,
            if (heightStr != null) heightStr,
          ].join(' · '),
          style: AppTypography.body.copyWith(color: AppColors.slateMist),
        ),
        if (profile.isGuardianProfile) ...[
          const SizedBox(height: AppDimensions.space10),
          const _GuardianManagedDetailPill(),
        ],
        // History only: hidden while the two members are matched again.
        if (profile.previousMatchAt != null &&
            profile.relationshipState != 'matched' &&
            context.select<InterestsCubit, bool>((cubit) =>
                cubit.state.interactionWith(profile.id) !=
                ProfileInteractionState.matched)) ...[
          const SizedBox(height: AppDimensions.space10),
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: AppColors.champagneGold,
                size: 17,
              ),
              const SizedBox(width: AppDimensions.space8),
              Expanded(
                child: UiText(
                  profile.priorMatchCount > 1
                      ? 'Previously matched ${profile.priorMatchCount} times · most recently ${MaterialLocalizations.of(context).formatMediumDate(profile.previousMatchAt!.toLocal())}'
                      : 'Previously matched on ${MaterialLocalizations.of(context).formatMediumDate(profile.previousMatchAt!.toLocal())}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.champagneLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.verifiedTeal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(color: AppColors.verifiedTeal),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: AppColors.verifiedTeal, size: 12),
          const SizedBox(width: AppDimensions.space4),
          UiText(
            context.uiCopy('Verified'),
            style: AppTypography.caption.copyWith(
              color: AppColors.verifiedTeal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianManagedDetailPill extends StatelessWidget {
  const _GuardianManagedDetailPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space10,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.family_restroom_rounded,
            color: AppColors.champagneGold,
            size: 14,
          ),
          const SizedBox(width: AppDimensions.space6),
          UiText(
            context.uiCopy('Guardian-managed profile'),
            style: AppTypography.caption.copyWith(
              color: AppColors.champagneGold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// Compatibility Indicator
// owner's stated preferences match the viewer's profile —
// 'You match 4 of their 5 preferences.'"
//
// TD7: Now uses the viewer's own OnboardingData for real comparison.

class _OwnProfilePreviewNotice extends StatelessWidget {
  const _OwnProfilePreviewNotice({required this.photoCount});

  final int photoCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.inkTeal.withValues(alpha: 0.38),
            AppColors.surfaceGlass,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.verifiedTeal.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.verifiedTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
            ),
            child: Icon(Icons.visibility_outlined,
                color: AppColors.verifiedTeal, size: 20),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(context.uiCopy('Member preview'),
                    style: AppTypography.bodyMedium),
                const SizedBox(height: AppDimensions.space4),
                UiText(
                  'This is the profile members see in discovery. Swipe through all $photoCount ${photoCount == 1 ? 'photo' : 'photos'} to review the full experience.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.slateMist,
                    height: 1.45,
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

class _PreviewModeTitle extends StatelessWidget {
  const _PreviewModeTitle();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space10,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack55,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: UiText(
        context.uiCopy('YOUR PROFILE'),
        style: AppTypography.sectionLabel.copyWith(
          // Sits on a dark scrim over the photo: always white, since the
          // accent colour differs per identity.
          color: AppColors.onMedia,
          fontSize: 10,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _OwnProfileActionBar extends StatelessWidget {
  const _OwnProfileActionBar({
    required this.onEdit,
    required this.onManagePhotos,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onManagePhotos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space16,
        AppDimensions.space12,
        AppDimensions.space16,
        MediaQuery.of(context).padding.bottom + AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.navBarSurface,
        border: Border(top: BorderSide(color: AppColors.navBarBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _OwnProfileAction(
              label: 'Manage photos',
              icon: Icons.photo_library_outlined,
              onTap: onManagePhotos,
              primary: false,
            ),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: _OwnProfileAction(
              label: 'Edit profile',
              icon: Icons.edit_outlined,
              onTap: onEdit,
              primary: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnProfileAction extends StatelessWidget {
  const _OwnProfileAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      enabled: onTap != null,
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          gradient: primary
              ? LinearGradient(colors: [
                  AppColors.champagneLight,
                  AppColors.champagneGold,
                ])
              : null,
          color: primary ? null : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: primary ? AppColors.champagneGold : AppColors.goldBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color:
                    primary ? AppColors.obsidianNight : AppColors.champagneGold,
                size: 19),
            const SizedBox(width: AppDimensions.space8),
            Flexible(
              child: UiText(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.button.copyWith(
                  color:
                      primary ? AppColors.obsidianNight : AppColors.pearlWhite,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompatibilityIndicator extends StatefulWidget {
  const _CompatibilityIndicator({required this.profile});
  final DiscoveryProfile profile;

  @override
  State<_CompatibilityIndicator> createState() =>
      _CompatibilityIndicatorState();
}

class _CompatibilityIndicatorState extends State<_CompatibilityIndicator> {
  Future<CompatibilityInsight>? _future;

  Future<CompatibilityInsight> _load({bool force = false}) =>
      CompatibilityService.instance.load(widget.profile.id, force: force);

  @override
  Widget build(BuildContext context) {
    final premium = context
            .watch<SubscriptionCubit?>()
            ?.state
            .canViewCompatibilityInsights ??
        false;
    if (!premium) return _locked(context);
    _future ??= _load();
    return FutureBuilder<CompatibilityInsight>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _shell(
            context,
            child: Row(
              children: [
                const SilarahActivityIndicator(
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: UiText(
                    context.uiCopy('Reading mutual preferences…'),
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _shell(
            context,
            child: Row(
              children: [
                Icon(Icons.sync_problem_rounded, color: AppColors.softCoral),
                const SizedBox(width: 12),
                Expanded(
                  child: UiText(
                    context.uiCopy(
                        'Compatibility details are temporarily unavailable.'),
                    style: AppTypography.caption,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _future = _load(force: true)),
                  child: UiText(context.uiCopy('Try again')),
                ),
              ],
            ),
          );
        }
        final insight = snapshot.data!;
        return _shell(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SilarahProgressRing(
                          value: insight.fraction,
                          size: 48,
                          trackColor: AppColors.surfaceGlassHover,
                          color: AppColors.champagneGold,
                          strokeWidth: 3.5,
                        ),
                        Icon(Icons.auto_awesome_rounded,
                            color: AppColors.champagneGold, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UiText(
                          context.uiCopy('Mutual compatibility insights'),
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 3),
                        UiText(
                          insight.totalCount == 0
                              ? context.uiCopy(
                                  'Add more partner preferences to unlock a clearer comparison.')
                              : premiumCompatibilitySummary(
                                  Localizations.localeOf(context).languageCode,
                                  insight.matchedCount,
                                  insight.totalCount,
                                ),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.champagneGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PremiumPill(),
                ],
              ),
              if (insight.criteria.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: insight.criteria
                      .map((criterion) => _CompatibilityCriterionChip(
                            criterion: criterion,
                          ))
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 12),
              UiText(
                context.uiCopy(
                    'Based only on preferences both members chose to share. This is not a safety or marriage-outcome guarantee.'),
                style: AppTypography.caption.copyWith(height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _locked(BuildContext context) => Semantics(
        button: true,
        label: context.uiCopy('Unlock mutual compatibility insights'),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          onTap: () => PaywallGateSheet.show(context),
          child: _shell(
            context,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.hub_outlined, color: AppColors.champagneGold),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText(
                        context.uiCopy('Mutual compatibility insights'),
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: 3),
                      UiText(
                        context.uiCopy(
                            'See where both members’ stated preferences align.'),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                _PremiumPill(),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: AppColors.slateMist),
              ],
            ),
          ),
        ),
      );

  Widget _shell(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: child,
    );
  }
}

class _CompatibilityCriterionChip extends StatelessWidget {
  const _CompatibilityCriterionChip({required this.criterion});
  final CompatibilityCriterion criterion;

  @override
  Widget build(BuildContext context) {
    final aligned = criterion.status == 'aligned';
    final partial = criterion.status == 'partial';
    final color = aligned
        ? AppColors.verifiedTeal
        : partial
            ? AppColors.champagneGold
            : AppColors.slateMist;
    final label = switch (criterion.key) {
      'age' => 'Age',
      'sect' => 'Sect',
      'deen' => 'Deen',
      'education' => 'Education',
      'mother_tongue' => 'Mother tongue',
      'community' => 'Community',
      'height' => 'Height',
      'marriage_timeline' => 'Marriage timeline',
      'relocation' => 'Relocation',
      'living_expectation' => 'Living plans',
      _ => criterion.key,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            aligned
                ? Icons.check_circle_outline_rounded
                : partial
                    ? Icons.circle_outlined
                    : Icons.remove_circle_outline_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          UiText(
            context.uiCopy(label),
            style: AppTypography.captionMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _PremiumPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.champagneGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: UiText(
          context.uiCopy('PREMIUM'),
          style: AppTypography.badge.copyWith(color: AppColors.champagneGold),
        ),
      );
}

class _PrivateShortlistCard extends StatelessWidget {
  const _PrivateShortlistCard({
    required this.detail,
    required this.loading,
    required this.onTap,
  });
  final ShortlistDetail? detail;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final premium =
        context.watch<SubscriptionCubit?>()?.state.canOrganizeShortlists ??
            false;
    final subtitle = !premium
        ? context.uiCopy('Organize profiles with private notes and reminders.')
        : detail == null
            ? context.uiCopy('Add a private category, family note or reminder.')
            : '${context.uiCopy(shortlistCategoryLabel(detail!.category))}${detail!.hasPendingReminder ? ' · ${context.uiCopy('Reminder set')}' : ''}';
    return Semantics(
      button: true,
      label: context.uiCopy('Private shortlist'),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Icon(
                detail == null ? Icons.bookmark_add_outlined : Icons.bookmarks,
                color: AppColors.champagneGold,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(context.uiCopy('Private shortlist'),
                        style: AppTypography.bodyMedium),
                    const SizedBox(height: 2),
                    UiText(subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
              if (!premium) _PremiumPill(),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SilarahActivityIndicator(
                    size: 18,
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: AppColors.slateMist),
            ],
          ),
        ),
      ),
    );
  }
}

// Section Header
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiText(label.toUpperCase(), style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space8),
        Divider(color: AppColors.divider, height: 1),
      ],
    );
  }
}

// Detail Grid
class _DetailItem {
  const _DetailItem({required this.label, required this.value});
  final String label;
  final String value;
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});
  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space12,
      runSpacing: AppDimensions.space12,
      children: items.map((item) => _DetailTile(item: item)).toList(),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.item});
  final _DetailItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiText(item.label, style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space4),
          UiText(_displayValue(item.value), style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

// Gold Chip (Interests — blueprint-specified gold outline)
class _GoldChip extends StatelessWidget {
  const _GoldChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border:
            Border.all(color: AppColors.champagneGold.withValues(alpha: 0.5)),
      ),
      child: UiText(
        label,
        style: AppTypography.chipLabel.copyWith(color: AppColors.champagneGold),
      ),
    );
  }
}

// Plain Chip (Languages etc.)
class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: UiText(label, style: AppTypography.chipLabel),
    );
  }
}

// CTA Bar (sticky bottom)
class _CtaBar extends StatelessWidget {
  const _CtaBar({
    required this.firstName,
    required this.interaction,
    this.rematchCooldownDays,
    required this.isRematchCandidate,
    required this.isBookmarked,
    this.onSendInterest,
    this.onOpenInterests,
    this.onOpenConversation,
    required this.onBookmark,
  });

  final String firstName;
  final ProfileInteractionState interaction;
  final int? rematchCooldownDays;
  final bool isRematchCandidate;
  final bool isBookmarked;
  final Future<void> Function()? onSendInterest;
  final VoidCallback? onOpenInterests;
  final Future<void> Function()? onOpenConversation;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final isCooldown = rematchCooldownDays != null;
    final isActive = interaction != ProfileInteractionState.none || isCooldown;
    final isMatched = interaction == ProfileInteractionState.matched;
    final normalizedName = firstName.trim();
    final (label, icon) = isCooldown
        ? (
            'Rematch available in $rematchCooldownDays day${rematchCooldownDays == 1 ? '' : 's'}',
            Icons.schedule_rounded,
          )
        : switch (interaction) {
            ProfileInteractionState.pendingSent => (
                normalizedName.isEmpty
                    ? 'Interest sent · Awaiting response'
                    : 'Interest sent · Awaiting $normalizedName',
                Icons.schedule_rounded,
              ),
            ProfileInteractionState.pendingReceived => (
                'Review interest',
                Icons.favorite_outline_rounded,
              ),
            ProfileInteractionState.matched => (
                'Open conversation',
                Icons.chat_bubble_outline_rounded,
              ),
            ProfileInteractionState.none => (
                isRematchCandidate
                    ? 'Send interest again'
                    : 'Send interest to $firstName',
                Icons.favorite_outline_rounded,
              ),
          };
    final canTap = !isCooldown &&
        (interaction == ProfileInteractionState.none ||
            interaction == ProfileInteractionState.pendingReceived ||
            isMatched);
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space24,
        AppDimensions.space24,
        AppDimensions.space24,
        AppDimensions.space12 + MediaQuery.of(context).padding.bottom,
      ),
      // A short fade above the buttons, then solid: content scrolling
      // underneath must not show through around them.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.obsidianNight.withValues(alpha: 0),
            AppColors.obsidianNight,
            AppColors.obsidianNight,
          ],
          stops: const [0, 0.28, 1],
        ),
      ),
      child: Row(
        children: [
          // Bookmark button — left
          GestureDetector(
            onTap: onBookmark,
            child: AnimatedContainer(
              duration: AppDimensions.durationTransition,
              width: AppDimensions.buttonHeight,
              height: AppDimensions.buttonHeight,
              decoration: BoxDecoration(
                color:
                    isBookmarked ? AppColors.onMedia : AppColors.overlayBlack87,
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(
                  color: isBookmarked
                      ? AppColors.overlayBlack45
                      : AppColors.onMedia.withValues(alpha: 0.72),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.overlayBlack55,
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                color:
                    isBookmarked ? AppColors.overlayBlack87 : AppColors.onMedia,
                size: AppDimensions.iconSizeLarge,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space12),

          // Send Interest — fills remaining space
          Expanded(
            child: SilarahPressable(
              semanticLabel: label,
              enabled: canTap,
              onTap: isMatched
                  ? () => onOpenConversation?.call()
                  : interaction == ProfileInteractionState.pendingReceived
                      ? () => onOpenInterests?.call()
                      : canTap
                          ? () => onSendInterest?.call()
                          : null,
              child: AnimatedContainer(
                duration: AppDimensions.durationTransition,
                height: AppDimensions.buttonHeight,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.champagneGold.withValues(alpha: 0.15)
                      : AppColors.champagneGold,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: isActive
                      ? Border.all(color: AppColors.champagneGold)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 19,
                      color: isActive
                          ? AppColors.champagneGold
                          : AppColors.obsidianNight,
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    Flexible(
                      child: UiText(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: isActive
                            ? AppTypography.button
                                .copyWith(color: AppColors.champagneGold)
                            : AppTypography.button,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Report / Block Bottom Sheet
// Upgraded to use BlockReportCubit + ReportBottomSheet (Step 10)

class _ReportBlockSheet extends StatelessWidget {
  const _ReportBlockSheet({
    required this.profile,
    required this.onBlock,
    required this.onReport,
  });

  final DiscoveryProfile profile;
  final Future<void> Function() onBlock;
  final Future<void> Function() onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.all(AppDimensions.space16),
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space24),

          _SheetAction(
            icon: Icons.flag_outlined,
            label: l10n.safety_reportMember(profile.firstName),
            color: AppColors.softCoral,
            onTap: () {
              Navigator.pop(context);
              // Small delay so first sheet fully closes before second opens
              unawaited(Future<void>.microtask(onReport));
            },
          ),
          const SizedBox(height: AppDimensions.space4),
          Divider(color: AppColors.divider),
          const SizedBox(height: AppDimensions.space4),
          _SheetAction(
            icon: Icons.block_rounded,
            label: l10n.safety_blockMember(profile.firstName),
            color: AppColors.softCoral,
            onTap: () {
              // This sheet's context is gone once it pops, so the confirm
              // dialog and the block itself run on the profile screen.
              Navigator.pop(context);
              unawaited(Future<void>.microtask(onBlock));
            },
          ),
          const SizedBox(height: AppDimensions.space12),
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
              child: UiText(l10n.common_button_cancel,
                  style: AppTypography.button
                      .copyWith(color: AppColors.slateMist)),
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space14,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: AppDimensions.iconSizeLarge),
            const SizedBox(width: AppDimensions.space12),
            UiText(label,
                style: AppTypography.bodyMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Stored values arrive as enum names ("never", "SUNNI", "once_a_week");
/// detail tiles show them as readable labels without touching data.
String _displayValue(String raw) {
  final spaced = raw.replaceAll('_', ' ').trim();
  if (spaced.isEmpty) return raw;
  final hasLetters = spaced.contains(RegExp(r'[A-Za-z]'));
  if (hasLetters && spaced == spaced.toUpperCase()) {
    return spaced
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
  if (hasLetters && spaced == spaced.toLowerCase()) {
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
  return spaced;
}
