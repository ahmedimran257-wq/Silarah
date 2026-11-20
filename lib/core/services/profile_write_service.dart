// SILARAH — Profile Write Service
// Maps OnboardingData fields → Supabase column names and
// performs partial upserts per onboarding step.
//
// Used by OnboardingCubit.saveAndAdvance() to persist data
// with no local success fallback.
import 'package:flutter/foundation.dart';

import '../models/onboarding_data.dart';
import '../onboarding/onboarding_flow.dart';
import 'my_account_snapshot.dart';
import 'operational_telemetry_service.dart';
import 'supabase_service.dart';

class ProfileWriteService {
  ProfileWriteService._();

  /// Shown when the server refuses profile text that carries contact details
  /// (migration 318 trigger). The app's own filter normally catches these
  /// first; this keeps a refusal from ever looking like a network failure.
  static const contactDetailsRefusalMessage =
      'Contact details (phone numbers, emails, links or social handles) cannot be shared in your profile.';

  static bool _contactDetailsRefused = false;

  /// True once after a save was refused for contact details in profile text.
  static bool takeContactDetailsRefusal() {
    final refused = _contactDetailsRefused;
    _contactDetailsRefused = false;
    return refused;
  }

  static void _noteWriteFailure(Object error) {
    if (error.toString().contains('profile_contact_details_blocked')) {
      _contactDetailsRefused = true;
    }
  }

  /// Whether real writes are possible (Supabase configured).
  static bool get _canWrite => SupabaseService.isInitialized;

  /// Current authenticated user ID, or null.
  static String? get _userId => SupabaseService.currentUserId;

  // Onboarding, Discovery and app resume each restore the profile; one
  // shared preference read serves the startup burst. Writes invalidate it.
  static final _preferences = AccountScopedRead<Object?>(
    freshness: MyAccountSnapshot.freshness,
    load: (_) => SupabaseService.client.rpc('get_my_profile_preferences'),
  );

  // Step-based partial upsert
  /// Persists the fields modified in [step] to Supabase.
  /// Returns true on success, false on error.
  static Future<bool> saveStep({
    required int step,
    required OnboardingData data,
    required bool isGuardianPath,
  }) async {
    if (!_canWrite || _userId == null) {
      return false;
    }

    OnboardingData dataToWrite = data;

    try {
      if (step == OnboardingFlow.basicIdentityStep) {
        final preparedData = await _prepareBasicIdentityWrite(data);
        if (preparedData == null) {
          return false;
        }
        dataToWrite = preparedData;
        final saved = await _saveBasicIdentityStep(
          dataToWrite,
          isGuardianPath: isGuardianPath,
        );
        if (!saved) return false;

        return true;
      }

      if (step > OnboardingFlow.basicIdentityStep) {
        final profileReady = await _ensureProfileRowForPartialStep(
          dataToWrite,
          isGuardianPath: isGuardianPath,
        );
        if (!profileReady) return false;
      }

      final fields = _fieldsForStep(step, dataToWrite, isGuardianPath);
      if (fields.isEmpty) {
        return true;
      }

      final prefFields = _preferenceFieldsForStep(step, dataToWrite);
      await SupabaseService.client.rpc('save_my_profile_bundle', params: {
        'p_profile_fields': fields,
        'p_preference_fields': prefFields,
      });

      return true;
    } catch (error) {
      _noteWriteFailure(error);
      OperationalTelemetryService.record('profile_write', 'save_step_failed');
      return false;
    }
  }

  static Future<bool> saveProfileTypeResume(OnboardingData data) async {
    if (!_canWrite || _userId == null) return false;
    final ownerType = _profileOwnerTypeForDb(data);
    final profileFor = ownerType == 'guardian' ? 'guardian' : 'myself';

    try {
      await SupabaseService.client.rpc(
        'save_onboarding_profile_type',
        params: {
          'p_profile_for': profileFor,
          'p_profile_creator_relation':
              data.wardRelationship ?? data.profileCreatorRelation ?? 'self',
        },
      );
      return true;
    } catch (error) {
      _noteWriteFailure(error);
      OperationalTelemetryService.record(
        'profile_write',
        'profile_type_resume_failed',
      );
      return false;
    }
  }

  static Future<bool> saveOnboardingLocation(OnboardingData data) async {
    if (!_canWrite || _userId == null) return false;
    final resolvedData = await _ensureLocationRows(data);
    if (resolvedData == null) return false;

    return _writeOnboardingLocation(resolvedData);
  }

  static Future<bool> _writeOnboardingLocation(OnboardingData data) async {
    final countryCode = _normalCountryCode(data.countryCode);
    final cityName = _cityNameForWrite(data);
    final cityId = int.tryParse(data.cityId ?? '');
    if (countryCode == null ||
        cityName == null ||
        cityId == null ||
        data.lat == null ||
        data.lng == null) {
      return false;
    }

    try {
      await SupabaseService.client.rpc(
        'save_onboarding_location',
        params: {
          'p_country_code': countryCode,
          'p_city_id': cityId,
          'p_city_name': cityName,
          'p_state_name': data.stateName,
          'p_postal_code': data.postalCode,
          'p_lat': data.lat,
          'p_lng': data.lng,
        },
      );
      return true;
    } catch (error) {
      _noteWriteFailure(error);
      OperationalTelemetryService.record(
        'profile_write',
        'onboarding_location_failed',
      );
      return false;
    }
  }

  static Future<OnboardingData?> _prepareBasicIdentityWrite(
    OnboardingData data,
  ) async {
    final countryCode = _normalCountryCode(data.countryCode);
    final cityName = _cityNameForWrite(data);
    if (countryCode == null ||
        cityName == null ||
        data.lat == null ||
        data.lng == null) {
      return null;
    }

    return data.copyWith(countryCode: countryCode, cityName: cityName);
  }

  static Future<bool> _ensureProfileRowForPartialStep(
    OnboardingData data, {
    required bool isGuardianPath,
  }) async {
    try {
      final existing = await SupabaseService.client
          .from('my_profile_private')
          .select('id')
          .eq('user_id', _userId!)
          .maybeSingle();
      if (existing != null) return true;
    } catch (error) {
      _noteWriteFailure(error);
      return false;
    }

    final preparedData = await _prepareBasicIdentityWrite(data);
    if (preparedData == null) return false;
    return _saveBasicIdentityStep(
      preparedData,
      isGuardianPath: isGuardianPath,
    );
  }

