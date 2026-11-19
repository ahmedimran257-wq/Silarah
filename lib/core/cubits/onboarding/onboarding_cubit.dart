// SILARAH — Onboarding Cubit
// Manages the five-step fast-start onboarding flow.
// Each step: locally validates → emits OnboardingLoading →
//            saves → emits OnboardingSaved.
// The router listens and pushes the next screen.
//
// Completion thresholds:
//   Myself   → completeAt 5
//   Guardian → completeAt 5
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/onboarding_data.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../services/profile_write_service.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required AuthCubit authCubit})
      : _authCubit = authCubit,
        super(const OnboardingInitial());

  final AuthCubit _authCubit;

  static const String _kCacheKey = 'onboarding_data_cache';
  bool _saveInFlight = false;
  bool _refreshInFlight = false;
  Future<void>? _initializationInFlight;
  DateTime? _lastProfileLoadAt;

  /// True once this account's profile has been read from (or written to)
  /// the server. Edit Profile's full save is refused until then, so a
  /// failed read can never send blank fields over the real profile.
  bool _profileLoaded = false;
  bool get profileLoaded => _profileLoaded;
  static const _profileFreshness = Duration(minutes: 5);

  // Initialization
  /// Called after auth succeeds. Loads the saved step from backend.
  /// Also restores saved data from Supabase/SharedPreferences to preserve state.
  Future<void> initialize({int startStep = 0}) async {
    final activeInitialization = _initializationInFlight;
    if (activeInitialization != null) {
      await activeInitialization;
      if (!isClosed) syncRouteStep(startStep);
      return;
    }
    final operation = _initializeOnce(startStep: startStep);
    _initializationInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_initializationInFlight, operation)) {
        _initializationInFlight = null;
      }
    }
  }

  Future<void> _initializeOnce({required int startStep}) async {
    OnboardingData data = const OnboardingData();

    // 1. Attempt to load from Supabase if real mode is enabled
    final OnboardingData? dbData;
    try {
      dbData = await ProfileWriteService.loadProfile();
    } on ProfileLoadException catch (error) {
      // Offline or a server error: keep whatever this session already has,
      // never move the member back a step and never clear their device
      // copy. Screens retry the read (My Profile shows its notice).
      debugPrint('OnboardingCubit: profile load failed: $error');
      if (!isClosed) {
        emit(OnboardingActive(step: _currentStep, data: currentData));
      }
      return;
    }
    if (dbData != null) {
      data = dbData;
      _lastProfileLoadAt = DateTime.now();
      _profileLoaded = true;
    } else {
      // Every resumable step is server-backed. Intimate profile, location,
      // guardian and photo data is never restored from SharedPreferences.
      await clearSensitiveDeviceState(userId: _authenticatedUserId);
    }

    final authState = _authCubit.state;
    if (data.email == null && authState is AuthAuthenticated) {
      final email = authState.email;
      if (email != null && email.isNotEmpty) {
        data = data.copyWith(email: email);
      }
    }

    // Prefill countryCode from SharedPreferences if null
    if (data.countryCode == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final code = prefs.getString('user_country_code');
        if (code != null && code.isNotEmpty) {
          data = data.copyWith(countryCode: code.toUpperCase());
        }
      } catch (_) {}
    }

    final resolvedStep = _clampStepForData(startStep, data);
    if (resolvedStep != startStep && authState is AuthAuthenticated) {
      _authCubit.updateOnboardingStep(
        resolvedStep,
        isGuardianPath:
            data.profileFor == ProfileFor.guardian || authState.isGuardianPath,
        allowRegression: true,
      );
    }

    if (!isClosed) emit(OnboardingActive(step: resolvedStep, data: data));
  }

  // Step Advance
  /// Saves the partial data for the current step and advances to next.
  /// In production: writes to Supabase profiles table via ProfileWriteService.
  /// Requires Supabase persistence.
  Future<bool> saveAndAdvance(OnboardingData updatedData) async {
    // Race fix: block double taps/slow retries from advancing the same step
    // more than once.
    if (_saveInFlight) return false;
    _saveInFlight = true;
    final currentStep = _currentStep;
    try {
      emit(OnboardingLoading(step: currentStep, data: updatedData));

      final validationMessage = _validateMandatoryStep(
        currentStep,
        updatedData,
      );
      if (validationMessage != null) {
        emit(OnboardingError(
          step: currentStep,
          data: updatedData,
          message: validationMessage,
        ));
        return false;
      }

      // Cache locally so transitions keep entered data; Supabase remains the
      // authoritative profile store once the row has enough required fields.
      await _persistLocalCache(updatedData);

      final isGuardianPath = updatedData.profileFor == ProfileFor.guardian;

      // Steps before Basic Identity do not have gender/date-of-birth yet. Their
      // required data is saved on users via RPCs so app restarts and new-device
      // resumes remain server-backed without creating invalid profile rows.
      if (currentStep == OnboardingFlow.profileForWhomStep) {
        final success =
            await ProfileWriteService.saveProfileTypeResume(updatedData);
        if (!success) {
          emit(OnboardingError(
            step: currentStep,
            data: updatedData,
            message: 'Could not save. Please try again.',
          ));
          return false;
        }
      } else if (currentStep == OnboardingFlow.quickLocationStepIndex) {
        final success =
            await ProfileWriteService.saveOnboardingLocation(updatedData);
        if (!success) {
          emit(OnboardingError(
            step: currentStep,
            data: updatedData,
            message: 'Could not save. Please try again.',
          ));
          return false;
        }
      } else if (currentStep >= OnboardingFlow.basicIdentityStep) {
        final success = await ProfileWriteService.saveStep(
          step: currentStep,
          data: updatedData,
          isGuardianPath: isGuardianPath,
        );

        if (!success) {
          emit(OnboardingError(
            step: currentStep,
            data: updatedData,
            message: 'Could not save. Please try again.',
          ));
          return false;
        }
      }

      final nextStep = currentStep + 1;

      // Persist progress for every step. Before Basic Identity there may be no
      // profiles row yet, so ProfileWriteService also mirrors the resume marker
      // onto public.users. That keeps app restarts from sending users backward.
      final progressSaved = await ProfileWriteService.updateOnboardingStep(
        nextStep,
        isGuardianPath: isGuardianPath,
      );
      if (!progressSaved) {
        emit(OnboardingError(
          step: currentStep,
          data: updatedData,
          message: 'Could not save. Please try again.',
        ));
        return false;
      }

      // Completion threshold: fast-start v3 completes after 5 steps.
      final completeAt = OnboardingFlow.completeAt(isGuardianPath);

      if (nextStep >= completeAt) {
        final completed = await ProfileWriteService.markOnboardingComplete();
        if (!completed) {
          emit(OnboardingError(
            step: currentStep,
            data: updatedData,
            message: 'Could not save. Please try again.',
          ));
          return false;
        }
        _authCubit.updateOnboardingStep(
          nextStep,
          isGuardianPath: isGuardianPath,
          onboardingCompleted: true,
        );
        emit(OnboardingComplete(data: updatedData));
      } else {
        _authCubit.updateOnboardingStep(nextStep,
            isGuardianPath: isGuardianPath);
        emit(OnboardingSaved(step: nextStep, data: updatedData));
      }
      return true;
    } finally {
      _saveInFlight = false;
    }
  }

  /// Moves back one step (local-only, but writes to DB to preserve step).
  Future<void> goBack() async {
    if (_saveInFlight) return;
    final current = state;
    int? newStep;
    OnboardingData? data;

    if (current is OnboardingActive && current.step > 0) {
      newStep = current.step - 1;
      data = current.data;
    } else if (current is OnboardingSaved && current.step > 0) {
      newStep = current.step - 1;
      data = current.data;
    } else if (current is OnboardingLoading && current.step > 0) {
      newStep = current.step - 1;
      data = current.data;
    } else if (current is OnboardingError && current.step > 0) {
      newStep = current.step - 1;
      data = current.data;
    }

    if (newStep != null && data != null) {
      final isGuardianPath = data.profileFor == ProfileFor.guardian;
      // Back is a local navigation action and must remain usable during a
      // transient connection loss. Persist the resume marker afterwards; a
      // later forward save is still server-authoritative and monotonic.
      _authCubit.updateOnboardingStep(
        newStep,
        isGuardianPath: isGuardianPath,
        allowRegression: true,
      );
      emit(OnboardingActive(step: newStep, data: data));
      await ProfileWriteService.setOnboardingStepForBack(newStep);
    }
  }

  Future<void> retryFailedSave() async {
    final current = state;
    if (current is! OnboardingError) return;
    await saveAndAdvance(current.data);
  }

  /// Updates the profile data in-place without advancing the step.
  /// Use this from EditProfileScreen so saving doesn't bump the onboarding flow.
  Future<bool> updateProfile(
    OnboardingData data, {
    bool locationChanged = false,
  }) async {
    final previousData = currentData;
    if (!_profileLoaded) {
      // Never write a profile this session has not read: the fields would
      // be blanks and overwrite the member's real answers.
      emit(OnboardingError(
        step: _currentStep,
        data: previousData,
        message:
            'Your profile has not finished loading. Check your connection and try again.',
      ));
      unawaited(refreshProfileFromDb(force: true).catchError((_) {}));
      return false;
    }
    final savedData = await ProfileWriteService.saveFullProfile(
      data,
      locationChanged: locationChanged,
    );
    if (savedData == null) {
      emit(OnboardingError(
        step: _currentStep,
        data: previousData,
        message: 'Could not save. Please try again.',
      ));
      return false;
    }
    await _persistLocalCache(savedData);
    emit(OnboardingActive(step: _currentStep, data: savedData));
    return true;
  }

  Future<void> refreshProfileFromDb({bool force = false}) async {
    if (_refreshInFlight) return;
    final lastLoadAt = _lastProfileLoadAt;
    if (!force &&
        lastLoadAt != null &&
        DateTime.now().difference(lastLoadAt) < _profileFreshness) {
      return;
    }
    _refreshInFlight = true;
    try {
      // A failed read throws (ProfileLoadException) so the caller can say so.
      final dbData = await ProfileWriteService.loadProfile();
      if (dbData == null) return;
      await _persistLocalCache(dbData);
      _lastProfileLoadAt = DateTime.now();
      _profileLoaded = true;
      emit(OnboardingActive(step: _currentStep, data: dbData));
    } finally {
      _refreshInFlight = false;
    }
  }

  /// Called by screens after router pushes the next page to mark active again.
  void markActive(int step, OnboardingData data) {
    emit(OnboardingActive(step: _clampStepForData(step, data), data: data));
  }

  /// Keeps GoRouter's `/onboarding/:step` route and this cubit's step in sync.
  /// This prevents stale async state from making Continue/Back operate on a
  /// different step than the one currently visible on screen.
  void syncRouteStep(int step) {
    final current = state;
    if (current is OnboardingLoading) return;

    final data = _currentData;
    final safeStep = _clampStepForData(step, data);
    if (current is OnboardingActive && current.step == safeStep) return;

    emit(OnboardingActive(step: safeStep, data: data));
  }

  /// Keeps long-lived profile editors synchronized after a setting changes.
  /// Without this, Manage Photos could overwrite the database with privacy
  /// data cached when the app first opened.
  Future<void> syncPhotoPrivacy(PhotoPrivacy privacy) async {
    final data = _currentData.copyWith(photoPrivacy: privacy);
    await _persistLocalCache(data);
    if (!isClosed) {
      emit(OnboardingActive(
          step: _clampStepForData(_currentStep, data), data: data));
    }
  }

  // Cache Persistence Helper
  Future<void> _persistLocalCache(OnboardingData data) async {
    // Deliberately memory-only. Supabase is the resume source and callers keep
    // [data] in Cubit state for the current process.
    await clearSensitiveDeviceState(userId: _authenticatedUserId);
  }

  /// Forgets everything about the signed-out account, so the next account on
  /// this phone never sees (or saves) the previous member's profile.
  void reset() {
    _profileLoaded = false;
    _lastProfileLoadAt = null;
    _initializationInFlight = null;
    _saveInFlight = false;
    _refreshInFlight = false;
    if (!isClosed) emit(const OnboardingInitial());
  }

  static Future<void> clearSensitiveDeviceState({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCacheKey);
      if (userId != null && userId.isNotEmpty) {
        await prefs.remove('${_kCacheKey}_$userId');
      }
      // Audit-2 cleanup for values written by older releases.
      for (final key in prefs.getKeys()) {
        if (key.startsWith('${_kCacheKey}_')) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }

  // Helpers
  String? get _authenticatedUserId {
    final authState = _authCubit.state;
    if (authState is AuthAuthenticated) {
      return authState.userId;
    }
    return null;
  }

  int _clampStepForData(int step, OnboardingData data) {
    final authState = _authCubit.state;
    final isGuardianPath = data.profileFor == ProfileFor.guardian ||
        (authState is AuthAuthenticated && authState.isGuardianPath);
    final completeAt = OnboardingFlow.completeAt(isGuardianPath);
    var safeStep = step.clamp(0, completeAt - 1).toInt();

    if (safeStep > 0 && data.profileFor == null) {
      safeStep = 0;
    } else if (safeStep > OnboardingFlow.quickLocationStep(isGuardianPath) &&
        !OnboardingFlow.hasValidLocation(data)) {
      safeStep = OnboardingFlow.quickLocationStep(isGuardianPath);
    } else if (safeStep > OnboardingFlow.basicIdentityStep &&
        _validateMandatoryStep(OnboardingFlow.basicIdentityStep, data) !=
            null) {
      safeStep = OnboardingFlow.basicIdentityStep;
    } else if (safeStep > OnboardingFlow.islamicIdentityStep &&
        _validateMandatoryStep(OnboardingFlow.islamicIdentityStep, data) !=
            null) {
      safeStep = OnboardingFlow.islamicIdentityStep;
    }

    return safeStep;
  }

  String? _validateMandatoryStep(int step, OnboardingData data) {
    final isGuardian = data.profileFor == ProfileFor.guardian ||
        data.profileOwnerType == ProfileOwnerType.guardian ||
        data.isGuardianMode;

    switch (step) {
      case OnboardingFlow.profileForWhomStep:
        if (data.profileFor == null) {
          return 'Please select who this profile is for.';
        }
        if (isGuardian && !_isWardRelationship(data.wardRelationship)) {
          return 'Please select who you are registering.';
        }
        return null;
      case OnboardingFlow.quickLocationStepIndex:
        return OnboardingFlow.hasValidLocation(data)
            ? null
            : 'Please select a verified city from the list.';
      case OnboardingFlow.basicIdentityStep:
        if (data.firstName?.trim().isNotEmpty != true ||
            data.lastName?.trim().isNotEmpty != true ||
            data.dateOfBirth == null ||
            data.gender == null ||
            data.motherTongue?.trim().isNotEmpty != true ||
            !OnboardingFlow.hasValidLocation(data)) {
          return 'Please complete all required profile details.';
        }
        if (data.age == null || data.age! < 18) {
          return 'You must be at least 18 to continue.';
        }
        if (isGuardian) {
          if (!_isWardRelationship(data.wardRelationship)) {
            return 'Please select who you are registering.';
          }
          if (!_isValidEmail(data.guardianEmail)) {
            return 'Please enter a valid guardian email.';
          }
        }
        return null;
      case OnboardingFlow.islamicIdentityStep:
        if (data.deenLevel == null ||
            data.praysFiveDaily == null ||
            data.dietType?.trim().isNotEmpty != true ||
            data.smokingHabit?.trim().isNotEmpty != true ||
            data.vapingHabit?.trim().isNotEmpty != true ||
            data.hookahHabit?.trim().isNotEmpty != true) {
          return 'Please complete all required Islamic identity details.';
        }
        return null;
      case OnboardingFlow.photoUploadStep:
        if (data.photoLocalPaths == null || data.photoLocalPaths!.isEmpty) {
          return 'Please add a primary profile photo.';
        }
        if (data.photoPrivacy == null) {
          return 'Please choose a photo privacy setting.';
        }
        return null;
      default:
        return null;
    }
  }

  bool _isWardRelationship(String? value) {
    const allowed = {'son', 'daughter', 'brother', 'sister'};
    return allowed.contains(value?.trim().toLowerCase());
  }

  bool _isValidEmail(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  int get _currentStep {
    final s = state;
    if (s is OnboardingActive) return s.step;
    if (s is OnboardingLoading) return s.step;
    if (s is OnboardingSaved) return s.step;
    if (s is OnboardingError) return s.step;
    return 0;
  }

  OnboardingData get _currentData {
    final s = state;
    if (s is OnboardingActive) return s.data;
    if (s is OnboardingLoading) return s.data;
    if (s is OnboardingSaved) return s.data;
    if (s is OnboardingError) return s.data;
    if (s is OnboardingComplete) return s.data;
    return const OnboardingData();
  }

  OnboardingData get currentData => _currentData;
  int get currentStep => _currentStep;
}
