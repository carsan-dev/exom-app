import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/feedback/presentation/feedback_notice_snack_bars.dart';

/// Ties the app-wide feedback notices to the session that shows them.
///
/// A notice with an action (the failed upload one, «Reintentar») persists
/// until it is dismissed, and the messenger outlives the routes. Leaving the
/// validated session (logout, rejected session, another account) closes the
/// notices; while there is no validated session, or the signed-in session is
/// not the one validated, no notice is shown; and a retry bound to a session
/// does nothing under another one. The queue itself is not touched: failed
/// uploads stay in their owner's namespace and in «Subidas pendientes».
class FeedbackNoticeSession {
  FeedbackNoticeSession({
    required String? Function() sessionKey,
    void Function()? closeNotices,
  }) : _sessionKey = sessionKey,
       _closeNotices = closeNotices ?? FeedbackNoticeSnackBars.closeAll;

  final String? Function() _sessionKey;
  final void Function() _closeNotices;

  /// The validated session whose notices may be on screen.
  String? _owner;

  /// Call with every [AuthState].
  void handle(AuthState state) {
    final owner = state is AuthAuthenticated ? _sessionKey() : null;
    if (owner == _owner) return;
    _owner = owner;
    _closeNotices();
  }

  bool _isCurrent(String? owner) =>
      owner != null && owner == _owner && owner == _sessionKey();

  /// Whether a notice may be shown now.
  bool get acceptsNotices => _isCurrent(_owner);

  /// [retry] bound to the session that is showing the notice: under any
  /// other session (or none) it does nothing.
  Future<void> Function(String id) guardRetry(
    Future<void> Function(String id) retry,
  ) {
    final owner = _owner;
    return (id) async {
      if (!_isCurrent(owner)) return;
      await retry(id);
    };
  }
}
