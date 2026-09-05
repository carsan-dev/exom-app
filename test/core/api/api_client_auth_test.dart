import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';

void main() {
  test('only concrete connectivity failures are classified as offline', () {
    final request = RequestOptions(path: '/auth/me');

    expect(
      ApiException.fromDioError(
        DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        ),
      ).statusCode,
      0,
    );
    expect(
      ApiException.fromDioError(
        DioException(requestOptions: request, type: DioExceptionType.unknown),
      ).statusCode,
      500,
    );
  });

  test('multiple simultaneous 401 responses share one token refresh', () async {
    late _AuthAdapter adapter;
    final provider = _FakeTokenProvider(() async {
      await adapter.allInitialRequests.future;
      return 'fresh-token';
    });
    final client = ApiClient(
      baseUrl: 'https://api.exom.test',
      authTokenProvider: provider,
    );
    adapter = _AuthAdapter(expectedInitialRequests: 3);
    client.dio.httpClientAdapter = adapter;

    var configuredInterceptorRequests = 0;
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          configuredInterceptorRequests++;
          handler.next(options);
        },
      ),
    );

    final responses = await Future.wait([
      client.dio.get<dynamic>('/protected/1'),
      client.dio.get<dynamic>('/protected/2'),
      client.dio.get<dynamic>('/protected/3'),
    ]);

    expect(responses.map((response) => response.statusCode), everyElement(200));
    expect(provider.forcedRefreshes, 1);
    expect(adapter.initialRequests, 3);
    expect(adapter.retryRequests, 3);
    expect(configuredInterceptorRequests, 6);
  });

  test('a retried 401 is returned without another refresh loop', () async {
    final provider = _FakeTokenProvider(() async => 'fresh-token');
    final client = ApiClient(
      baseUrl: 'https://api.exom.test',
      authTokenProvider: provider,
    );
    final adapter = _AuthAdapter(
      expectedInitialRequests: 1,
      rejectFreshToken: true,
    );
    client.dio.httpClientAdapter = adapter;

    await expectLater(
      client.dio.get<dynamic>('/always-unauthorized'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );

    expect(provider.forcedRefreshes, 1);
    expect(adapter.initialRequests, 1);
    expect(adapter.retryRequests, 1);
  });

  test('business 401 from login is not refreshed or retried', () async {
    final provider = _FakeTokenProvider(() async => 'fresh-token');
    final client = ApiClient(
      baseUrl: 'https://api.exom.test/api/v1',
      authTokenProvider: provider,
    );
    final adapter = _AuthAdapter(expectedInitialRequests: 1);
    client.dio.httpClientAdapter = adapter;

    await expectLater(
      client.dio.post<dynamic>('/auth/login'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );

    expect(provider.forcedRefreshes, 0);
    expect(adapter.initialRequests, 1);
    expect(adapter.retryRequests, 0);
  });

  test('network failure while obtaining a request token is offline', () async {
    final client = ApiClient(
      baseUrl: 'https://api.exom.test',
      authTokenProvider: _RequestTokenNetworkFailureProvider(),
    );
    final adapter = _NeverCalledAdapter();
    client.dio.httpClientAdapter = adapter;

    final error = await client.dio
        .get<dynamic>('/auth/me')
        .then<Object>(
          (_) => fail('request should fail'),
          onError: (Object error) => error,
        );

    expect(error, isA<DioException>());
    expect(ApiException.fromDioError(error as DioException).statusCode, 0);
    expect(adapter.requests, 0);
  });

  test('network failure during a 401 refresh remains offline', () async {
    final provider = _FakeTokenProvider(
      () async => throw const AuthTokenNetworkException(),
    );
    final client = ApiClient(
      baseUrl: 'https://api.exom.test',
      authTokenProvider: provider,
    );
    client.dio.httpClientAdapter = _AuthAdapter(expectedInitialRequests: 1);

    final error = await client.dio
        .get<dynamic>('/auth/me')
        .then<Object>(
          (_) => fail('request should fail'),
          onError: (Object error) => error,
        );

    expect(error, isA<DioException>());
    expect(ApiException.fromDioError(error as DioException).statusCode, 0);
    expect(provider.forcedRefreshes, 1);
  });
}

class _FakeTokenProvider implements AuthTokenProvider {
  _FakeTokenProvider(this._refresh);

  final Future<String> Function() _refresh;
  String _cachedToken = 'stale-token';
  int forcedRefreshes = 0;

  @override
  LocalAuthSession get currentSession =>
      const LocalAuthSession(uid: 'firebase-user', email: 'client@exom.dev');

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (!forceRefresh) return _cachedToken;
    forcedRefreshes++;
    _cachedToken = await _refresh();
    return _cachedToken;
  }
}

class _RequestTokenNetworkFailureProvider implements AuthTokenProvider {
  @override
  LocalAuthSession get currentSession =>
      const LocalAuthSession(uid: 'firebase-user');

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) {
    throw const AuthTokenNetworkException();
  }
}

class _NeverCalledAdapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests++;
    throw StateError('adapter should not be called');
  }

  @override
  void close({bool force = false}) {}
}

class _AuthAdapter implements HttpClientAdapter {
  _AuthAdapter({
    required this.expectedInitialRequests,
    this.rejectFreshToken = false,
  });

  final int expectedInitialRequests;
  final bool rejectFreshToken;
  final Completer<void> allInitialRequests = Completer<void>();
  int initialRequests = 0;
  int retryRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final authorization = options.headers['Authorization'];
    if (authorization == 'Bearer fresh-token') {
      retryRequests++;
      return _jsonResponse(rejectFreshToken ? 401 : 200);
    }

    initialRequests++;
    if (initialRequests == expectedInitialRequests &&
        !allInitialRequests.isCompleted) {
      allInitialRequests.complete();
    }
    return _jsonResponse(401);
  }

  ResponseBody _jsonResponse(int statusCode) => ResponseBody.fromString(
    '{"ok":true}',
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
