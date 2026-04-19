part of 'notifications_bloc.dart';

abstract class NotificationsState extends Equatable {
  const NotificationsState();

  int get unreadCount => 0;

  @override
  List<Object?> get props => const [];
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  final List<NotificationEntity> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  @override
  final int unreadCount;

  const NotificationsLoaded({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.unreadCount,
    this.loadingMore = false,
  });

  NotificationsLoaded copyWith({
    List<NotificationEntity>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    int? unreadCount,
  }) {
    return NotificationsLoaded(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [items, page, hasMore, loadingMore, unreadCount];
}

class NotificationsUnreadOnly extends NotificationsState {
  @override
  final int unreadCount;
  const NotificationsUnreadOnly({required this.unreadCount});

  @override
  List<Object?> get props => [unreadCount];
}

class NotificationsError extends NotificationsState {
  final String message;
  const NotificationsError({required this.message});

  @override
  List<Object?> get props => [message];
}
