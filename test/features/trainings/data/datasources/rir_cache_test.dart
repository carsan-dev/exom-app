import 'dart:io';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/data/datasources/training_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

Map<String, dynamic> _wireProgress(Object? date, int revision) => {
  'date': date,
  'sync_revision': revision,
  'training_sessions': [
    {'training_session_id': 'session-a', 'training_id': 'training-a'},
  ],
  'exercises_completed': [
    for (final id in ['occurrence-a', 'occurrence-b'])
      {
        'training_session_id': 'session-a',
        'training_exercise_id': id,
        'sets': [
          {'set_number': 1, 'weight_kg': 20, 'reps': 10, 'rir': 3},
        ],
      },
  ],
};

Future<void> _withProgressFixture(
  Future<void> Function(TrainingRemoteDataSourceImpl, LocalStorage,
      Map<String, dynamic>) check,
) async {
  final folder = await Directory.systemTemp.createTemp('exom-progress-date-');
  Hive.init(folder.path);
  await Hive.openBox('cache_box');
  final storage = LocalStorage(
    currentSession: () => const LocalAuthSession(uid: 'a'),
    environment: 'progress-date-isolated',
  );
  final client = ApiClient(baseUrl: 'https://api.example.test', useAuth: false);
  final wire = _wireProgress('2026-09-30T00:00:00.000Z', 3);
  client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    expect(options.path, '/progress');
    expect(options.queryParameters['date'], '2026-09-30');
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
      'success': true,
      'data': wire,
      'timestamp': '2026-09-30T10:00:00.000Z',
    }));
  }));
  final source = TrainingRemoteDataSourceImpl(client, storage,
    OfflineSyncService(client, storage, isAuthenticated: () => true));
  try {
    await check(source, storage, wire);
  } finally {
    client.dio.close();
    await Hive.close();
    // This directory contains only this test's isolated Hive fixture.
    await folder.delete(recursive: true);
  }
}