  static Future<bool> _saveBasicIdentityStep(
    OnboardingData data, {
    required bool isGuardianPath,
  }) async {
    final countryCode = _normalCountryCode(data.countryCode);
    final cityName = _cityNameForWrite(data);
    final gender = _genderToString(data.gender);
    final dateOfBirth = data.dateOfBirth?.toIso8601String().split('T').first;
    if (countryCode == null ||
        cityName == null ||
        data.lat == null ||
        data.lng == null ||
        gender == null ||
        dateOfBirth == null ||
        _cleanText(data.firstName) == null ||
        data.heightCm == null) {
      return false;
    }

    final isGuardian = isGuardianPath || _isGuardianData(data);
    try {
      await SupabaseService.client.rpc('save_basic_identity_step', params: {
        'p_profile_owner_type': _profileOwnerTypeForDb(data),
        'p_profile_creator_relation': _creatorRelationForDb(data),
        'p_ward_relationship': _wardRelationshipForDb(data),
        'p_guardian_mode': isGuardian ? data.guardianMode ?? 'none' : 'none',
        'p_guardian_relationship': isGuardian
            ? _guardianRelationshipForDb(data.guardianRelationship)
            : null,
        'p_relationship_to_ward': isGuardian
            ? _relationshipToWardForDb(data.guardianRelationship)
            : null,
        'p_guardian_email': isGuardian ? data.guardianEmail : null,
        'p_guardian_authority_scope':
            isGuardian ? data.guardianAuthorityScope ?? 'full' : null,
        'p_first_name': _cleanText(data.firstName),
        'p_last_name': _cleanText(data.lastName),
        'p_date_of_birth': dateOfBirth,
        'p_gender': gender,
        'p_height_cm': data.heightCm,
        'p_complexion': data.complexion?.toLowerCase().replaceAll(' ', '_'),
        'p_mother_tongue': _cleanText(data.motherTongue),
        'p_community': _cleanText(data.community),
        'p_residency_status': _residencyStatusToDb(data.residencyStatus),
        'p_special_needs': _specialNeedsToDb(data.specialNeeds),
        'p_country_code': countryCode,
        'p_city_name': cityName,
        'p_state_name': _cleanText(data.stateName),
        'p_postal_code': _cleanText(data.postalCode),
        'p_lat': data.lat,
        'p_lng': data.lng,
      });
      return true;
    } catch (error) {
      _noteWriteFailure(error);
      debugPrint(
        '[ProfileWriteService] Basic Identity RPC failed: '
        '${error.runtimeType}',
      );
      return false;
    }
  }

  static Future<OnboardingData?> _ensureLocationRows(
    OnboardingData data,
  ) async {
    final countryCode = _normalCountryCode(data.countryCode);
    final cityName = _cityNameForWrite(data);
    if (countryCode == null ||
        cityName == null ||
        data.lat == null ||
        data.lng == null) {
      return null;
    }

    // Shared catalogue creation is service-only. Quick Location resolves a
    // provider-signed result through the location-search Edge Function before
    // any profile write reaches this boundary.
    final cityId = data.cityId?.trim();
    if (cityId == null || int.tryParse(cityId) == null) return null;
    return data.copyWith(
      countryCode: countryCode,
      cityId: cityId,
      cityName: cityName,
    );
  }

  /// Updates the onboarding_step column on the profiles table.
  static Future<bool> updateOnboardingStep(
    int step, {
    bool? isGuardianPath,
    bool? onboardingCompleted,
  }) async {
    if (!_canWrite || _userId == null) return false;
    try {
      await SupabaseService.client
          .rpc('advance_onboarding_step_monotonic', params: {'p_step': step});
      final userProgressSaved = await _updateUserOnboardingProgress(
        null,
        isGuardianPath: isGuardianPath,
        onboardingCompleted: onboardingCompleted,
      );
      if (!userProgressSaved) return false;
      return true;
    } catch (error) {
      _noteWriteFailure(error);
      return false;
    }
  }

  /// Explicit Back button persistence. Forward writes use monotonic updates;
  /// this separate method is the only intentional regression path.
  static Future<bool> setOnboardingStepForBack(int step) async {
    if (!_canWrite || _userId == null) return false;
    try {
      await SupabaseService.client
          .rpc('set_my_onboarding_step_for_back', params: {'p_step': step});
      return true;
    } catch (error) {
      _noteWriteFailure(error);
      return false;
    }
  }

  static Future<bool> markOnboardingComplete() async {
    if (!_canWrite || _userId == null) return false;
    try {
      await SupabaseService.client.rpc('complete_onboarding_profile');
      return true;
    } catch (error) {
      _noteWriteFailure(error);
      return false;
    }
  }

  static Future<bool> _updateUserOnboardingProgress(
    int? step, {
    bool? isGuardianPath,
    bool? onboardingCompleted,
    bool writeStepDirectly = false,
  }) async {
    if (!_canWrite || _userId == null) return false;
    final fields = <String, dynamic>{
      // Forward steps are handled by advance_onboarding_step_monotonic() so a
      // stale async response cannot regress users.onboarding_step. Exact step
      // writes are reserved for explicit Back and final completion.
      if (writeStepDirectly && step != null) 'onboarding_step': step,
      if (isGuardianPath != null) 'is_guardian_path': isGuardianPath,
      if (isGuardianPath != null)
        'profile_owner_type': isGuardianPath ? 'guardian' : 'self',
      if (onboardingCompleted != null)
        'onboarding_completed': onboardingCompleted,
    };

    if (fields.isEmpty) return true;

    try {
      await SupabaseService.client
          .rpc('patch_my_user', params: {'p_fields': fields});
      return true;
    } catch (error) {
      _noteWriteFailure(error);
      return false;
    }
  }

