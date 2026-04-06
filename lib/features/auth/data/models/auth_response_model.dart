import '../../domain/entities/user_entity.dart';

class ProfileModel {
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  const ProfileModel({this.firstName, this.lastName, this.avatarUrl});

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'avatar_url': avatarUrl,
  };
}

class UserModel {
  final String id;
  final String email;
  final String role;
  final String tier;
  final DateTime? trialExpiresAt;
  final ProfileModel? profile;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.tier,
    this.trialExpiresAt,
    this.profile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      tier: json['tier'] as String? ?? 'HIGH_TICKET',
      trialExpiresAt: json['trial_expires_at'] != null
          ? DateTime.parse(json['trial_expires_at'] as String)
          : null,
      profile: json['profile'] != null
          ? ProfileModel.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'role': role,
    'tier': tier,
    'trial_expires_at': trialExpiresAt?.toIso8601String(),
    'profile': profile?.toJson(),
  };

  UserEntity toEntity() => UserEntity(
    id: id,
    email: email,
    role: role,
    tier: tier,
    trialExpiresAt: trialExpiresAt,
    firstName: profile?.firstName,
    lastName: profile?.lastName,
    avatarUrl: profile?.avatarUrl,
  );
}

class AuthResponseModel {
  final String accessToken;
  final UserModel user;

  const AuthResponseModel({required this.accessToken, required this.user});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['access_token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'user': user.toJson(),
  };
}
