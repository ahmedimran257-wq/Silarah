// SILARAH — Profile Transport Model
// Legacy profile transport model used for real Supabase rows.
// Each entry maps to the SilarahProfileCard constructor params.
import '../utils/member_name.dart';

class DiscoveryProfile {
  const DiscoveryProfile({
    String? id,
    required this.firstName,
    required this.lastNameInitial,
    required this.age,
    required this.cityName,
    this.sect,
    this.deenLevel,
    this.photoUrl,
    this.photoUrls = const [],
    this.photoCount = 0,
    this.isPhotoPrivate = false,
    this.photoPrivacy = 'public',
    this.isVerified = false,
    this.guardianConnected = false,
    this.establishedMember = false,
    this.occupation,
    this.education,
    this.bio,
    this.languages,
    this.maritalStatus,
    this.familyType,
    this.interests,
    // Partner preferences
    this.partnerAgeMin,
    this.partnerAgeMax,
    this.partnerSect,
    this.partnerDeenLevel,
    this.partnerEducationMinRank,
    // Existing fields
    this.heightCm,
    this.complexion,
    this.motherTongue,
    this.smokingHabit,
    this.vapingHabit,
    this.hookahHabit,
    this.isGuardianProfile = false,
    this.community,
    this.dietType,
    this.livingExpectation,
    this.quranMemorization,
    this.religiousEducation,
    this.marriageTimeline,
    this.willingToRelocate,
    this.gender,
    this.hasChildren = false,
    // D3: Last active timestamp for recency display
    this.lastActiveAt,
    this.countryCode,
    this.lastName,
    this.incomeBracket,
    this.familyOriginCity,
    this.blurhash,
    this.previousMatchAt,
    this.previousMatchEndedAt,
    this.priorMatchCount = 0,
    this.rematchAvailableAt,
    this.relationshipState = 'none',
  }) : _id = id;

  final String? _id;
  final String firstName;
  final String lastNameInitial;
  final int age;
  final String cityName;
  final String? sect;
  final String? deenLevel;
  final String? photoUrl;

  /// Ordered, authorized gallery URLs. [photoUrl] remains as a compatibility
  /// alias for card surfaces that only render the primary image.
  final List<String> photoUrls;
  final int photoCount;

  List<String> get orderedPhotoUrls {
    final urls = <String>[];
    for (final value in [photoUrl, ...photoUrls]) {
      final normalized = value?.trim();
      if (normalized != null &&
          normalized.isNotEmpty &&
          !urls.contains(normalized)) {
        urls.add(normalized);
      }
    }
    return List.unmodifiable(urls);
  }

  final bool isPhotoPrivate;
  final String photoPrivacy;
  String get effectivePhotoPrivacy =>
      photoPrivacy == 'public' && isPhotoPrivate ? 'mutual_only' : photoPrivacy;
  final bool isVerified;
  final bool guardianConnected;
  final bool establishedMember;
  final String? occupation;
  final String? education;
  final String? bio;
  final List<String>? languages;
  final String? maritalStatus;
  final String? familyType;
  final List<String>? interests;
  final int? partnerAgeMin;
  final int? partnerAgeMax;
  final String? partnerSect;
  final String? partnerDeenLevel;
  final int? partnerEducationMinRank;
  final int? heightCm;
  final String? complexion;
  final String? motherTongue;
  final String? smokingHabit;
  final String? vapingHabit;
  final String? hookahHabit;
  final bool isGuardianProfile;
  final String? community;
  final String? dietType;
  final String? livingExpectation;
  final String? quranMemorization; // 'none','some_surahs','partial','hafiz'
  final String?
      religiousEducation; // 'self_taught','madrasa','islamic_uni','alim_course','none'
  final String?
      marriageTimeline; // 'asap','6_months','1_year','2_plus_years','not_sure'
  final String? willingToRelocate; // 'yes','no','open_to_discussion'
  final String? gender; // 'male','female'
  final bool hasChildren;
  // D3: Last active timestamp
  final DateTime? lastActiveAt;
  final String? countryCode;
  final String? lastName;
  final String? incomeBracket;
  final String? familyOriginCity;
  final String? blurhash;
  final DateTime? previousMatchAt;
  final DateTime? previousMatchEndedAt;
  final int priorMatchCount;
  final DateTime? rematchAvailableAt;
  final String relationshipState;

  bool get isRematchCandidate => previousMatchAt != null && priorMatchCount > 0;

  bool get isInRematchCooldown {
    final availableAt = rematchAvailableAt;
    return availableAt != null && availableAt.isAfter(DateTime.now());
  }

