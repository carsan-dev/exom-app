import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';

/// Ties the native rest timer, which has no owner of its own, to the
/// validated session (DESCANSO-AVISO): a rest must not ring «Descanso
/// terminado» once no valid owner is left (logout, deletion, account switch)
/// or when the process starts without one (signed out, account locked).
///
/// While the process has not resolved its session yet ([AuthInitial] and the
/// [AuthLoading] of the first check) nothing is cancelled, so a cold start
/// never stops a rest that still belongs to the signed-in user.
class RestTimerSessionGuard {
  RestTimerSessionGuard(this._restTimer);

  final RestTimerCoordinator Function() _restTimer;
  bool _resolved = false;
  String? _owner;

  /// [owner] is the validated session stamp after [state], or null.
  void handle(AuthState state, String? owner) {
    if (!_resolved) {
      if (state is AuthAuthenticated) {
        _resolved = true;
        _owner = owner;
      } else if (state is AuthUnauthenticated ||
          state is AuthAccountLocked ||
          state is AuthAccountDeleted) {
        _resolved = true;
        _owner = null;
        _cancel();
      }
      // AuthInitial, AuthLoading, AuthError, AuthLinkPasswordRequired: the
      // first check has not said who owns the session yet.
      return;
    }
    final previous = _owner;
    _owner = owner;
    if (previous != null && previous != owner) _cancel();
  }

  void _cancel() {
    // Native cancellation failures must never surface as uncaught errors.
    _restTimer().cancel().catchError((Object _) {});
  }
}
