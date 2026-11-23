import 'package:exom_app/features/auth/data/models/auth_response_model.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UserEntity parse(Object? profile, {bool includeProfile = true}) {
    return UserModel.fromJson({
      'id': 'db-A',
      'email': 'a@exom.test',
      'role': 'CLIENT',
      if (includeProfile) 'profile': profile,
    }).toEntity();
  }

  group('OP-RED-04 / OP-APP-01 tri-state onboarding status', () {
    test('a date means done', () {
      final user = parse({
        'first_name': 'Ana',
        'onboarding_completed_at': '2026-11-01T10:00:00.000Z',
        'onboarding_outcome': null,
      });
      expect(user.onboardingStatus, OnboardingServerStatus.done);
      expect(user.isServerValidated, isTrue);
    });

    test('an explicit null means pending', () {
      final user = parse({
        'first_name': 'Ana',
        'onboarding_completed_at': null,
        'onboarding_outcome': null,
      });
      expect(user.onboardingStatus, OnboardingServerStatus.pending);
    });

    test('a missing key (old API) means unknown', () {
      expect(
        parse({'first_name': 'Ana'}).onboardingStatus,
        OnboardingServerStatus.unknown,
      );
    });

    test('profile null or absent means unknown', () {
      expect(parse(null).onboardingStatus, OnboardingServerStatus.unknown);
      expect(
        parse(null, includeProfile: false).onboardingStatus,
        OnboardingServerStatus.unknown,
      );
    });

    test('a malformed value never means pending', () {
      for (final value in ['not-a-date', 42, true]) {
        expect(
          parse({'onboarding_completed_at': value}).onboardingStatus,
          OnboardingServerStatus.unknown,
        );
      }
    });

    test('status and validation take part in equality', () {
      final done = parse({'onboarding_completed_at': '2026-11-01T10:00:00Z'});
      final pending = parse({'onboarding_completed_at': null});
      expect(done == pending, isFalse);
    });

    test('a hand-built entity defaults to unknown and not validated', () {
      const user = UserEntity(id: 'uid', email: 'a@exom.test', role: 'CLIENT');
      expect(user.onboardingStatus, OnboardingServerStatus.unknown);
      expect(user.isServerValidated, isFalse);
    });
  });
}