  /// Persists deferred profile sections from Edit Profile after fast-start
  /// onboarding. This keeps "complete later" real, not just locally cached.
  static Future<OnboardingData?> saveFullProfile(
    OnboardingData data, {
    bool locationChanged = false,
  }) async {
    if (!_canWrite || _userId == null) {
      return null;
    }

    try {
      var effectiveData = data;
      if (locationChanged) {
        final resolvedLocation = await _ensureLocationRows(data);
        if (resolvedLocation == null) return null;
        effectiveData = resolvedLocation;
      }

      final fields = _fullProfileFields(effectiveData);
      if (locationChanged) {
        // The dedicated bundle RPC commits profile fields, preferences, user
        // resume location and the discovery point in one transaction.
        fields.remove('city_id');
        fields.remove('country_code');
      }
      final prefFields = _preferenceFields(effectiveData);
      if (locationChanged) {
        final committedLocation = await _saveProfileBundleWithLocation(
          effectiveData,
          profileFields: fields,
          preferenceFields: prefFields,
        );
        if (committedLocation == null) return null;
        effectiveData = committedLocation;
      } else {
        await SupabaseService.client.rpc('save_my_profile_bundle', params: {
          'p_profile_fields': fields,
          'p_preference_fields': prefFields,
        });
      }

      // A successful transport response is not enough: Edit Profile must
      // reopen from the server-authoritative values it just committed. This
      // also prevents a stale in-memory snapshot from replacing fresh edits
      // when the profile screen refreshes immediately after navigation pops.
      final committedData = await loadProfile();
      if (committedData == null ||
          !_preferenceFieldsMatch(effectiveData, committedData)) {
        OperationalTelemetryService.record(
          'profile_write',
          'preference_readback_mismatch',
        );
        return null;
      }
      return committedData;
    } catch (error) {
      _noteWriteFailure(error);
      return null;
    }
  }

  static Future<OnboardingData?> _saveProfileBundleWithLocation(
    OnboardingData data, {
    required Map<String, dynamic> profileFields,
    required Map<String, dynamic> preferenceFields,
  }) async {
    final cityId = int.tryParse(data.cityId ?? '');
    final countryCode = _normalCountryCode(data.countryCode);
    if (cityId == null || countryCode == null) return null;

    try {
      final response = await SupabaseService.client.rpc(
        'save_my_profile_bundle_with_location',
        params: {
          'p_profile_fields': profileFields,
          'p_preference_fields': preferenceFields,
          'p_city_id': cityId,
          'p_country_code': countryCode,
          'p_postal_code': _cleanText(data.postalCode),
        },
      );
      if (response is! Map) return null;
      final result = Map<String, dynamic>.from(response);
      final committedCityId = _intFromRpc(result['city_id']);
      final committedCountry = result['country_code']?.toString();
      final committedCity = result['city_name']?.toString();
      final lat = _toDouble(result['lat']);
      final lng = _toDouble(result['lng']);
      if (committedCityId == null ||
          committedCountry == null ||
          committedCity == null ||
          lat == null ||
          lng == null) {
        return null;
      }

      return data.copyWith(
        cityId: committedCityId.toString(),
        cityName: committedCity,
        stateName: result['state_name']?.toString(),
        countryCode: committedCountry,
        postalCode: result['postal_code']?.toString() ?? '',
        lat: lat,
        lng: lng,
      );
    } catch (error) {
      _noteWriteFailure(error);
      return null;
    }
  }

