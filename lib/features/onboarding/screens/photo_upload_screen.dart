// SILARAH - Photo Upload Screen (fast-start step 5)
// 4-slot grid. Slot 0 = primary photo (required to proceed).
// Real image picking via image_picker (Camera / Gallery).
// Compression via flutter_image_compress (bounded JPEG for mobile delivery).
// On-device explicit-content moderation; identity checks live separately.
// Photo privacy toggle for women.
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/services/photo_moderation_service.dart';
import '../../../core/services/media_permission_error.dart';
import '../../../core/services/platform_action_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations/silarah_motion.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../core/widgets/overlays/silarah_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// Photos are displayed below tablet resolution throughout the app. A 720 px
// JPEG at this bound keeps private Storage egress low while remaining
// independently decodable by the server-side validation pipeline.
const int profilePhotoUploadMinDimension = 720;
const int profilePhotoUploadJpegQuality = 82;

// Face detection
// Screen
class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({
    super.key,
    this.returnToPreviousOnSave = false,
  });

  final bool returnToPreviousOnSave;

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  // Compressed bytes for each slot (null = empty)
  final List<Uint8List?> _bytes = [null, null, null, null];
  // Temp file paths for each slot
  final List<String?> _paths = [null, null, null, null];
  final List<PhotoModerationResult?> _moderation = [null, null, null, null];
  final List<String?> _remoteUrls = [null, null, null, null];
  final List<String?> _initialRemoteUrls = [null, null, null, null];
  final Set<int> _removedRemoteSlots = <int>{};
  // Preparing a picked photo and saving are mutually exclusive: one finishing
  // must never mark the other as done.
  _PhotoWork _work = _PhotoWork.idle;
  bool get _uploading => _work == _PhotoWork.uploading;
  bool get _isScanning => _work == _PhotoWork.scanning;
  bool _loadingExisting = false;
  String? _existingLoadError;
  PhotoPrivacy _privacy = PhotoPrivacy.publicAll;
  final _privacyChoicesKey = GlobalKey();
  int? _activeSlot;
  String? _operationTitle;
  String? _operationDetail;
  double _operationProgress = 0;
  bool _operationComplete = false;

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _privacy = data.photoPrivacy ?? PhotoPrivacy.publicAll;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(PhotoModerationService.warmUp().catchError((_) {}));
    });
    // Also load during onboarding. This recovers the exact case where secure
    // upload finalization succeeded but the step-advance response was lost.
    _loadingExisting = true;
    unawaited(_loadExistingPhotos());
  }

  @override
  void dispose() {
    _deleteAllTemporaryPhotos();
    super.dispose();
  }

  Future<void> _loadExistingPhotos() async {
    try {
      final results = await Future.wait<Object>([
        ProfilePhotoService.instance.getMyPhotoSlots(),
        ProfilePhotoService.instance.getMyPhotoPrivacy(),
      ]);
      final slots = results[0] as Map<int, String>;
      final privacy = results[1] as PhotoPrivacy;
      if (!mounted) return;
      setState(() {
        _privacy = privacy;
        for (var i = 0; i < 4; i++) {
          final url = slots[i];
          _remoteUrls[i] = url;
          _initialRemoteUrls[i] = url;
        }
        _existingLoadError = null;
        _loadingExisting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _existingLoadError = error is StateError
            ? error.message
            : 'Your photos could not be loaded. Please try again.';
        _loadingExisting = false;
      });
    }
  }

  bool get _hasPrimary => _bytes[0] != null || _remoteUrls[0] != null;
  bool get _primaryReady =>
      _remoteUrls[0] != null ||
      (_bytes[0] != null && _moderation[0]?.canUpload == true);
  Gender? get _gender => context.read<OnboardingCubit>().currentData.gender;

  /// Picks, compresses, validates, and explicit-content scans a photo.
  Future<void> _pickPhoto(int index) async {
    if (_work != _PhotoWork.idle || _loadingExisting) return;
    // Claimed before the picker opens, so Save cannot start meanwhile.
    setState(() => _work = _PhotoWork.scanning);

    final ImageSource? source;

    source = await _showSourceSheet();

    if (source == null) {
      if (mounted) setState(() => _work = _PhotoWork.idle);
      return;
    }
    if (!mounted) return;

    try {
      final XFile? xfile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (xfile == null) {
        return;
      }
      if (!mounted) return;

      _showOperation(
        slot: index,
        title: 'Preparing photo',
        detail: 'Optimising the image securely on your device',
        progress: 0.12,
      );

      // JPEG is the canonical profile-photo transport. The server decodes the
      // bytes again before finalization, so the extension, MIME type and
      // encoded payload must stay aligned end to end.
      final result = await FlutterImageCompress.compressWithFile(
        xfile.path,
        minWidth: profilePhotoUploadMinDimension,
        minHeight: profilePhotoUploadMinDimension,
        quality: profilePhotoUploadJpegQuality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (!mounted) return;

      // Never write source bytes into a file whose extension promises a
      // different encoding. That mismatch can pass local preview but must fail
      // the server's independent decoder.
      if (result == null || result.isEmpty) {
        throw const FormatException(
          'This photo could not be prepared securely. Choose another image.',
        );
      }
      await _setSlot(index, result);
    } catch (e) {
      if (mounted) {
        _clearOperation();
        final l10n = AppLocalizations.of(context);
        if (MediaPermissionError.isPermissionDenied(e)) {
          final permissionL10n = AppLocalizations.of(context);
          await showSilarahDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: UiText(permissionL10n.media_photoAccessOff),
              content: UiText(permissionL10n.media_photoAccessBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: UiText(permissionL10n.common_button_cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await PlatformActionService.instance.openAppSettings();
                  },
                  child: UiText(permissionL10n.common_openSettings),
                ),
              ],
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: UiText(l10n.photo_error_pick_failed(e.toString()),
                style: AppTypography.body.copyWith(
                  color: AppColors.readableOn(AppColors.softCoral),
                )),
            backgroundColor: AppColors.softCoral,
          ),
        );
      }
    } finally {
      if (mounted && _work == _PhotoWork.scanning) {
        setState(() => _work = _PhotoWork.idle);
      }
    }
  }

  Future<void> _setSlot(int index, Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final oldPath = _paths[index];
    final file = File(
      '${tempDir.path}/silarah_photo_slot_${index}_${_uuid.v4()}.jpg',
    );
    await file.writeAsBytes(bytes);
    if (oldPath != null && oldPath != file.path) {
      _deleteTemporaryPhoto(oldPath);
    }

    _showOperation(
      slot: index,
      title: 'Safety check',
      detail: 'Checking for content that is not permitted',
      progress: 0.56,
    );
    final moderation =
        await PhotoModerationService.instance.scanFile(file.path);
    if (!mounted) return;
    if (!moderation.canUpload) {
      await file.delete().catchError((_) => file);
      _clearOperation();
      if (moderation.decision == PhotoModerationDecision.scanFailed) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        _showPhotoSafetyError(
          'Safety check failed. Please try a different photo or try again.',
        );
        return;
      }

      _showPhotoSafetyError(_photoModerationMessage(moderation));
      return;
    }
    if (!moderation.personDetected) {
      _clearOperation();
      if (!await _confirmPhotoWithoutPerson()) {
        await file.delete().catchError((_) => file);
        return;
      }
      if (!mounted) return;
    }
    if (moderation.decision == PhotoModerationDecision.flagged) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: UiText(
              context.uiCopy(
                  'This photo will be reviewed by our team before it appears on your profile.'),
              style: AppTypography.body.copyWith(
                color: AppColors.readableOn(AppColors.surfaceGlassHover),
              ),
            ),
            backgroundColor: AppColors.surfaceGlassHover,
            behavior: SnackBarBehavior.floating,
            // Clears the Continue button.
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              side: BorderSide(color: AppColors.goldBorder),
            ),
          ),
        );
    }

    _paths[index] = file.path;
    _moderation[index] = moderation;

    setState(() {
      _bytes[index] = bytes;
      _remoteUrls[index] = null;
      _removedRemoteSlots.remove(index);
      _operationTitle = 'Ready to upload';
      _operationDetail = context.uiPhotoReadyReview(index + 1);
      _operationProgress = 1;
      _operationComplete = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted && !_uploading && _activeSlot == index) _clearOperation();
  }

  void _showOperation({
    required int slot,
    required String title,
    required String detail,
    required double progress,
    bool complete = false,
  }) {
    if (!mounted) return;
    setState(() {
      _activeSlot = slot;
      _operationTitle = title;
      _operationDetail = detail;
      _operationProgress = progress.clamp(0.0, 1.0);
      _operationComplete = complete;
    });
  }

  void _clearOperation() {
    if (!mounted) return;
    setState(() {
      _activeSlot = null;
      _operationTitle = null;
      _operationDetail = null;
      _operationProgress = 0;
      _operationComplete = false;
    });
  }

  void _handleSyncProgress(PhotoSyncProgress progress) {
    final copy = switch (progress.stage) {
      PhotoSyncStage.safetyScan => (
          'Final safety check',
          context.uiCopyWith('Verifying photo {number} before upload',
              {'number': progress.slot + 1})
        ),
      PhotoSyncStage.preparingUpload => (
          'Securing upload',
          context.uiCopyWith('Creating a protected upload for photo {number}',
              {'number': progress.slot + 1})
        ),
      PhotoSyncStage.transferring => (
          'Uploading photo',
          context.uiCopyWith('Transferring photo {number} securely',
              {'number': progress.slot + 1})
        ),
      PhotoSyncStage.publishing => (
          'Publishing photo',
          context.uiCopyWith('Adding photo {number} to your protected gallery',
              {'number': progress.slot + 1})
        ),
      PhotoSyncStage.complete => (
          progress.fraction >= 1 ? 'Photos saved' : 'Photo saved',
          progress.fraction >= 1
              ? 'Safe photos are live and remain subject to moderation'
              : 'Continuing with the next photo'
        ),
    };
    _showOperation(
      slot: progress.slot,
      title: copy.$1,
      detail: copy.$2,
      progress: progress.fraction,
      complete:
          progress.stage == PhotoSyncStage.complete && progress.fraction >= 1,
    );
  }

  String _photoModerationMessage(PhotoModerationResult moderation) {
    if (moderation.category == 'invalid_image') {
      return 'Choose a valid photo file.';
    }
    if (moderation.category == 'explicit_content') {
      return "This photo can't be used. Silarah doesn't allow nudity or revealing photos.";
    }
    return 'This photo could not be safety checked. Please choose another image.';
  }

  /// Covered photos (niqab, burqa) may show no face or clothing label, so the
  /// member decides; every upload still enters staff review.
  Future<bool> _confirmPhotoWithoutPerson() async {
    final confirmed = await showSilarahDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: UiText(context.uiCopy('Is this a photo of you?')),
        content: UiText(context.uiCopy(
            "We couldn't spot a person in this photo. Profile photos should show you. Photos in hijab, niqab or burqa are welcome.")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: UiText(context.uiCopy('Choose another')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: UiText(context.uiCopy('Use this photo')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<ImageSource?> _showSourceSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final l10n = AppLocalizations.of(context);
    return showSilarahBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.space16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slateMist.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.space20),
            UiText(l10n.photo_add_photo, style: AppTypography.bodyMedium),
            const SizedBox(height: AppDimensions.space16),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined,
                  color: AppColors.champagneGold),
              title: UiText(l10n.photo_sheet_camera, style: AppTypography.body),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: AppColors.champagneGold),
              title:
                  UiText(l10n.photo_sheet_gallery, style: AppTypography.body),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
            ),
            const SizedBox(height: AppDimensions.space16),
          ],
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    // Its file may be the one being prepared or uploaded right now.
    if (_work != _PhotoWork.idle) return;
    final hadLocalPhoto = _paths[index] != null;
    if (hadLocalPhoto) {
      final file = File(_paths[index]!);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    setState(() {
      _bytes[index] = null;
      _paths[index] = null;
      _moderation[index] = null;
      if (hadLocalPhoto && _initialRemoteUrls[index] != null) {
        // Removing an unsaved replacement restores the server photo instead
        // of unexpectedly deleting it.
        _remoteUrls[index] = _initialRemoteUrls[index];
        _removedRemoteSlots.remove(index);
      } else if (_remoteUrls[index] != null) {
        _remoteUrls[index] = null;
        _removedRemoteSlots.add(index);
      }
    });
  }

  Future<void> _advance() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_work != _PhotoWork.idle || _loadingExisting) {
      return;
    }
    if (!_hasPrimary) {
      _showSaveRequirement('Add a main photo before saving.');
      return;
    }
    if (!_primaryReady) {
      _showSaveRequirement('Wait for the main photo safety check to finish.');
      return;
    }
    final localSlots = <int, String>{};
    for (int i = 0; i < 4; i++) {
      if (_paths[i] != null) localSlots[i] = _paths[i]!;
    }
    final paths = localSlots.values.toList(growable: false);
    final persistedPhotoMarkers = _remoteUrls.whereType<String>().toList();
    final data = context.read<OnboardingCubit>().currentData.copyWith(
          // Signed URLs are never persisted as profile data. They are only a
          // non-empty validation marker for an already finalized remote slot.
          photoLocalPaths: paths.isNotEmpty ? paths : persistedPhotoMarkers,
          photoPrivacy: _privacy,
        );
    setState(() => _work = _PhotoWork.uploading);
    try {
      await ProfilePhotoService.instance.syncPhotoSlots(
        localSlots,
        privacy: _privacy,
        onProgress: _handleSyncProgress,
      );
      for (final slot in _removedRemoteSlots.toList()..sort()) {
        await ProfilePhotoService.instance.deleteMyPhotoSlot(slot);
      }
      if (!mounted) return;
      final cubit = context.read<OnboardingCubit>();
      if (widget.returnToPreviousOnSave) {
        // syncPhotoSlots already persisted the gallery and privacy. Running a
        // full profile update here made Save Photos depend on unrelated profile
        // fields and could leave the button apparently doing nothing.
        await cubit.syncPhotoPrivacy(_privacy);
        if (!mounted) return;
        _showOperation(
          slot: _activeSlot ?? 0,
          title: 'Gallery updated',
          detail: 'Safe photos are live and remain subject to moderation',
          progress: 1,
          complete: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: UiText(context.uiCopy('Photos saved.')),
            behavior: SnackBarBehavior.floating,
            // Clears the Continue button.
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final advanced = await cubit.saveAndAdvance(data);
        if (!advanced) {
          final state = cubit.state;
          throw StateError(
            state is OnboardingError
                ? state.message
                : 'Could not save. Please try again.',
          );
        }
      }
      _deleteAllTemporaryPhotos();
    } catch (e) {
      if (!mounted) return;
      _clearOperation();
      final message = e is StateError
          ? e.message
          : 'Could not upload photos. Please try again.';
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: UiText(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.readableOn(AppColors.surfaceGlassHover),
              ),
            ),
            backgroundColor: AppColors.surfaceGlassHover,
            behavior: SnackBarBehavior.floating,
            // Clears the Continue button.
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              side: BorderSide(color: AppColors.cardBorder),
            ),
          ),
        );
    } finally {
      if (mounted) {
        if (_work == _PhotoWork.uploading) {
          setState(() => _work = _PhotoWork.idle);
        }
        if (!_operationComplete) _clearOperation();
      }
    }
  }

  void _deleteTemporaryPhoto(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // The OS temporary-directory sweeper remains the final fallback.
    }
  }

  void _deleteAllTemporaryPhotos() {
    for (var i = 0; i < _paths.length; i++) {
      final path = _paths[i];
      if (path != null) _deleteTemporaryPhoto(path);
      _paths[i] = null;
      _bytes[i] = null;
      _moderation[i] = null;
    }
  }

  void _showSaveRequirement(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: UiText(
            message,
            style: AppTypography.body.copyWith(
              color: AppColors.readableOn(AppColors.surfaceGlassHover),
            ),
          ),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
          // Clears the Continue button.
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: BorderSide(color: AppColors.goldBorder),
          ),
        ),
      );
  }

  void _explainDisabledSave() {
    if (_loadingExisting) {
      _showSaveRequirement('Loading your current photos…');
    } else if (_isScanning) {
      _showSaveRequirement('Wait for the photo safety check to finish.');
    } else if (_existingLoadError != null) {
      _showSaveRequirement(_existingLoadError!);
    } else if (!_hasPrimary) {
      _showSaveRequirement('Add a main photo before saving.');
    } else if (!_primaryReady) {
      _showSaveRequirement('Wait for the main photo safety check to finish.');
    }
  }

  void _showPhotoSafetyError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: UiText(
          message,
          style: AppTypography.body.copyWith(
            color: AppColors.readableOn(AppColors.softCoral),
          ),
        ),
        backgroundColor: AppColors.softCoral,
        behavior: SnackBarBehavior.floating,
        // Clears the Continue button.
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        final obData = context.read<OnboardingCubit>().currentData;
        final isGuardian = obData.isGuardianMode;
        final relation = obData.profileCreatorRelation ?? 'ward';

        String getRelationString() {
          switch (relation) {
            case 'son':
              return l10n.onboarding_profileForWhom_relation_son.toLowerCase();
            case 'daughter':
              return l10n.onboarding_profileForWhom_relation_daughter
                  .toLowerCase();
            case 'brother':
              return l10n.onboarding_profileForWhom_relation_brother
                  .toLowerCase();
            case 'sister':
              return l10n.onboarding_profileForWhom_relation_sister
                  .toLowerCase();
            default:
              return l10n.onboarding_profileForWhom_ward.toLowerCase();
          }
        }

        return OnboardingScaffold(
          ctaLabel: widget.returnToPreviousOnSave
              ? 'Save photos'
              : l10n.legal_button_continue,
          onCta: _advance,
          onBack: widget.returnToPreviousOnSave
              ? () => Navigator.pop(context, false)
              : null,
          showProgressHeader: !widget.returnToPreviousOnSave,
          headerTitle: 'Photo library',
          isCtaEnabled: _hasPrimary &&
              _primaryReady &&
              _work == _PhotoWork.idle &&
              !_loadingExisting &&
              _existingLoadError == null,
          isCtaLoading: isLoading || _uploading || _loadingExisting,
          onCtaDisabledTap: _explainDisabledSave,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space16),
              // Women choose their photo audience at the end of this step;
              // the summary card takes them straight to those choices.
              GestureDetector(
                onTap: _gender != Gender.female
                    ? null
                    : () {
                        final target = _privacyChoicesKey.currentContext;
                        if (target != null) {
                          Scrollable.ensureVisible(
                            target,
                            duration: AppDimensions.durationTransition,
                            curve: Curves.easeOutCubic,
                            alignment: 0.1,
                          );
                        }
                      },
                child: PhotoAudienceSummary(privacy: _privacy),
              ),
              const SizedBox(height: AppDimensions.space32),
              StepHeader(
                title: widget.returnToPreviousOnSave
                    ? 'Curate your gallery'
                    : (isGuardian
                        ? l10n.photo_title_guardian
                        : l10n.photo_title_self),
                subtitle: widget.returnToPreviousOnSave
                    ? 'Choose the photographs that represent you. Changes are safety checked and published securely.'
                    : (isGuardian
                        ? l10n.photo_subtitle_guardian(getRelationString())
                        : l10n.photo_subtitle_self),
              ),
              const SizedBox(height: AppDimensions.space24),

              _GallerySummary(photoCount: _filledPhotoCount),
              AnimatedSwitcher(
                duration: AppDimensions.durationReveal,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SilarahSizeReveal(
                    factor: animation,
                    child: child,
                  ),
                ),
                child: _operationTitle == null
                    ? const SizedBox.shrink(key: ValueKey('no-operation'))
                    : Padding(
                        key: const ValueKey('photo-operation'),
                        padding: const EdgeInsets.only(
                          top: AppDimensions.space16,
                        ),
                        child: _PhotoOperationPanel(
                          title: _operationTitle!,
                          detail: _operationDetail ?? '',
                          progress: _operationProgress,
                          complete: _operationComplete,
                        ),
                      ),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Photo grid (2 × 2)
              if (_existingLoadError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.space12),
                  decoration: BoxDecoration(
                    color: AppColors.softCoral.withValues(alpha: 0.09),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color: AppColors.softCoral.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          color: AppColors.softCoral, size: 20),
                      const SizedBox(width: AppDimensions.space10),
                      Expanded(
                        child: UiText(
                          _existingLoadError!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.pearlWhite,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loadingExisting = true;
                            _existingLoadError = null;
                          });
                          unawaited(_loadExistingPhotos());
                        },
                        child: UiText(context.uiCopy('Retry')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space16),
              ],
              AspectRatio(
                aspectRatio: 16 / 11,
                child: _buildPhotoSlot(0, label: 'Main photo'),
              ),
              const SizedBox(height: AppDimensions.space12),
              Row(
                children: [
                  for (var i = 1; i < 4; i++) ...[
                    if (i > 1) const SizedBox(width: AppDimensions.space10),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 0.78,
                        child: _buildPhotoSlot(
                          i,
                          label: context.uiPhotoNumber(i + 1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppDimensions.space16),
              const _SafetyPolicyNote(),

              // Privacy toggle for women
              if (_gender == Gender.female) ...[
                const SizedBox(height: AppDimensions.space24),
                UiText(l10n.photo_privacy_label,
                    key: _privacyChoicesKey, style: AppTypography.sectionLabel),
                const SizedBox(height: AppDimensions.space12),
                _PrivacyToggle(
                  current: _privacy,
                  onChanged: (p) => setState(() => _privacy = p),
                ),
              ],

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }

  int get _filledPhotoCount => List<int>.generate(4, (index) => index)
      .where((index) => _bytes[index] != null || _remoteUrls[index] != null)
      .length;

  Widget _buildPhotoSlot(int index, {required String label}) {
    return _PhotoSlot(
      index: index,
      isPrimary: index == 0,
      label: label,
      bytes: _bytes[index],
      remoteUrl: _remoteUrls[index],
      moderation: _moderation[index],
      loading: _loadingExisting &&
          _bytes[index] == null &&
          _remoteUrls[index] == null,
      active: _activeSlot == index && (_isScanning || _uploading),
      progress: _activeSlot == index ? _operationProgress : 0,
      operationComplete: _activeSlot == index && _operationComplete,
      onAdd: () => _pickPhoto(index),
      onRemove: () => _removePhoto(index),
    );
  }
}

// Photo slot
class _GallerySummary extends StatelessWidget {
  const _GallerySummary({required this.photoCount});

  final int photoCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.goldGlow,
              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
            ),
            child: Icon(Icons.collections_outlined,
                color: AppColors.champagneGold, size: 20),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(context.uiPhotoCount(photoCount),
                    style: AppTypography.bodyMedium),
                const SizedBox(height: AppDimensions.space2),
                UiText(
                  photoCount < 3
                      ? 'Add variety to give members a fuller picture of you'
                      : 'Your gallery gives members a well-rounded introduction',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.slateMist),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoOperationPanel extends StatelessWidget {
  const _PhotoOperationPanel({
    required this.title,
    required this.detail,
    required this.progress,
    required this.complete,
  });

  final String title;
  final String detail;
  final double progress;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final accent = complete ? AppColors.verifiedTeal : AppColors.champagneGold;
    return Semantics(
      liveRegion: true,
      label: '${context.uiCopy(title)}. ${context.uiCopy(detail)}',
      value: '${(progress * 100).round()} percent',
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: accent.withValues(alpha: 0.42)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedSwitcher(
                  duration: AppDimensions.durationTransition,
                  child: Icon(
                    complete
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_outlined,
                    key: ValueKey(complete),
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppDimensions.space10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: AppDimensions.durationTransition,
                        child: UiText(title,
                            key: ValueKey(title),
                            style: AppTypography.bodyMedium),
                      ),
                      const SizedBox(height: AppDimensions.space2),
                      UiText(detail,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.slateMist)),
                    ],
                  ),
                ),
                UiText('${(progress * 100).round()}%',
                    style: AppTypography.captionMedium.copyWith(color: accent)),
              ],
            ),
            const SizedBox(height: AppDimensions.space12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: AppDimensions.durationTactile,
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => SilarahLinearProgress(
                  value: value,
                  height: 3,
                  trackColor: AppColors.progressBarBase,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyPolicyNote extends StatelessWidget {
  const _SafetyPolicyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: AppColors.slateMist, size: 18),
        const SizedBox(width: AppDimensions.space8),
        Expanded(
          child: UiText(
            context.uiCopy(
                'Photos are checked privately before they become visible. Explicit content is not permitted.'),
            style: AppTypography.caption.copyWith(color: AppColors.slateMist),
          ),
        ),
      ],
    );
  }
}

