import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  const UserEntity({
    required this.id,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  bool get isAdmin => role == 'ADMIN' || role == 'SUPER_ADMIN';
  bool get isClient => role == 'CLIENT';

  String get displayName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    return email;
  }

  @override
  List<Object?> get props => [id, email, role, firstName, lastName, avatarUrl];
}
