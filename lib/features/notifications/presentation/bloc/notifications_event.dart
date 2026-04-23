part of 'notifications_bloc.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => const [];
}

class NotificationsRequested extends NotificationsEvent {
  const NotificationsRequested();
}

class NotificationsLoadMoreRequested extends NotificationsEvent {
  const NotificationsLoadMoreRequested();
}

class NotificationsMarkReadRequested extends NotificationsEvent {
  final String id;
  const NotificationsMarkReadRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class NotificationsMarkAllReadRequested extends NotificationsEvent {
  const NotificationsMarkAllReadRequested();
}

class NotificationsDeleteReadRequested extends NotificationsEvent {
  const NotificationsDeleteReadRequested();
}

class NotificationsUnreadCountRefreshRequested extends NotificationsEvent {
  const NotificationsUnreadCountRefreshRequested();
}