class _SlotProgressOverlay extends StatelessWidget {
  const _SlotProgressOverlay({
    required this.progress,
    required this.complete,
  });

  final double progress;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.overlayBlack55,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: AppDimensions.durationTransition,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: AppCurves.tactile),
            child: child,
          ),
          child: complete
              ? Icon(Icons.check_circle_rounded,
                  key: const ValueKey('complete'),
                  color: AppColors.verifiedTeal,
                  size: 42)
              : SizedBox(
                  key: const ValueKey('progress'),
                  width: 42,
                  height: 42,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: AppDimensions.durationTactile,
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => SilarahProgressRing(
                      value: value,
                      size: 42,
                      strokeWidth: 2.5,
                      trackColor: AppColors.progressBarBase,
                      color: AppColors.champagneGold,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.index,
    required this.isPrimary,
    required this.label,
    required this.bytes,
    required this.remoteUrl,
    required this.moderation,
    required this.loading,
    required this.active,
    required this.progress,
    required this.operationComplete,
    required this.onAdd,
    required this.onRemove,
  });

  final int index;
  final bool isPrimary;
  final String label;
  final Uint8List? bytes;
  final String? remoteUrl;
  final PhotoModerationResult? moderation;
  final bool loading;
  final bool active;
  final double progress;
  final bool operationComplete;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isRemote = bytes == null && remoteUrl != null;
    final isFilled = bytes != null || isRemote;
    return SilarahPressable(
      enabled: !isFilled && !active,
      semanticLabel:
          isFilled ? context.uiSelectedLabel(label) : context.uiAddLabel(label),
      onTap: isFilled
          ? null
          : () {
              FocusManager.instance.primaryFocus?.unfocus();
              onAdd();
            },
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        decoration: BoxDecoration(
          color: isFilled ? AppColors.surfaceElevated : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(isPrimary
              ? AppDimensions.radiusCard
              : AppDimensions.radiusButton),
          border: Border.all(
            color: active
                ? AppColors.champagneGold
                : isFilled
                    ? AppColors.champagneGold.withValues(alpha: 0.4)
                    : isPrimary
                        ? AppColors.champagneGold.withValues(alpha: 0.3)
                        : AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isFilled)
              ClipRRect(
                borderRadius: BorderRadius.circular(isPrimary
                    ? AppDimensions.radiusCard - 2
                    : AppDimensions.radiusButton - 2),
                child: bytes != null
                    ? AnimatedSwitcher(
                        duration: AppDimensions.durationReveal,
                        child: Image.memory(
                          bytes!,
                          key: ValueKey(bytes.hashCode),
                          fit: BoxFit.cover,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: remoteUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 480,
                        maxWidthDiskCache: 640,
                        placeholder: (_, __) => const Center(
                          child: SilarahPulseLoader(size: 34),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceGlass,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.slateMist,
                            size: 32,
                          ),
                        ),
                      ),
              )
            else if (loading)
              const Center(child: SilarahPulseLoader(size: 34))
            else
              _EmptySlot(isPrimary: isPrimary, label: label),

            if (isFilled)
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.overlayBlack55],
                      stops: [0.55, 1],
                    ),
                  ),
                ),
              ),

            Positioned(
              left: AppDimensions.space10,
              bottom: AppDimensions.space10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space8,
                  vertical: AppDimensions.space4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.overlayBlack55,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: UiText(
                  label,
                  style: AppTypography.caption.copyWith(
                    // The accent is green on Ivory Emerald and unreadable on
                    // the dark scrim; media labels stay white in every theme.
                    color: AppColors.onMedia,
                    fontWeight: FontWeight.w600,
                    fontSize: isPrimary ? 12 : 10,
                  ),
                ),
              ),
            ),

            // Content-safety status is independent from the optional,
            // human-reviewed photo badge.
            if (isFilled && isPrimary && (moderation != null || isRemote))
              Positioned(
                top: AppDimensions.space10,
                left: AppDimensions.space10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space8,
                    vertical: AppDimensions.space4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        moderation?.decision == PhotoModerationDecision.flagged
                            ? AppColors.champagneGold.withValues(alpha: 0.92)
                            : AppColors.verifiedTeal.withValues(alpha: 0.9),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusChip),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        moderation?.decision == PhotoModerationDecision.flagged
                            ? Icons.policy_outlined
                            : Icons.shield_outlined,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      UiText(
                        moderation?.decision == PhotoModerationDecision.flagged
                            ? 'Review required'
                            : 'Content checked',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Remove button
            if (isFilled && !active)
              Positioned(
                top: 8,
                right: 8,
                child: SilarahPressable(
                  semanticLabel: context.uiRemoveLabel(label),
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    onRemove();
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.overlayBlack55,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.onMedia, size: 17),
                  ),
                ),
              ),

            if (active || operationComplete)
              Positioned.fill(
                child: _SlotProgressOverlay(
                  progress: progress,
                  complete: operationComplete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.isPrimary, required this.label});
  final bool isPrimary;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isPrimary
              ? Icons.add_photo_alternate_outlined
              : Icons.add_a_photo_outlined,
          color: isPrimary ? AppColors.champagneGold : AppColors.slateMist,
          size: AppDimensions.iconSizeXLarge,
        ),
        const SizedBox(height: AppDimensions.space8),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
          child: UiText(
            isPrimary ? 'Add your main photo' : 'Add',
            style: AppTypography.caption.copyWith(
              color: isPrimary ? AppColors.champagneGold : AppColors.slateMist,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// Privacy toggle
/// Shows the actual audience immediately before the member continues or saves.
/// The summary uses the selected policy, never an optimistic privacy promise.
class PhotoAudienceSummary extends StatelessWidget {
  const PhotoAudienceSummary({super.key, required this.privacy});

  final PhotoPrivacy privacy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final description = switch (privacy) {
      PhotoPrivacy.publicAll => l10n.photo_privacy_everyone_sub,
      PhotoPrivacy.mutualOnly => l10n.photo_privacy_mutual_sub,
      PhotoPrivacy.requestOnly => l10n.photo_privacy_request_sub,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              privacy == PhotoPrivacy.publicAll
                  ? Icons.visibility_outlined
                  : Icons.lock_outline_rounded,
              color: AppColors.champagneGold,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText('Who can see your photos',
                      style: AppTypography.bodyMedium),
                  const SizedBox(height: 4),
                  UiText(description,
                      style: AppTypography.caption.copyWith(height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.current, required this.onChanged});
  final PhotoPrivacy current;
  final ValueChanged<PhotoPrivacy> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _PrivacyTile(
          icon: Icons.public_outlined,
          label: l10n.photo_privacy_everyone,
          subtitle: l10n.photo_privacy_everyone_sub,
          isSelected: current == PhotoPrivacy.publicAll,
          onTap: () => onChanged(PhotoPrivacy.publicAll),
        ),
        const SizedBox(height: AppDimensions.space8),
        _PrivacyTile(
          icon: Icons.lock_outline_rounded,
          label: l10n.photo_privacy_mutual,
          subtitle: l10n.photo_privacy_mutual_sub,
          isSelected: current == PhotoPrivacy.mutualOnly,
          onTap: () => onChanged(PhotoPrivacy.mutualOnly),
        ),
        const SizedBox(height: AppDimensions.space8),
        _PrivacyTile(
          icon: Icons.visibility_off_outlined,
          label: l10n.photo_privacy_request,
          subtitle: l10n.photo_privacy_request_sub,
          isSelected: current == PhotoPrivacy.requestOnly,
          onTap: () => onChanged(PhotoPrivacy.requestOnly),
        ),
      ],
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.08)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    isSelected ? AppColors.champagneGold : AppColors.slateMist,
                size: AppDimensions.iconSizeLarge),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(label,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isSelected
                            ? AppColors.champagneGold
                            : AppColors.pearlWhite,
                      )),
                  const SizedBox(height: AppDimensions.space4),
                  UiText(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.champagneGold,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded,
                    color: AppColors.obsidianNight, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

/// What the photo screen is busy with.
enum _PhotoWork { idle, scanning, uploading }
