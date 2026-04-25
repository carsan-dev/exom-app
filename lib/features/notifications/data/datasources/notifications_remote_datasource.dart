import 'package:flutter/foundation.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/notifications/data/models/notification_model.dart';
import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';

abstract class NotificationsRemoteDataSource {
  Future<NotificationsPageEntity> getMyNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  });
  Future<int> getUnreadCount();
  Future<void> markAsRead(String id);
  Future<int> markAllAsRead();
  Future<int> deleteRead();
}

class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  final ApiClient _apiClient;

  const NotificationsRemoteDataSourceImpl(this._apiClient);

  @override
  Future<NotificationsPageEntity> getMyNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/notifications/me',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (unreadOnly) 'unread_only': true,
      },
    );
    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        final items = data['data'];
        final list = (items is List)
            ? items
                  .whereType<Map>()
                  .map(
                    (e) => NotificationModel.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList()
            : <NotificationModel>[];
        return NotificationsPageEntity(
          items: list,
          total: (data['total'] as num?)?.toInt() ?? list.length,
          page: (data['page'] as num?)?.toInt() ?? page,
          limit: (data['limit'] as num?)?.toInt() ?? limit,
          totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
        );
      }
    }
    return NotificationsPageEntity(
      items: const [],
      total: 0,
      page: page,
      limit: limit,
      totalPages: 0,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _apiClient.dio.get<dynamic>(
      '/notifications/me/unread-count',
    );
    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return (data['count'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  @override
  Future<void> markAsRead(String id) async {
    final response = await _apiClient.dio.put<dynamic>(
      '/notifications/$id/read',
    );
    debugPrint(
      '[Notifications] PUT /notifications/$id/read -> ${response.statusCode}',
    );
  }

  @override
  Future<int> markAllAsRead() async {
    final response = await _apiClient.dio.put<dynamic>(
      '/notifications/me/read-all',
    );
    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return (data['updated'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  @override
  Future<int> deleteRead() async {
    final response = await _apiClient.dio.delete<dynamic>(
      '/notifications/me/read',
    );
    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return (data['deleted'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }
}
