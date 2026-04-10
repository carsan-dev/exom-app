import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? 'http://10.0.2.2:3000/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(_AuthInterceptor());
    _dio.interceptors.add(_LoggingInterceptor());
  }

  Dio get dio => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
    );
    final data = response.data?['data'];
    if (fromJson != null && data is Map<String, dynamic>) {
      return fromJson(data);
    }
    return data as T;
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: data);
    final responseData = response.data?['data'];
    if (fromJson != null && responseData is Map<String, dynamic>) {
      return fromJson(responseData);
    }
    return responseData as T;
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(path, data: data);
    final responseData = response.data?['data'];
    if (fromJson != null && responseData is Map<String, dynamic>) {
      return fromJson(responseData);
    }
    return responseData as T;
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(path, data: data);
    final responseData = response.data?['data'];
    if (fromJson != null && responseData is Map<String, dynamic>) {
      return fromJson(responseData);
    }
    return responseData as T;
  }

  Future<void> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    await _dio.delete(path, queryParameters: queryParameters);
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Token might be expired, try to refresh
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken(true); // force refresh
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $token';
          final response = await Dio().fetch(opts);
          return handler.resolve(response);
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[API] ${options.method} ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[API] Error: ${err.response?.statusCode} - ${err.message}');
    }
    handler.next(err);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  static ApiException? maybeFrom(Object error) {
    if (error is ApiException) {
      return error;
    }
    if (error is DioException) {
      return ApiException.fromDioError(error);
    }
    return null;
  }

  factory ApiException.fromDioError(DioException e) {
    final isNetwork =
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.response == null;
    final statusCode = isNetwork ? 0 : (e.response?.statusCode ?? 500);
    final data = e.response?.data;
    String? message;

    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String && msg.trim().isNotEmpty) {
        message = msg.trim();
      }
      if (msg is List) {
        final joined = msg
            .whereType<Object>()
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .join(', ');
        if (joined.isNotEmpty) {
          message = joined;
        }
      }
    }

    message ??= e.message?.trim();
    message ??= e.response?.statusMessage?.trim();
    message ??= e.error?.toString().trim();
    message ??= 'Request failed';

    return ApiException(statusCode: statusCode, message: message);
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isLocked => statusCode == 423;
  bool get isNotFound => statusCode == 404;
  bool get isNetworkError => statusCode == 0;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
