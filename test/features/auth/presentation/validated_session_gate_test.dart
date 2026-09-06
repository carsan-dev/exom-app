import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/validated_session_gate.dart';

void main() {
  test(
    'services pause after rejection/loading and require validation of a replacement session',
    () {
      LocalAuthSession? session = const LocalAuthSession(uid: 'A');
      final gate = ValidatedSessionGate(() => session);
      const valid = AuthAuthenticated(
        UserEntity(id: 'db-A', email: 'a@example.test', role: 'CLIENT'),
      );
      expect(gate.isAuthenticated, false);
      gate.handle(valid);
      expect(gate.isAuthenticated, true);
      for (final state in [
        const AuthLoading(),
        const AuthError('503'),
        const AuthAccountLocked(),
        const AuthUnauthenticated(),
      ]) {
        gate.handle(state);
        expect(gate.isAuthenticated, false);
        gate.handle(valid);
      }
      session = const LocalAuthSession(uid: 'B');
      expect(gate.isAuthenticated, false);
      session = const LocalAuthSession(uid: 'A', generation: 1);
      expect(gate.isAuthenticated, false);
      gate.handle(valid);
      expect(gate.isAuthenticated, true);
      session = null;
      expect(gate.isAuthenticated, false);
    },
  );
}
