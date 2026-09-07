import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class ValidationAdapter implements HttpClientAdapter {
  ValidationAdapter(this.message);
  final Object message;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'message': message, 'sensitive': 'secret-token-not-for-logs'}),
    400,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  for (final path in ['/uploads/sessions', '/auth/social']) {
    for (final recognized in [true, false]) {
      test(
        'upload contract diagnostic is specific and sanitized: $path/$recognized',
        () async {
          final logs = <String>[];
          final original = debugPrint;
          debugPrint = (String? message, {int? wrapWidth}) {
            if (message != null) logs.add(message);
          };
          addTearDown(() => debugPrint = original);
          final client = ApiClient(
            useAuth: false,
            baseUrl: 'https://api.exom.test',
          );
          client.dio.httpClientAdapter = ValidationAdapter([
            if (recognized) 'property client_operation_id should not exist',
            'invalid customer@example.test https://storage.invalid/file?token=secret',
          ]);
          await expectLater(
            client.dio.post<Object?>(path),
            throwsA(isA<DioException>()),
          );
          final output = logs.join('\n');
          expect(
            output.contains('operation_identity_unsupported'),
            recognized && path == '/uploads/sessions',
          );
          expect(output, isNot(contains('secret')));
          expect(output, isNot(contains('customer@example.test')));
          expect(output, isNot(contains('storage.invalid')));
        },
      );
    }
  }
}
