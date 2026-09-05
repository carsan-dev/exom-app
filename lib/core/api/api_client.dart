import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({
    String? baseUrl,
    bool useAuth = true,
    AuthTokenProvider? authTokenProvider,
  }) {
    if (useAuth && authTokenProvider == null) {
      throw ArgumentError.notNull('authTokenProvider');
    }

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

    if (useAuth) {
      _dio.interceptors.add(_AuthInterceptor(_dio, authTokenProvider!));
    }
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
  static const _retryKey = 'exom.auth.retry';
  static const _refreshExcludedPaths = {
    '/auth/login',
    '/auth/social',
    '/auth/forgot-password',
  };

  final Dio _dio;
  final AuthTokenProvider _authTokenProvider;
  Future<String?>? _refreshInFlight;
  String? _tokenBeforeLastRefresh;
  String? _lastRefreshedToken;
  bool _hasCompletedRefresh = false;

  _AuthInterceptor(this._dio, this._authTokenProvider);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_retryKey] == true &&
        options.headers.containsKey('Authorization')) {
      handler.next(options);
      return;
    }

    if (_authTokenProvider.currentSession != null) {
      try {
        final token = await _authTokenProvider.getIdToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } on AuthTokenNetworkException catch (error) {
        handler.reject(
          DioException.connectionError(
            requestOptions: options,
            reason: 'Firebase token refresh failed due to connectivity',
            error: error,
          ),
        );
        return;
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        options.extra[_retryKey] == true ||
        _refreshExcludedPaths.any(options.uri.path.endsWith) ||
        _authTokenProvider.currentSession == null) {
      handler.next(err);
      return;
    }

    try {
      final failedAuthorization = options.headers['Authorization']?.toString();
      final token = await _refreshToken(failedAuthorization);
      if (token == null || token.isEmpty) {
        handler.next(err);
        return;
      }

      final retryOptions = options.copyWith(
        headers: {...options.headers, 'Authorization': 'Bearer $token'},
        extra: {...options.extra, _retryKey: true},
      );
      final response = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on AuthTokenNetworkException catch (refreshError) {
      handler.next(
        DioException.connectionError(
          requestOptions: options,
          reason: 'Firebase token refresh failed due to connectivity',
          error: refreshError,
        ),
      );
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<String?> _refreshToken(String? failedAuthorization) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    if (_hasCompletedRefresh &&
        failedAuthorization == _tokenBeforeLastRefresh) {
      return Future<String?>.value(_lastRefreshedToken);
    }

    _tokenBeforeLastRefresh = failedAuthorization;
    final refresh = _authTokenProvider.getIdToken(forceRefresh: true);
    _refreshInFlight = refresh;
    return refresh
        .then((token) {
          if (token != null && token.isNotEmpty) {
            _lastRefreshedToken = token;
            _hasCompletedRefresh = true;
          }
          return token;
        })
        .whenComplete(() {
          if (identical(_refreshInFlight, refresh)) {
            _refreshInFlight = null;
          }
        });
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
        e.type == DioExceptionType.connectionError;
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
