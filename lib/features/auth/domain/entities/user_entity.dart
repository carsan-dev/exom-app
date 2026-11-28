import 'package:equatable/equatable.dart';

/// Onboarding state as reported by the server in `profile`.
///
/// * [done]: `onboarding_completed_at` holds a date.
/// * [pending]: the key is present and `null`.
/// * [unknown]: the key or the profile is missing (API without the column),
///   the value is malformed, or the entity was not built from a server
///   response (offline session).
enum OnboardingServerStatus { done, pending, unknown }

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final OnboardingServerStatus onboardingStatus;

  /// `true` only when the entity comes from a backend response (`/auth/me`,
  /// login or social); the offline entity built from the Firebase session is
  /// not validated by the server.
  final bool isServerValidated;

  const UserEntity({
    required this.id,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.onboardingStatus = OnboardingServerStatus.unknown,
    this.isServerValidated = false,
  });

  bool get isAdmin => role == 'ADMIN' || role == 'SUPER_ADMIN';
  bool get isClient => role == 'CLIENT';

  String get displayName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    return email;
  }

  @override
  List<Object?> get props => [
    id,
    email,
    role,
    firstName,
    lastName,
    avatarUrl,
    onboardingStatus,
    isServerValidated,
  ];
}
