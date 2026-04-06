import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String role;
  final String tier;
  final DateTime? trialExpiresAt;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  const UserEntity({
    required this.id,
    required this.email,
    required this.role,
    this.tier = 'HIGH_TICKET',
    this.trialExpiresAt,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  bool get isAdmin => role == 'ADMIN' || role == 'SUPER_ADMIN';
  bool get isClient => role == 'CLIENT';

  bool get isHighTicket => tier == 'HIGH_TICKET';
  bool get isLowTicket => tier == 'LOW_TICKET';
  bool get isTrial => trialExpiresAt != null;
  bool get isTrialExpired =>
      trialExpiresAt != null && DateTime.now().isAfter(trialExpiresAt!);
  int get trialDaysRemaining => trialExpiresAt != null
      ? trialExpiresAt!.difference(DateTime.now()).inDays.clamp(0, 999)
      : 0;

  String get displayName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    return email;
  }

  @override
  List<Object?> get props =>
      [id, email, role, tier, trialExpiresAt, firstName, lastName, avatarUrl];
}
