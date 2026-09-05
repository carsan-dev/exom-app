import 'dart:async';

import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';

class ValidatedSessionServiceStarter {
  ValidatedSessionServiceStarter(this._initializers);

  final List<Future<void> Function()> _initializers;
  bool _started = false;

  void handle(AuthState state) {
    if (_started || state is! AuthAuthenticated) return;

    _started = true;
    for (final initializer in _initializers) {
      unawaited(Future<void>.sync(initializer));
    }
  }
}
