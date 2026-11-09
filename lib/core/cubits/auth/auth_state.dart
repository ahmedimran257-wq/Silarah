// SILARAH — Auth Cubit States
// Auth state for Supabase email OTP.
import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// App just launched — checking stored session.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Any async auth operation in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// OTP has been sent.
class AuthOtpSent extends AuthState {
  const AuthOtpSent({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Successfully authenticated. Holds userId for routing decisions.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.userId,
    required this.onboardingStep,
    this.gender,
    this.email,
    this.countryCode,
    this.isGuardianPath = false,
    this.onboardingCompleted = false,
    this.accountRole = 'member',
    this.guardianInvitationPending = false,
  });

  final String userId;

  /// Fast-start onboarding uses steps 0-4. Completion is tracked by
  /// [onboardingCompleted], not inferred from this number.
  final int onboardingStep;

  /// 'male' | 'female' | null (unknown until onboarding sets it)
  final String? gender;

  /// Supabase email OTP auth identifier.
  final String? email;

  /// Country code for regional pricing (e.g., 'IN', 'US', 'AE')
  final String? countryCode;

  /// Whether the user is on the guardian onboarding path.
  /// Guardian and self paths now share the same five-step fast-start flow.
  final bool isGuardianPath;

  /// Persisted server-side. Do not infer completion from a numeric step.
  final bool onboardingCompleted;

  /// `guardian` accounts exist only to oversee an invited ward. Existing
  /// matrimony members who also accept an invitation use `member_guardian`.
  final String accountRole;

  /// A locally-held one-time code must resume before ordinary onboarding.
  final bool guardianInvitationPending;

  /// Completion is persisted server-side.
  bool get isOnboardingComplete => onboardingCompleted;
  bool get isGuardianOnly => accountRole == 'guardian';
  bool get hasGuardianAccess =>
      accountRole == 'guardian' || accountRole == 'member_guardian';

  @override
  List<Object?> get props => [
        userId,
        onboardingStep,
        gender,
        email,
        countryCode,
        isGuardianPath,
        onboardingCompleted,
        accountRole,
        guardianInvitationPending,
      ];
}

/// Session check found no active session.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.notice});

  /// Why the session ended, when the member has to be told.
  final String? notice;

  @override
  List<Object?> get props => [notice];
}

enum AuthErrorKind { general, invalidEmail, legalConsentRequired }

/// Any auth error (invalid OTP, network, etc.)
class AuthError extends AuthState {
  const AuthError({required this.message, this.kind = AuthErrorKind.general});

  final String message;
  final AuthErrorKind kind;

  @override
  List<Object?> get props => [message, kind];
}