  // Field mapping per step
  /// Returns a map of DB column → value for the given onboarding step.
  /// Only includes fields that were actually set (non-null).
  static Map<String, dynamic> _fieldsForStep(
    int step,
    OnboardingData data,
    bool isGuardianPath,
  ) {
    switch (step) {
      case OnboardingFlow.profileForWhomStep:
        final relation = data.profileCreatorRelation ??
            (data.profileFor == ProfileFor.myself ? 'self' : 'guardian');
        final dbRelation = relation == 'son' || relation == 'daughter'
            ? 'parent'
            : (relation == 'brother' || relation == 'sister'
                ? 'sibling'
                : relation);

        return _compactMap({
          'profile_owner_type': _profileOwnerTypeForDb(data),
          'profile_creator_relation': dbRelation,
          'ward_relationship': _wardRelationshipForDb(data),
          'guardian_mode': 'none',
          'guardian_user_id': null,
        });

      case OnboardingFlow.quickLocationStepIndex:
        return _locationFields(data);

      case OnboardingFlow.basicIdentityStep:
        final isGuardian = _isGuardianData(data);
        return _compactMap({
          ..._locationFields(data),
          'profile_owner_type': _profileOwnerTypeForDb(data),
          'profile_creator_relation': _creatorRelationForDb(data),
          'ward_relationship': _wardRelationshipForDb(data),
          'guardian_mode': isGuardian ? data.guardianMode ?? 'none' : 'none',
          'guardian_user_id': null,
          'guardian_relationship': isGuardian
              ? _guardianRelationshipForDb(data.guardianRelationship)
              : null,
          'relationship_to_ward': isGuardian
              ? _relationshipToWardForDb(data.guardianRelationship)
              : null,
          'guardian_email': isGuardian ? data.guardianEmail : null,
          'guardian_authority_scope':
              isGuardian ? data.guardianAuthorityScope ?? 'full' : null,
          'first_name': data.firstName,
          'last_name': data.lastName,
          'date_of_birth': data.dateOfBirth?.toIso8601String().split('T')[0],
          'gender': _genderToString(data.gender),
          'height_cm': data.heightCm,
          'complexion': data.complexion?.toLowerCase().replaceAll(' ', '_'),
          'mother_tongue': data.motherTongue,
          'community': data.community,
          'residency_status': _residencyStatusToDb(data.residencyStatus),
          'special_needs': _specialNeedsToDb(data.specialNeeds),
        });

      case OnboardingFlow.islamicIdentityStep:
        return _compactMap({
          'sect': _sectToString(data.sect),
          'sub_sect': data.subSect,
          'deen_level': _deenLevelToString(data.deenLevel),
          'prays_five_daily': data.praysFiveDaily,
          'hijab': _modestyOptionToDb(data.hijabStyle),
          'beard': _modestyOptionToDb(data.beardStyle),
          'diet_type': data.dietType,
          'smoking_habit': _habitToDb(data.smokingHabit),
          'vaping_habit': _habitToDb(data.vapingHabit),
          'hookah_habit': _habitToDb(data.hookahHabit),
        });

      case OnboardingFlow.photoUploadStep:
        // ProfilePhotoService owns this step transactionally: it persists
        // photo_privacy through set_my_photo_privacy before reserving and
        // publishing any photo slots. Repeating the field through the general
        // profile bundle makes an otherwise successful upload depend on an
        // unrelated RPC and can strand the user on the final onboarding step.
        return const <String, dynamic>{};

      case 5:
        final fields = <String, dynamic>{
          'quran_memorization': data.quranMemorization,
          'religious_education': data.religiousEducation,
          'is_revert': data.isRevert,
          'marriage_timeline': data.marriageTimeline,
          'willing_to_relocate': data.willingToRelocate,
          'religious_leadership': data.religiousLeadership,
        };

        if (data.gender == Gender.female) {
          fields.addAll({
            'niqab_preference': data.niqabPreference,
            'mahr_expectation': data.mahrExpectation,
            'willing_to_work_after_marriage': data.willingToWorkAfterMarriage,
            'polygamy_acceptance': data.polygamyAcceptance,
          });
        } else if (data.gender == Gender.male) {
          fields.addAll({
            'mahr_budget': data.mahrBudget,
            'can_provide_housing': data.canProvideHousing,
            'can_provide_maintenance': data.canProvideMaintenance,
            'debt_status': data.debtStatus,
            'polygamy_status': data.polygamyStatus,
          });
        }

        return _compactMap(fields);

      case 6:
        return _compactMap({
          'education_level': data.educationLabel,
          'education_rank': data.educationRank,
          'field_of_study': data.fieldOfStudy,
          'profession': data.profession,
          'employment_status': _employmentStatusToString(data.employmentStatus),
          'income_bracket': data.incomeBracketId,
          'income_visibility': data.incomeVisibility,
        });

      case 7:
        return _compactMap({
          'family_type': _familyTypeToString(data.familyType),
          'sibling_count': data.siblingCount,
          'is_eldest_child': data.isEldestChild,
          'parents_status': data.parentsStatus,
          'previously_married': data.previouslyMarried,
          'children_count': data.childrenCount,
          'living_expectation': data.livingExpectation,
        });

      // Deferred bio and interests
      case 8:
        return _compactMap({
          'bio': data.bio,
          'interests': data.interests,
          'languages': data.languages,
        });

      // Deferred partner preferences
      case 9:
        return {}; // Handled by _preferenceFieldsForStep

      // Review section has no direct fields
      case 10:
        return {};

      // Completion section has no direct fields
      case 11:
        return {};

      default:
        return {};
    }
  }

  /// Returns deferred partner preference fields.
  static Map<String, dynamic> _preferenceFieldsForStep(
    int step,
    OnboardingData data,
  ) {
    // Partner preferences are no longer part of the required five-step flow.
    // This mapper remains for edit-profile/deferred completion saves.
    if (step != 9) return {};

    return _compactMap({
      'preferred_age_min': data.preferredAgeMin,
      'preferred_age_max': data.preferredAgeMax,
      'sect_preference': data.preferredSect,
      'deen_preference': data.preferredDeenLevel,
      'min_education_rank': data.minEducationRank,
      'open_to_divorced': data.openToDivorced,
      'open_to_widowed': data.openToWidowed,
      'open_to_has_children': data.openToWithChildren,
      'open_to_diaspora': data.openToDiaspora,
      'preferred_living_expectation': data.preferredLivingExpectation,
      'diaspora_mode': data.locationPreference == LocationPreference.diaspora,
      'location_preference': data.locationPreference
          ?.name, // Fixed Flaw 21: Persist LocationPreference name
    });
  }

  static Map<String, dynamic> _fullProfileFields(OnboardingData data) {
    // Edit Profile only owns ordinary member attributes. Ownership, guardian
    // settings and photo privacy each have dedicated RPCs with their own
    // validation/audit rules. Including those values here makes the secured
    // patch_my_profile allowlist reject the entire otherwise-valid edit.
    final fields = <String, dynamic>{
      ..._locationFields(data),
      'first_name': data.firstName,
      'last_name': data.lastName,
      'date_of_birth': data.dateOfBirth?.toIso8601String().split('T')[0],
      'gender': _genderToString(data.gender),
      'height_cm': data.heightCm,
      'complexion': data.complexion?.toLowerCase().replaceAll(' ', '_'),
      'mother_tongue': data.motherTongue,
      'community': data.community,
      'residency_status': _residencyStatusToDb(data.residencyStatus),
      'special_needs': _specialNeedsToDb(data.specialNeeds),
      'sect': _sectToString(data.sect),
      'sub_sect': data.subSect,
      'deen_level': _deenLevelToString(data.deenLevel),
      'prays_five_daily': data.praysFiveDaily,
      'hijab': _modestyOptionToDb(data.hijabStyle),
      'beard': _modestyOptionToDb(data.beardStyle),
      'diet_type': data.dietType,
      'smoking_habit': _habitToDb(data.smokingHabit),
      'vaping_habit': _habitToDb(data.vapingHabit),
      'hookah_habit': _habitToDb(data.hookahHabit),
      'education_level': data.educationLabel,
      'education_rank': data.educationRank,
      'field_of_study': data.fieldOfStudy,
      'profession': data.profession,
      'employment_status': _employmentStatusToString(data.employmentStatus),
      'income_bracket': data.incomeBracketId,
      'income_visibility': data.incomeVisibility,
      'family_type': _familyTypeToString(data.familyType),
      'sibling_count': data.siblingCount,
      'is_eldest_child': data.isEldestChild,
      'parents_status': data.parentsStatus,
      'previously_married': data.previouslyMarried,
      'children_count': data.childrenCount,
      'living_expectation': data.livingExpectation,
      'bio': data.bio,
      'interests': data.interests,
      'languages': data.languages,
      'quran_memorization': data.quranMemorization,
      'religious_education': data.religiousEducation,
      'is_revert': data.isRevert,
      'marriage_timeline': data.marriageTimeline,
      'willing_to_relocate': data.willingToRelocate,
      'religious_leadership': data.religiousLeadership,
    };

    if (data.gender == Gender.female) {
      fields.addAll({
        'niqab_preference': data.niqabPreference,
        'mahr_expectation': data.mahrExpectation,
        'willing_to_work_after_marriage': data.willingToWorkAfterMarriage,
        'polygamy_acceptance': data.polygamyAcceptance,
      });
    } else if (data.gender == Gender.male) {
      fields.addAll({
        'mahr_budget': data.mahrBudget,
        'can_provide_housing': data.canProvideHousing,
        'can_provide_maintenance': data.canProvideMaintenance,
        'debt_status': data.debtStatus,
        'polygamy_status': data.polygamyStatus,
      });
    }

    return _compactMap(fields);
  }

