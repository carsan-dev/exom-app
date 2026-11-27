import 'package:exom_app/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// OP-CMP-01 guard: the parsing of the base app must accept the new profile
/// keys and keep every other field identical. It passes on the base commit and
/// must keep passing.
void main() {
  Map<String, dynamic> me(Map<String, dynamic> extraProfile) => {
    'id': 'db-A',
    'email': 'a@exom.test',
    'role': 'CLIENT',
    'profile': {
      'first_name': 'Ana',
      'last_name': 'A',
      'avatar_url': 'https://cdn.exom.test/a.png',
      ...extraProfile,
    },
  };

  for (final value in [
    {
      'onboarding_completed_at': '2026-11-01T10:00:00.000Z',
      'onboarding_outcome': 'COMPLETED',
    },
    {
      'onboarding_completed_at': '2026-11-01T10:00:00.000Z',
      'onboarding_outcome': null,
    },
    {'onboarding_completed_at': null, 'onboarding_outcome': null},
  ]) {
    test('OP-CMP-01 /auth/me with onboarding keys $value parses unchanged', () {
      final legacy = UserModel.fromJson(me(const {})).toEntity();
      final current = UserModel.fromJson(me(value)).toEntity();

      expect(current.id, legacy.id);
      expect(current.email, legacy.email);
      expect(current.role, legacy.role);
      expect(current.firstName, legacy.firstName);
      expect(current.lastName, legacy.lastName);
      expect(current.avatarUrl, legacy.avatarUrl);
      expect(current.isClient, isTrue);
    });
  }

  test('OP-CMP-01 login/social response with onboarding keys parses', () {
    final response = AuthResponseModel.fromJson({
      'access_token': 'custom-token',
      'user': me({
        'onboarding_completed_at': '2026-11-01T10:00:00.000Z',
        'onboarding_outcome': 'SKIPPED',
      }),
    });

    expect(response.accessToken, 'custom-token');
    expect(response.user.toEntity().email, 'a@exom.test');
  });
}
