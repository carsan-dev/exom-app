import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';

/// Runtime authorization for services; durable queue ownership is separate.
class ValidatedSessionGate {
  ValidatedSessionGate(this._currentSession);
  final LocalAuthSession? Function() _currentSession;
  LocalAuthSession? _validated;

  void handle(AuthState state) {
    _validated = state is AuthAuthenticated ? _currentSession() : null;
  }

  bool get isAuthenticated {
    final current = _currentSession();
    return _validated != null &&
        current != null &&
        current.uid == _validated!.uid &&
        current.generation == _validated!.generation;
  }
}
