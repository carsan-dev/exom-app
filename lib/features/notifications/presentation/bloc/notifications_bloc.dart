import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:exom_app/features/notifications/domain/usecases/delete_read_notifications_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/get_my_notifications_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/get_unread_count_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/mark_all_notifications_as_read_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/mark_notification_as_read_usecase.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final GetMyNotificationsUseCase _getMyNotifications;
  final GetUnreadCountUseCase _getUnreadCount;
  final MarkNotificationAsReadUseCase _markAsRead;
  final MarkAllNotificationsAsReadUseCase _markAllAsRead;
  final DeleteReadNotificationsUseCase _deleteRead;
  final Set<String> _pendingReadIds = <String>{};

  static const int _pageSize = 20;

  NotificationsBloc({
    required GetMyNotificationsUseCase getMyNotifications,
    required GetUnreadCountUseCase getUnreadCount,
    required MarkNotificationAsReadUseCase markAsRead,
    required MarkAllNotificationsAsReadUseCase markAllAsRead,
    required DeleteReadNotificationsUseCase deleteRead,
  })  : _getMyNotifications = getMyNotifications,
        _getUnreadCount = getUnreadCount,
        _markAsRead = markAsRead,
        _markAllAsRead = markAllAsRead,
        _deleteRead = deleteRead,
        super(const NotificationsInitial()) {
    on<NotificationsRequested>(_onRequested);
    on<NotificationsLoadMoreRequested>(_onLoadMore);
    on<NotificationsMarkReadRequested>(_onMarkRead);
    on<NotificationsMarkAllReadRequested>(_onMarkAllRead);
    on<NotificationsDeleteReadRequested>(_onDeleteRead);
    on<NotificationsUnreadCountRefreshRequested>(_onUnreadCountRefresh);
  }

  Future<NotificationsLoaded> _loadFirstPage() async {
    final page = await _getMyNotifications(limit: _pageSize);
    final unread = await _getUnreadCount();
    return NotificationsLoaded(
      items: _applyPendingReads(page.items),
      page: page.page,
      hasMore: page.hasMore,
      unreadCount: _applyPendingUnreadCount(unread),
    );
  }

  List<NotificationEntity> _applyPendingReads(List<NotificationEntity> items) {
    if (_pendingReadIds.isEmpty) return items;

    final now = DateTime.now();
    return items
        .map(
          (notification) => _pendingReadIds.contains(notification.id) &&
                  notification.isUnread
              ? notification.copyWith(readAt: now)
              : notification,
        )
        .toList();
  }

  int _applyPendingUnreadCount(int unreadCount) {
    final adjusted = unreadCount - _pendingReadIds.length;
    return adjusted < 0 ? 0 : adjusted;
  }

  Future<void> _onRequested(
    NotificationsRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(const NotificationsLoading());
    try {
      emit(await _loadFirstPage());
    } catch (error) {
      emit(
        NotificationsError(
          message: ApiException.maybeFrom(error)?.message ?? error.toString(),
        ),
      );
    }
  }

  Future<void> _onLoadMore(
    NotificationsLoadMoreRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    if (current is! NotificationsLoaded || !current.hasMore || current.loadingMore) {
      return;
    }

    emit(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final page = await _getMyNotifications(page: nextPage, limit: _pageSize);
      emit(
        current.copyWith(
          items: [...current.items, ..._applyPendingReads(page.items)],
          page: page.page,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } catch (_) {
      emit(current.copyWith(loadingMore: false));
    }
  }

  Future<void> _onMarkRead(
    NotificationsMarkReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    final target = current.items.firstWhere(
      (n) => n.id == event.id,
      orElse: () => _nullNotification,
    );
    if (target.id.isEmpty || !target.isUnread) return;

    // Optimistic
    _pendingReadIds.add(event.id);
    final updated = current.items
        .map((n) => n.id == event.id ? n.copyWith(readAt: DateTime.now()) : n)
        .toList();
    emit(
      current.copyWith(
        items: updated,
        unreadCount: current.unreadCount > 0 ? current.unreadCount - 1 : 0,
      ),
    );

    try {
      await _markAsRead(event.id);
      _pendingReadIds.remove(event.id);
      debugPrint('[Notifications] markAsRead OK id=${event.id}');
    } catch (error, stack) {
      _pendingReadIds.remove(event.id);
      debugPrint('[Notifications] markAsRead FAILED id=${event.id} error=$error');
      debugPrintStack(stackTrace: stack, label: 'markAsRead');
      // Revert on failure
      emit(current);
    }
  }

  Future<void> _onMarkAllRead(
    NotificationsMarkAllReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    if (current is! NotificationsLoaded || current.unreadCount == 0) return;

    final idsToMark = current.items
        .where((notification) => notification.isUnread)
        .map((notification) => notification.id)
        .toSet();
    _pendingReadIds.addAll(idsToMark);
    final now = DateTime.now();
    final updated = current.items
        .map((n) => n.isUnread ? n.copyWith(readAt: now) : n)
        .toList();
    emit(current.copyWith(items: updated, unreadCount: 0));

    try {
      await _markAllAsRead();
      _pendingReadIds.removeAll(idsToMark);
    } catch (_) {
      _pendingReadIds.removeAll(idsToMark);
      emit(current);
    }
  }

  Future<void> _onUnreadCountRefresh(
    NotificationsUnreadCountRefreshRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    try {
      final unread = _applyPendingUnreadCount(await _getUnreadCount());
      if (current is NotificationsLoaded) {
        emit(
          current.copyWith(
            items: _applyPendingReads(current.items),
            unreadCount: unread,
          ),
        );
      } else {
        emit(NotificationsUnreadOnly(unreadCount: unread));
      }
    } catch (_) {
      // silent
    }
  }

  Future<void> _onDeleteRead(
    NotificationsDeleteReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    if (current is! NotificationsLoaded ||
        current.deletingRead ||
        !current.items.any((notification) => !notification.isUnread)) {
      return;
    }

    emit(current.copyWith(deletingRead: true));

    try {
      await _deleteRead();
      emit(await _loadFirstPage());
    } catch (_) {
      emit(current);
    }
  }

  static final NotificationEntity _nullNotification = NotificationEntity(
    id: '',
    title: '',
    body: '',
    status: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