void main() {
  test('loads API UTC-midnight progress with its execution and performed sets', () async {
    await _withProgressFixture((source, storage, wire) async {
      final progress = await source.getCompletedExerciseIds(date: '2026-09-30');
      expect(progress.ids, {'occurrence-a', 'occurrence-b'});
      expect(progress.sessionTrainings, {'session-a': 'training-a'});
      expect(progress.sessions['session-a']?.ids, {'occurrence-a', 'occurrence-b'});
      expect(progress.sessions.containsKey('session-b'), isFalse);
      final set = progress.sessions['session-a']!.performances['occurrence-a']!.single;
      expect([set.weightKg, set.reps, set.rir], [20, 10, 3]);
      expect(storage.getCachedMap('day_progress_2026-09-30')?['date'], '2026-09-30');
      expect(wire['date'], '2026-09-30T00:00:00.000Z');
    });
  });

  for (final responseDate in [
    '2026-09-30', '2026-09-30T00:00:00.000Z', '2026-10-01T00:00:00.000Z',
  ]) {
    test('keeps newer ISO ACK progress authoritative over $responseDate', () async {
      await _withProgressFixture((source, storage, wire) async {
        final acknowledged = _wireProgress('2026-09-30T00:00:00.000Z', 4);
        acknowledged['notes'] = 'newer ACK';
        await storage.cacheData('day_progress_2026-09-30', acknowledged);
        wire['date'] = responseDate;
        wire['exercises_completed'] = <dynamic>[];
        final progress = await source.getCompletedExerciseIds(date: '2026-09-30');
        expect(progress.ids, {'occurrence-a', 'occurrence-b'});
        expect(progress.sessions['session-a']?.ids, {'occurrence-a', 'occurrence-b'});
        expect(progress.note, 'newer ACK');
        expect(storage.getCachedMap('day_progress_2026-09-30'), acknowledged);
      });
    });
  }

  for (final invalidDate in <Object?>[
    null, 'invalid', '2026-09-31', '2026-02-30T00:00:00.000Z',
    '2026-10-01T00:00:00.000Z', '2026-09-30T01:00:00.000Z',
    '2026-09-30T00:00:00.001Z', '2026-09-30T00:00:00.000',
    '2026-09-30T00:00:00.000+02:00',
  ]) {
    test('rejects unproven response date $invalidDate without cache poisoning', () async {
      await _withProgressFixture((source, storage, wire) async {
        final cached = _wireProgress('2026-09-30', 2);
        cached['exercises_completed'] = <dynamic>[];
        await storage.cacheData('day_progress_2026-09-30', cached);
        wire['date'] = invalidDate;
        wire['sync_revision'] = 99;
        final progress = await source.getCompletedExerciseIds(date: '2026-09-30');
        expect(progress.ids, isEmpty);
        expect(storage.getCachedMap('day_progress_2026-09-30'), cached);
        expect(storage.getCachedMap('home_progress_2026-09-30'), isNull);
      });
    });
    test('does not trust invalid ACK date $invalidDate over valid response', () async {
      await _withProgressFixture((source, storage, wire) async {
        final cached = _wireProgress(invalidDate, 99);
        cached['exercises_completed'] = <dynamic>[];
        await storage.cacheData('day_progress_2026-09-30', cached);
        final progress = await source.getCompletedExerciseIds(date: '2026-09-30');
        expect(progress.ids, {'occurrence-a', 'occurrence-b'});
        expect(storage.getCachedMap('day_progress_2026-09-30')?['sync_revision'], 3);
      });
    });
  }

  test('keeps the downloaded RIR offline by account and date, then refreshes without changing performed RIR', () async {
    final folder = await Directory.systemTemp.createTemp('exom-rir-cache-');
    Hive.init(folder.path);
    await Hive.openBox('cache_box');
    var session = const LocalAuthSession(uid: 'a');
    final storage = LocalStorage(currentSession: () => session, environment: 'rir-isolated');
    final client = ApiClient(baseUrl: 'https://api.example.test', useAuth: false);
    var offline = false;
    var prescribed = 0;
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (offline) {
        handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError));
        return;
      }
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
        'data': {'trainings': [{
          'id': 'same-training', 'name': 'Fuerza', 'type': 'FUERZA',
          'assignment_date': options.queryParameters['date'],
          'exercises': [{'id': 'occurrence', 'sets': 3, 'reps_or_duration': '10',
            'target_rir': prescribed, 'exercise': {'id': 'exercise', 'name': 'Sentadilla'}}],
        }]},
      }));
    }));
    final source = TrainingRemoteDataSourceImpl(client, storage,
      OfflineSyncService(client, storage, isAuthenticated: () => true));
    try {
      await storage.cacheData('day_progress_2026-09-09', {'rir': 7});
      expect((await source.getDayTrainings(date: '2026-09-09')).single.exercises.single.targetRir, 0);
      prescribed = 10;
      expect((await source.getDayTrainings(date: '2026-09-14')).single.exercises.single.targetRir, 10);
      offline = true;
      expect((await source.getDayTrainings(date: '2026-09-09')).single.exercises.single.targetRir, 0);
      session = const LocalAuthSession(uid: 'b', generation: 1);
      await expectLater(source.getDayTrainings(date: '2026-09-09'), throwsA(isA<DioException>()));
      session = const LocalAuthSession(uid: 'a', generation: 2);
      expect((await source.getDayTrainings(date: '2026-09-09')).single.exercises.single.targetRir, 0);
      offline = false;
      expect((await source.getDayTrainings(date: '2026-09-09')).single.exercises.single.targetRir, 10);
      expect(storage.getCachedMap('day_progress_2026-09-09')?['rir'], 7);
    } finally {
      client.dio.close();
      await Hive.close();
      // This directory is created by this test and contains only its Hive fixture.
      await folder.delete(recursive: true);
    }
  });
}
