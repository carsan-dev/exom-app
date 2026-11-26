// Inicio offline (E1 D1): the inline line «Sin conexión · datos guardados»
// appears when the data layer serves the saved copy because there is no
// network, over the real data stack (datasource, repository and bloc). A
// rejected request (401/403) or a server failure never reads as offline.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/features/home/data/datasources/home_remote_datasource.dart';
import 'package:exom_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_e1_harness.dart';

class _MemoryStorage extends LocalStorage {
  final cache = <String, dynamic>{};

  @override
  Future<void> cacheData(String key, dynamic value) async {
    cache[key] = value;
  }

  @override
  Map<String, dynamic>? getCachedMap(String key) {
    final value = cache[key];
    return value is Map<String, dynamic> ? value : null;
  }

  @override
  List<dynamic>? getCachedList(String key) {
    final value = cache[key];
    return value is List ? List<dynamic>.from(value) : null;
  }

  @override
  List<Map<String, dynamic>> getPendingSyncActions() => const [];
}

class _Adapter implements HttpClientAdapter {
  bool offline = false;
  int? status;

  /// Status of single paths (the rest answer).
  final pathStatus = <String, int>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final failure = status ?? pathStatus[options.path];
    if (failure != null) {
      return ResponseBody.fromString(
        '{}',
        failure,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final Object? data = switch (options.path) {
      '/trainings/day' => {
        'id': 'training-1',
        'name': 'Pierna fuerza',
        'estimated_duration_min': 55,
        'exercises': const [
          {
            'id': 'te-1',
            'sets': 3,
            'exercise': {'id': 'e-1'},
          },
        ],
      },
      '/streaks/me' => {'current_days': 4},
      '/progress' => {'exercises_completed': const []},
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The harness repository, answered by the real Inicio data stack.
class _RealStack extends InicioE1Repository {
  _RealStack(this.real) : super((_) => inicioE1Training);

  final HomeRepository real;

  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) {
    dates.add(date);
    return real.getHomeSummary(
      date: date,
      includeSharedData: includeSharedData,
    );
  }
}

({_RealStack repository, _Adapter adapter}) _stack() {
  final adapter = _Adapter();
  final client = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test')
    ..dio.httpClientAdapter = adapter;
  final source = HomeRemoteDataSourceImpl(client, _MemoryStorage());
  return (repository: _RealStack(HomeRepositoryImpl(source)), adapter: adapter);
}

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleRealStack(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

String? _lineTitle(WidgetTester tester) {
  final line = find.byType(ExomInlineMessage);
  if (line.evaluate().isEmpty) return null;
  return tester.widget<ExomInlineMessage>(line).title;
}

void main() {
  testWidgets('a reload without network says «Sin conexión · datos guardados» '
      'and keeps the saved session', (tester) async {
    final stack = _stack();
    await pumpInicioE1(tester, repository: stack.repository, settle: false);
    await _settleRealStack(tester);
    expect(find.text('PIERNA FUERZA'), findsWidgets);
    expect(_lineTitle(tester), isNull);

    stack.adapter.offline = true;
    await _pullToRefresh(tester);
    expect(_lineTitle(tester), 'Sin conexión · datos guardados');
    expect(find.text('PIERNA FUERZA'), findsWidgets);
  });

  testWidgets('opening Inicio without network and without a saved copy says '
      '«Sin conexión · datos guardados»', (tester) async {
    final stack = _stack();
    stack.adapter.offline = true;
    await pumpInicioE1(tester, repository: stack.repository, settle: false);
    await _settleRealStack(tester);
    expect(_lineTitle(tester), 'Sin conexión · datos guardados');
  });

  for (final status in [401, 403, 500]) {
    testWidgets('a $status keeps the saved session and is not «Sin conexión»', (
      tester,
    ) async {
      final stack = _stack();
      await pumpInicioE1(tester, repository: stack.repository, settle: false);
      await _settleRealStack(tester);

      stack.adapter.status = status;
      await _pullToRefresh(tester);
      final title = _lineTitle(tester);
      expect(title, isNotNull);
      expect(title, isNot('Sin conexión · datos guardados'));
      expect(find.text('PIERNA FUERZA'), findsWidgets);
    });
  }

  testWidgets('a reload that answers again removes the line', (tester) async {
    final stack = _stack();
    stack.adapter.offline = true;
    await pumpInicioE1(tester, repository: stack.repository, settle: false);
    await _settleRealStack(tester);
    expect(_lineTitle(tester), isNotNull);

    stack.adapter.offline = false;
    await tester.tap(find.text('Reintentar'));
    await _settleRealStack(tester);
    expect(_lineTitle(tester), isNull);
    expect(find.text('PIERNA FUERZA'), findsWidgets);
  });

  testWidgets('a single 403 with the rest answering is not «Sin conexión» '
      'and keeps the content', (tester) async {
    final stack = _stack();
    await pumpInicioE1(tester, repository: stack.repository, settle: false);
    await _settleRealStack(tester);
    expect(_lineTitle(tester), isNull);

    stack.adapter.pathStatus['/profile/me'] = 403;
    await _pullToRefresh(tester);
    final title = _lineTitle(tester);
    expect(title, isNotNull);
    expect(title, isNot('Sin conexión · datos guardados'));
    expect(find.text('PIERNA FUERZA'), findsWidgets);
  });
}