  /// Exposes the Edit Profile payload only to contract tests. Keeping this
  /// test at the mapper boundary prevents a UI refactor from reintroducing
  /// fields owned by security-sensitive dedicated RPCs.
  @visibleForTesting
  static Map<String, dynamic> buildEditProfileFieldsForTest(
    OnboardingData data,
  ) =>
      _fullProfileFields(data);

  @visibleForTesting
  static Map<String, dynamic> buildEditPreferenceFieldsForTest(
    OnboardingData data,
  ) =>
      _preferenceFields(data);

  static Map<String, dynamic> _locationFields(OnboardingData data) {
    return _compactMap({
      'city_id':
          (data.cityId != null && RegExp(r'^\d+$').hasMatch(data.cityId!))
              ? int.parse(data.cityId!)
              : null,
      'country_code': _normalCountryCode(data.countryCode),
    });
  }

  static String? _normalCountryCode(String? countryCode) {
    final normalized = countryCode?.trim().toUpperCase();
    if (normalized == null || normalized.length != 2) return null;
    return normalized;
  }

  static String? _cleanText(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }

  static String? _cityNameForWrite(OnboardingData data) {
    final raw = _cleanText(data.cityName);
    if (raw == null) return null;
    return raw.split(',').first.trim();
  }

  static int? _intFromRpc(dynamic response) {
    if (response is int) return response;
    if (response is num) return response.toInt();
    return int.tryParse(response?.toString() ?? '');
  }

  static String? _habitToDb(String? value) {
    switch (_normalizeOption(value)?.replaceAll('_', ' ')) {
      case 'never':
        return 'never';
      case 'occasionally':
        return 'occasionally';
      case 'frequently':
        return 'frequently';
      case 'prefer not':
      case 'prefer not to say':
        return 'prefer_not';
      default:
        return null;
    }
  }

  static String? _habitFromDb(String? value) {
    switch (_normalizeOption(value)) {
      case 'never':
        return 'Never';
      case 'occasionally':
        return 'Occasionally';
      case 'frequently':
        return 'Frequently';
      case 'prefer_not':
        return 'Prefer not to say';
      default:
        return value;
    }
  }

  static String? _modestyOptionToDb(String? value) {
    switch (_normalizeOption(value)?.replaceAll('_', ' ')) {
      case 'always':
        return 'always';
      case 'sometimes':
        return 'sometimes';
      case 'yes':
        return 'yes';
      case 'no':
        return 'no';
      case 'prefer not to say':
      case 'prefer not':
        return 'prefer_not_to_say';
      default:
        return value;
    }
  }

  static String? _hijabFromDb(String? value) {
    switch (_normalizeOption(value)) {
      case 'always':
        return 'Always';
      case 'sometimes':
        return 'Sometimes';
      case 'no':
        return 'No';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return value;
    }
  }

  static String? _beardFromDb(String? value) {
    switch (_normalizeOption(value)) {
      case 'yes':
        return 'yes';
      case 'no':
        return 'no';
      case 'prefer_not_to_say':
        return 'prefer_not_to_say';
      default:
        return value;
    }
  }

  static bool _isGuardianData(OnboardingData data) {
    return data.profileOwnerType == ProfileOwnerType.guardian ||
        data.profileFor == ProfileFor.guardian ||
        data.isGuardianMode;
  }

  static String _profileOwnerTypeForDb(OnboardingData data) {
    return _isGuardianData(data) ? 'guardian' : 'self';
  }

