import 'dart:io';
import 'dart:typed_data';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/features/auth/data/models/auth_response_model.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:hive/hive.dart';

/// Opens an in-memory `settings_box` (the box that holds the onboarding
/// marks) so widget tests never touch the real Hive files.
Future<Directory> openInMemorySettingsBox() async {
  final directory = await Directory.systemTemp.createTemp('exom-onboarding-');
  Hive.init(directory.path);
  await Hive.openBox('settings_box', bytes: Uint8List(0));
  return directory;
}

Future<void> closeSettingsBox(Directory directory) async {
  await Hive.close();
  if (directory.existsSync()) {
    await directory.delete(recursive: true);
  }
}

Box<dynamic> get settingsBox => Hive.box('settings_box');

/// Builds the entity exactly as `/auth/me`, login and social do: through
/// `UserModel.fromJson(...).toEntity()`.
UserEntity userFromServer({
  String id = 'db-A',
  String email = 'a@exom.test',
  String role = 'CLIENT',
  Map<String, Object?>? profile,
}) {
  return UserModel.fromJson({
    'id': id,
    'email': email,
    'role': role,
    'profile': profile,
  }).toEntity();
}

const doneProfile = <String, Object?>{
  'first_name': 'Ana',
  'last_name': 'A',
  'avatar_url': null,
  'onboarding_completed_at': '2026-11-01T10:00:00.000Z',
  'onboarding_outcome': 'COMPLETED',
};

const pendingProfile = <String, Object?>{
  'first_name': 'Ana',
  'last_name': 'A',
  'avatar_url': null,
  'onboarding_completed_at': null,
  'onboarding_outcome': null,
};

/// Profile served by an API that predates the onboarding columns.
const legacyProfile = <String, Object?>{
  'first_name': 'Ana',
  'last_name': 'A',
  'avatar_url': null,
};

class SessionFirebaseAuthService extends FirebaseAuthService {
  SessionFirebaseAuthService(this.session);

  LocalAuthSession? session;
  int signOutCalls = 0;

  @override
  LocalAuthSession? get currentSession => session;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      session == null ? null : 'token-${session!.uid}';

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class ScriptedAuthRepository implements AuthRepository {
  ScriptedAuthRepository(this.getMeResult);

  /// Either a [UserEntity] or an error thrown by `/auth/me`.
  Object getMeResult;

  @override
  Future<UserEntity> getMe() async {
    final result = getMeResult;
    if (result is UserEntity) return result;
    throw result;
  }

  @override
  Future<UserEntity> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<UserEntity> socialLogin(String token, String provider) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  UserEntity? getCurrentUser() => null;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> forgotPassword(String email) async {}
}
