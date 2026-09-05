import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/validated_session_service_starter.dart';

void main() {
  test('starts background services only after a validated session', () async {
    var firstStarts = 0;
    var secondStarts = 0;
    final starter = ValidatedSessionServiceStarter([
      () async => firstStarts++,
      () async => secondStarts++,
    ]);

    starter.handle(const AuthInitial());
    starter.handle(const AuthError('temporary backend failure'));
    starter.handle(const AuthAccountLocked());
    starter.handle(const AuthUnauthenticated());
    await Future<void>.delayed(Duration.zero);

    expect(firstStarts, 0);
    expect(secondStarts, 0);

    const authenticated = AuthAuthenticated(
      UserEntity(id: 'user-1', email: 'client@exom.dev', role: 'CLIENT'),
    );
    starter.handle(authenticated);
    starter.handle(authenticated);
    await Future<void>.delayed(Duration.zero);

    expect(firstStarts, 1);
    expect(secondStarts, 1);
  });
}