  static String? _guardianRelationshipForDb(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized == 'guardian') return 'other';
    if (normalized == 'parent') return 'father';
    if (normalized == 'sibling') return 'brother';
    const allowed = {
      'father',
      'mother',
      'brother',
      'sister',
      'uncle',
      'aunt',
      'other',
    };
    return allowed.contains(normalized) ? normalized : null;
  }

  static String? _relationshipToWardForDb(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized == 'parent') return 'father';
    if (normalized == 'sibling') return 'brother';
    const allowed = {
      'father',
      'mother',
      'brother',
      'sister',
      'uncle',
      'aunt',
      'guardian',
    };
    return allowed.contains(normalized) ? normalized : null;
  }

  static String? _wardRelationshipForDb(OnboardingData data) {
    if (!_isGuardianData(data)) return null;
    final normalized = (data.wardRelationship ?? data.profileCreatorRelation)
        ?.trim()
        .toLowerCase();
    const allowed = {'son', 'daughter', 'brother', 'sister'};
    return allowed.contains(normalized) ? normalized : null;
  }

  static Map<String, dynamic> _preferenceFields(OnboardingData data) {
    return _compactMap({
      'preferred_age_min': data.preferredAgeMin,
      'preferred_age_max': data.preferredAgeMax,
      'sect_preference': data.preferredSect,
      'deen_preference': data.preferredDeenLevel,
      'min_education_rank': data.minEducationRank,
      'open_to_divorced': data.openToDivorced,
      'open_to_widowed': data.openToWidowed,
      'open_to_has_children': data.openToWithChildren,
      'open_to_diaspora': data.openToDiaspora,
      'preferred_living_expectation': data.preferredLivingExpectation,
      'diaspora_mode': data.locationPreference == LocationPreference.diaspora,
      'location_preference': data.locationPreference?.name,
    });
  }

  static bool _preferenceFieldsMatch(
    OnboardingData requested,
    OnboardingData committed,
  ) {
    final expected = _preferenceFields(requested);
    final actual = _preferenceFields(committed);
    return expected.entries.every((entry) => actual[entry.key] == entry.value);
  }

  static String? _creatorRelationForDb(OnboardingData data) {
    final relation = data.wardRelationship ??
        data.profileCreatorRelation ??
        (data.profileFor == ProfileFor.myself ? 'self' : 'guardian');
    if (relation == 'son' || relation == 'daughter') return 'parent';
    if (relation == 'brother' || relation == 'sister') return 'sibling';
    return relation;
  }

  /// Loads profile data from Supabase for the current user to restore onboarding state.
  ///
  /// Returns null only when nobody is signed in. A failed read throws
  /// [ProfileLoadException]: treating it as "no profile" once let Edit
  /// Profile open blank and a save then overwrite the real profile.
  static Future<OnboardingData?> loadProfile() async {
    if (!_canWrite || _userId == null) return null;

    try {
      // 1. Fetch users row first: early onboarding data exists before profiles.
      final userId = _userId!;
      final Map<String, dynamic>? userRes =
          await MyAccountSnapshot.instance.user(userId);

      // 2. Fetch profiles table row
      final profileRes = await MyAccountSnapshot.instance.profile(userId);

      if (profileRes == null) return _mapUserResumeToOnboardingData(userRes);

      // 3. Fetch private preferences through the owner-scoped SECURITY
      // DEFINER read boundary. Direct table reads are intentionally revoked;
      // an RLS policy that joins profiles cannot work without re-granting the
      // wider profiles table, which would weaken the member privacy boundary.
      final preferenceResponse = await _preferences.read(userId);
      final prefRes = preferenceResponse is Map
          ? Map<String, dynamic>.from(preferenceResponse)
          : null;

      // 4. Construct and return OnboardingData
      return _mapDbToOnboardingData(profileRes, prefRes, userRes);
    } catch (error) {
      throw ProfileLoadException(error);
    }
  }

  static OnboardingData _mapDbToOnboardingData(
    Map<String, dynamic> p,
    Map<String, dynamic>? pr,
    Map<String, dynamic>? u,
  ) {
    final ownerTypeRaw = p['profile_owner_type'] as String?;
    final creatorRel = p['profile_creator_relation'] as String?;
    final guardianMode = p['guardian_mode'] as String?;
    // Profile ownership and Guardian oversight are separate concepts. A
    // self-owned member remains self-owned after connecting a Guardian.
    final isGuardian = ownerTypeRaw == 'guardian';

    // Parse date of birth
    DateTime? dob;
    if (p['date_of_birth'] != null) {
      dob = DateTime.tryParse(p['date_of_birth'] as String);
    }

    // Parse gender
    Gender? gender;
    if (p['gender'] != null) {
      gender = p['gender'] == 'female' ? Gender.female : Gender.male;
    }

    // Parse complexion
    String? complexionVal = p['complexion'] as String?;
    String? complexion;
    if (complexionVal != null) {
      switch (complexionVal) {
        case 'fair':
          complexion = 'Fair';
          break;
        case 'medium':
          complexion = 'Medium';
          break;
        case 'olive':
          complexion = 'Olive';
          break;
        case 'dark':
          complexion = 'Dark';
          break;
        case 'prefer_not_to_say':
          complexion = 'Prefer not to say';
          break;
        default:
          complexion = complexionVal;
      }
    }

    // Parse sect
    Sect? sect;
    if (p['sect'] != null) {
      switch (p['sect'] as String) {
        case 'sunni':
          sect = Sect.sunni;
          break;
        case 'shia':
          sect = Sect.shia;
          break;
        case 'prefer_not_to_say':
          sect = Sect.preferNotToSay;
          break;
        case 'other':
          sect = Sect.other;
          break;
      }
    }

    // Parse deenLevel
    DeenLevel? deen;
    if (p['deen_level'] != null) {
      switch (p['deen_level'] as String) {
        case 'practicing':
          deen = DeenLevel.practicing;
          break;
        case 'moderate':
          deen = DeenLevel.moderate;
          break;
        case 'cultural':
          deen = DeenLevel.cultural;
          break;
      }
    }

    // Parse employmentStatus
    EmploymentStatus? empStatus;
    if (p['employment_status'] != null) {
      switch (p['employment_status'] as String) {
        case 'employed':
          empStatus = EmploymentStatus.employed;
          break;
        case 'self_employed':
          empStatus = EmploymentStatus.selfEmployed;
          break;
        case 'student':
          empStatus = EmploymentStatus.student;
          break;
        case 'not_working':
          empStatus = EmploymentStatus.notWorking;
          break;
      }
    }

    // Parse familyType
    FamilyType? famType;
    if (p['family_type'] != null) {
      switch (p['family_type'] as String) {
        case 'nuclear':
          famType = FamilyType.nuclear;
          break;
        case 'joint':
          famType = FamilyType.joint;
          break;
        case 'extended':
          famType = FamilyType.extended;
          break;
      }
    }

    // Parse maritalStatus
    MaritalStatus? marStatus;
    final previouslyMarried = p['previously_married'] as String?;
    if (previouslyMarried != null) {
      switch (previouslyMarried) {
        case 'no':
          marStatus = MaritalStatus.neverMarried;
          break;
        case 'divorced':
          marStatus = MaritalStatus.divorced;
          break;
        case 'widowed':
          marStatus = MaritalStatus.widowed;
          break;
      }
    }

    // Parse LocationPreference
    LocationPreference? locPref;
    if (pr != null) {
      final locPrefStr = pr['location_preference'] as String?;
      if (locPrefStr != null) {
        try {
          locPref = LocationPreference.values.byName(locPrefStr);
        } catch (_) {}
      }
      if (locPref == null) {
        final diaspora = pr['diaspora_mode'] as bool? ?? false;
        if (diaspora) {
          locPref = LocationPreference.diaspora;
        }
      }
    }

    // Map profile_creator_relation back
    String? wardRelationship = p['ward_relationship'] as String?;
    String? profileCreatorRelation = wardRelationship ?? creatorRel;
    String? guardianRelationship = (p['relationship_to_ward'] as String?) ??
        (p['guardian_relationship'] as String?);
    if (isGuardian) {
      if (wardRelationship == null && creatorRel == 'parent') {
        profileCreatorRelation = gender == Gender.female ? 'daughter' : 'son';
        wardRelationship = profileCreatorRelation;
        guardianRelationship ??= 'father';
      } else if (wardRelationship == null && creatorRel == 'sibling') {
        profileCreatorRelation = gender == Gender.female ? 'sister' : 'brother';
        wardRelationship = profileCreatorRelation;
        guardianRelationship ??= 'brother';
      } else if (creatorRel == 'guardian') {
        profileCreatorRelation = 'guardian';
        guardianRelationship ??= 'guardian';
      }
    }

    return OnboardingData(
      profileFor: isGuardian ? ProfileFor.guardian : ProfileFor.myself,
      profileOwnerType:
          isGuardian ? ProfileOwnerType.guardian : ProfileOwnerType.self,
      wardRelationship: wardRelationship,
      wardGender: isGuardian ? gender : null,
      firstName: p['first_name'] as String?,
      lastName: p['last_name'] as String?,
      dateOfBirth: dob,
      gender: gender,
      cityId: p['city_id']?.toString(),
      cityName: u?['onboarding_city_name'] as String?,
      stateName: u?['onboarding_state_name'] as String?,
      postalCode: u?['onboarding_postal_code'] as String?,
      lat: _toDouble(u?['onboarding_lat']),
      lng: _toDouble(u?['onboarding_lng']),
      countryCode:
          (p['country_code'] as String?) ?? (u?['country_code'] as String?),
      heightCm: p['height_cm'] as int?,
      complexion: complexion,
      motherTongue: p['mother_tongue'] as String?,
      community: p['community'] as String?,
      residencyStatus: _residencyStatusFromDb(p['residency_status'] as String?),
      sect: sect,
      subSect: p['sub_sect'] as String?,
      deenLevel: deen,
      praysFiveDaily: p['prays_five_daily'] as bool?,
      hijabStyle: _hijabFromDb(p['hijab'] as String?),
      beardStyle: _beardFromDb(p['beard'] as String?),
      dietType: p['diet_type'] as String?,
      smokingHabit: _habitFromDb(p['smoking_habit'] as String?),
      vapingHabit: _habitFromDb(p['vaping_habit'] as String?),
      hookahHabit: _habitFromDb(p['hookah_habit'] as String?),
      educationRank: p['education_rank'] as int?,
      educationLabel: p['education_level'] as String?,
      fieldOfStudy: p['field_of_study'] as String?,
      profession: p['profession'] as String?,
      employmentStatus: empStatus,
      incomeBracketId: p['income_bracket'] as int?,
      incomeVisibility: p['income_visibility'] as String?,
      familyType: famType,
      siblingCount: p['sibling_count'] as int?,
      isEldestChild: p['is_eldest_child'] as bool?,
      parentsStatus: p['parents_status'] as String?,
      maritalStatus: marStatus,
      hasChildren: (p['children_count'] as int? ?? 0) > 0,
      childrenCount: p['children_count'] as int?,
      livingExpectation: p['living_expectation'] as String?,
      bio: p['bio'] as String?,
      interests: p['interests'] != null
          ? List<String>.from(p['interests'] as Iterable)
          : null,
      languages: p['languages'] != null
          ? List<String>.from(p['languages'] as Iterable)
          : null,
      preferredAgeMin: pr?['preferred_age_min'] as int?,
      preferredAgeMax: pr?['preferred_age_max'] as int?,
      locationPreference: locPref,
      preferredSect: pr?['sect_preference'] as String?,
      preferredDeenLevel: pr?['deen_preference'] as String?,
      minEducationRank: pr?['min_education_rank'] as int?,
      openToDivorced: pr?['open_to_divorced'] as bool?,
      openToWidowed: pr?['open_to_widowed'] as bool?,
      openToWithChildren: pr?['open_to_has_children'] as bool?,
      openToDiaspora: pr?['open_to_diaspora'] as bool?,
      preferredLivingExpectation:
          pr?['preferred_living_expectation'] as String?,
      photoPrivacy: p['photo_privacy'] == 'mutual_only'
          ? PhotoPrivacy.mutualOnly
          : p['photo_privacy'] == 'request_only'
              ? PhotoPrivacy.requestOnly
              : PhotoPrivacy.publicAll,
      quranMemorization: p['quran_memorization'] as String?,
      religiousEducation: p['religious_education'] as String?,
      marriageTimeline: p['marriage_timeline'] as String?,
      willingToRelocate: p['willing_to_relocate'] as String?,
      niqabPreference: p['niqab_preference'] as String?,
      mahrExpectation: p['mahr_expectation'] as String?,
      willingToWorkAfterMarriage: p['willing_to_work_after_marriage'] as bool?,
      mahrBudget: p['mahr_budget'] as String?,
      canProvideHousing: p['can_provide_housing'] as bool?,
      canProvideMaintenance: p['can_provide_maintenance'] as bool?,
      debtStatus: p['debt_status'] as String?,
      religiousLeadership: p['religious_leadership'] as String?,
      email: u?['email'] as String?,
      guardianName: p['guardian_name'] as String?,
      guardianRelationship: guardianRelationship,
      isGuardianMode: isGuardian,
      profileCreatorRelation: profileCreatorRelation,
      guardianEmail: p['guardian_email'] as String?,
      guardianAuthorityScope: p['guardian_authority_scope'] as String?,
      guardianMode: guardianMode,
      isRevert: p['is_revert'] as String?,
      polygamyStatus: p['polygamy_status'] as String?,
      polygamyAcceptance: p['polygamy_acceptance'] as String?,
      specialNeeds: _specialNeedsFromDb(p['special_needs'] as String?),
    );
  }

  static OnboardingData? _mapUserResumeToOnboardingData(
    Map<String, dynamic>? u,
  ) {
    if (u == null) return null;

    final profileForRaw = u['onboarding_profile_for'] as String?;
    final ownerTypeRaw = u['profile_owner_type'] as String?;
    final isGuardianPath = u['is_guardian_path'] as bool? ?? false;
    final profileFor = ownerTypeRaw == 'guardian' ||
            profileForRaw == 'guardian' ||
            isGuardianPath
        ? ProfileFor.guardian
        : ownerTypeRaw == 'self' || profileForRaw == 'myself'
            ? ProfileFor.myself
            : null;
    final cityName = u['onboarding_city_name'] as String?;
    final countryCode = u['country_code'] as String?;
    final wardRelationship =
        u['onboarding_profile_creator_relation'] as String?;

    final hasAnyResumeData = profileFor != null ||
        (countryCode?.trim().isNotEmpty == true) ||
        (cityName?.trim().isNotEmpty == true);
    if (!hasAnyResumeData) return null;

    return OnboardingData(
      profileFor: profileFor,
      profileOwnerType: profileFor == ProfileFor.guardian
          ? ProfileOwnerType.guardian
          : profileFor == ProfileFor.myself
              ? ProfileOwnerType.self
              : null,
      isGuardianMode: profileFor == ProfileFor.guardian,
      wardRelationship:
          profileFor == ProfileFor.guardian ? wardRelationship : null,
      wardGender: profileFor == ProfileFor.guardian
          ? _wardGenderFromRelationship(wardRelationship)
          : null,
      gender: profileFor == ProfileFor.guardian
          ? _wardGenderFromRelationship(wardRelationship)
          : null,
      profileCreatorRelation: wardRelationship,
      email: u['email'] as String?,
      countryCode: countryCode,
      cityId: u['onboarding_city_id']?.toString(),
      cityName: cityName,
      stateName: u['onboarding_state_name'] as String?,
      postalCode: u['onboarding_postal_code'] as String?,
      lat: _toDouble(u['onboarding_lat']),
      lng: _toDouble(u['onboarding_lng']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static Gender? _wardGenderFromRelationship(String? relation) {
    switch (relation?.trim().toLowerCase()) {
      case 'daughter':
      case 'sister':
        return Gender.female;
      case 'son':
      case 'brother':
        return Gender.male;
      default:
        return null;
    }
  }

  // Enum → String converters
  static String? _genderToString(Gender? g) {
    if (g == null) return null;
    switch (g) {
      case Gender.male:
        return 'male';
      case Gender.female:
        return 'female';
    }
  }

  static String? _sectToString(Sect? s) {
    if (s == null) return null;
    switch (s) {
      case Sect.sunni:
        return 'sunni';
      case Sect.shia:
        return 'shia';
      case Sect.preferNotToSay:
        return 'prefer_not_to_say';
      case Sect.other:
        return 'other';
    }
  }

  static String? _deenLevelToString(DeenLevel? d) {
    if (d == null) return null;
    switch (d) {
      case DeenLevel.practicing:
        return 'practicing';
      case DeenLevel.moderate:
        return 'moderate';
      case DeenLevel.cultural:
        return 'cultural';
    }
  }

  static String? _familyTypeToString(FamilyType? f) {
    if (f == null) return null;
    switch (f) {
      case FamilyType.nuclear:
        return 'nuclear';
      case FamilyType.joint:
        return 'joint';
      case FamilyType.extended:
        return 'extended';
    }
  }

  static String? _employmentStatusToString(EmploymentStatus? e) {
    if (e == null) return null;
    switch (e) {
      case EmploymentStatus.employed:
        return 'employed';
      case EmploymentStatus.selfEmployed:
        return 'self_employed';
      case EmploymentStatus.student:
        return 'student';
      case EmploymentStatus.notWorking:
        return 'not_working';
    }
  }

  static String? _residencyStatusToDb(String? value) {
    final normalized = _normalizeOption(value);
    if (normalized == null) return null;
    switch (normalized) {
      case 'citizen':
        return 'citizen';
      case 'permanent resident':
      case 'permanent_resident':
        return 'permanent_resident';
      case 'work visa':
      case 'work_visa':
        return 'work_visa';
      case 'student visa':
      case 'student_visa':
        return 'student_visa';
      case 'other':
        return 'other';
      case 'prefer not to say':
      case 'prefer_not_to_say':
        return 'prefer_not_to_say';
      default:
        return null;
    }
  }

  static String? _residencyStatusFromDb(String? value) {
    switch (_normalizeOption(value)) {
      case 'citizen':
        return 'Citizen';
      case 'permanent_resident':
        return 'Permanent Resident';
      case 'work_visa':
        return 'Work Visa';
      case 'student_visa':
        return 'Student Visa';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return value;
    }
  }

  static String? _specialNeedsToDb(String? value) {
    final normalized = _normalizeOption(value);
    if (normalized == null) return null;
    switch (normalized) {
      case 'none':
        return 'none';
      case 'physical disability':
      case 'physical':
        return 'physical';
      case 'hearing impairment':
      case 'hearing':
        return 'hearing';
      case 'visual impairment':
      case 'visual':
        return 'visual';
      case 'other':
        return 'other';
      case 'prefer not to say':
      case 'prefer_not_to_say':
        return 'prefer_not_to_say';
      default:
        return null;
    }
  }

  static String? _specialNeedsFromDb(String? value) {
    switch (_normalizeOption(value)) {
      case 'none':
        return 'None';
      case 'physical':
        return 'Physical disability';
      case 'hearing':
        return 'Hearing impairment';
      case 'visual':
        return 'Visual impairment';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return value;
    }
  }

  static String? _normalizeOption(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
  }

  // Helpers
  /// Removes null values from a map to enable partial upserts.
  static Map<String, dynamic> _compactMap(Map<String, dynamic> input) {
    return Map.fromEntries(
      input.entries.where((e) => e.value != null),
    );
  }
}

/// The profile could not be read (offline, timeout, server error). Callers
/// keep what they have and never treat this as an empty profile.
class ProfileLoadException implements Exception {
  const ProfileLoadException(this.cause);

  final Object cause;

  @override
  String toString() => 'ProfileLoadException: $cause';
}
