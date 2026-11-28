import 'package:exom_app/features/notifications/presentation/bloc/notifications_bloc.dart';

/// One [NotificationsBloc] per signed-in session, shared by every reader of
/// that session (shell bell and notifications page).
///
/// A new session (another account, or the same one after signing in again)
/// gets a new bloc, so its first frame never shows the previous session's
/// count or items, and answers still in flight for the previous session land
/// in the previous bloc, which no reader of the new session holds. The
/// previous bloc is not closed: a widget of the previous session may still
/// hold it until it unmounts, and adding an event to a closed bloc throws.
class NotificationsBlocSessionScope {
  NotificationsBlocSessionScope({
    required NotificationsBloc Function() create,
    required String? Function() sessionKey,
  }) : _create = create,
       _sessionKey = sessionKey;

  final NotificationsBloc Function() _create;
  final String? Function() _sessionKey;
  NotificationsBloc? _bloc;
  String? _owner;

  /// The bloc of the current session.
  NotificationsBloc get current {
    final owner = _sessionKey();
    final bloc = _bloc;
    if (bloc != null && !bloc.isClosed && owner == _owner) return bloc;
    _owner = owner;
    return _bloc = _create();
  }
}