  int? get rematchCooldownDaysRemaining {
    final availableAt = rematchAvailableAt;
    if (availableAt == null) return null;
    final seconds = availableAt.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) return null;
    return (seconds / Duration.secondsPerDay).ceil().clamp(1, 7);
  }

  /// Public profile name supplied by the server. During the rollout the
  /// legacy surname transport field can contain either an initial (older
  /// backend) or the full surname (current backend), so rendering never adds
  /// punctuation that could corrupt a complete name.
  String get displayName => memberDisplayName(firstName, visibleSurname);

  /// The full surname for an active match, otherwise its initial.
  String get visibleSurname => (lastName?.trim().isNotEmpty ?? false)
      ? lastName!.trim()
      : lastNameInitial.trim();

  /// Real Supabase user/profile identifier.
  ///
  /// Production screens must never invent IDs from names. If the backend row is
  /// missing its identity, fail closed instead of allowing actions against a
  /// fake target.
  String get id {
    final value = _id?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('DiscoveryProfile requires a real Supabase id.');
    }
    return value;
  }

  DiscoveryProfile copyWith({
    String? id,
    String? firstName,
    String? lastNameInitial,
    int? age,
    String? cityName,
    String? sect,
    String? deenLevel,
    String? photoUrl,
    List<String>? photoUrls,
    int? photoCount,
    bool? isPhotoPrivate,
    String? photoPrivacy,
    bool? isVerified,
    bool? guardianConnected,
    bool? establishedMember,
    String? occupation,
    String? education,
    String? bio,
    List<String>? languages,
    String? maritalStatus,
    String? familyType,
    List<String>? interests,
    int? partnerAgeMin,
    int? partnerAgeMax,
    String? partnerSect,
    String? partnerDeenLevel,
    int? partnerEducationMinRank,
    int? heightCm,
    String? complexion,
    String? motherTongue,
    String? smokingHabit,
    String? vapingHabit,
    String? hookahHabit,
    bool? isGuardianProfile,
    String? community,
    String? dietType,
    String? livingExpectation,
    String? quranMemorization,
    String? religiousEducation,
    String? marriageTimeline,
    String? willingToRelocate,
    String? gender,
    bool? hasChildren,
    DateTime? lastActiveAt,
    String? countryCode,
    String? lastName,
    String? incomeBracket,
    String? familyOriginCity,
    String? blurhash,
    DateTime? previousMatchAt,
    DateTime? previousMatchEndedAt,
    int? priorMatchCount,
    DateTime? rematchAvailableAt,
    String? relationshipState,
    bool clearPhotoUrl = false,
    bool clearPreviousMatchAt = false,
    bool clearPreviousMatchEndedAt = false,
    bool clearRematchAvailableAt = false,
  }) {
    return DiscoveryProfile(
      id: id ?? _id,
      firstName: firstName ?? this.firstName,
      lastNameInitial: lastNameInitial ?? this.lastNameInitial,
      age: age ?? this.age,
      cityName: cityName ?? this.cityName,
      sect: sect ?? this.sect,
      deenLevel: deenLevel ?? this.deenLevel,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      photoUrls: photoUrls ?? this.photoUrls,
      photoCount: photoCount ?? this.photoCount,
      isPhotoPrivate: isPhotoPrivate ?? this.isPhotoPrivate,
      photoPrivacy: photoPrivacy ?? this.photoPrivacy,
      isVerified: isVerified ?? this.isVerified,
      guardianConnected: guardianConnected ?? this.guardianConnected,
      establishedMember: establishedMember ?? this.establishedMember,
      occupation: occupation ?? this.occupation,
      education: education ?? this.education,
      bio: bio ?? this.bio,
      languages: languages ?? this.languages,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      familyType: familyType ?? this.familyType,
      interests: interests ?? this.interests,
      partnerAgeMin: partnerAgeMin ?? this.partnerAgeMin,
      partnerAgeMax: partnerAgeMax ?? this.partnerAgeMax,
      partnerSect: partnerSect ?? this.partnerSect,
      partnerDeenLevel: partnerDeenLevel ?? this.partnerDeenLevel,
      partnerEducationMinRank:
          partnerEducationMinRank ?? this.partnerEducationMinRank,
      heightCm: heightCm ?? this.heightCm,
      complexion: complexion ?? this.complexion,
      motherTongue: motherTongue ?? this.motherTongue,
      smokingHabit: smokingHabit ?? this.smokingHabit,
      vapingHabit: vapingHabit ?? this.vapingHabit,
      hookahHabit: hookahHabit ?? this.hookahHabit,
      isGuardianProfile: isGuardianProfile ?? this.isGuardianProfile,
      community: community ?? this.community,
      dietType: dietType ?? this.dietType,
      livingExpectation: livingExpectation ?? this.livingExpectation,
      quranMemorization: quranMemorization ?? this.quranMemorization,
      religiousEducation: religiousEducation ?? this.religiousEducation,
      marriageTimeline: marriageTimeline ?? this.marriageTimeline,
      willingToRelocate: willingToRelocate ?? this.willingToRelocate,
      gender: gender ?? this.gender,
      hasChildren: hasChildren ?? this.hasChildren,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      countryCode: countryCode ?? this.countryCode,
      lastName: lastName ?? this.lastName,
      incomeBracket: incomeBracket ?? this.incomeBracket,
      familyOriginCity: familyOriginCity ?? this.familyOriginCity,
      blurhash: blurhash ?? this.blurhash,
      previousMatchAt: clearPreviousMatchAt
          ? null
          : (previousMatchAt ?? this.previousMatchAt),
      previousMatchEndedAt: clearPreviousMatchEndedAt
          ? null
          : (previousMatchEndedAt ?? this.previousMatchEndedAt),
      priorMatchCount: priorMatchCount ?? this.priorMatchCount,
      rematchAvailableAt: clearRematchAvailableAt
          ? null
          : (rematchAvailableAt ?? this.rematchAvailableAt),
      relationshipState: relationshipState ?? this.relationshipState,
    );
  }

  /// Human-readable last-active label
  String get lastActiveLabel {
    final t = lastActiveAt;
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 5) return 'Online now';
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
    return 'Active ${diff.inDays ~/ 7}w ago';
  }
}
