import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/trainings/data/datasources/training_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  const date = '2026-09-29';
  const cacheKey = 'day_progress_$date';
  const confirmed = <String, dynamic>{
    'date': date,
    'sync_revision': 7,
    'training_sessions': [
      {'training_session_id': 'execution-one', 'training_id': 'training-one'},
    ],
    'exercises_completed': [
      {
        'training_exercise_id': 'te-1',
        'exercise_id': 'exercise-one',
        'training_session_id': 'execution-one',
      },
    ],
  };

  Future<void> checkGetAgainstConfirmedCache({
    required int? getRevision,
    required bool shouldRetainCompletion,
    bool hasConfirmedCache = true,
  }) async {
    final folder = await Directory.systemTemp.createTemp('exom-training-sync-cache-');
    ApiClient? client;
    try {
      Hive.init(folder.path);
      await Hive.openBox('cache_box');
      final storage = LocalStorage(
        currentSession: () => const LocalAuthSession(uid: 'owner-one'),
        environment: 'training-sync-cache-test',
      );
      client = ApiClient(baseUrl: 'https://api.example.test', useAuth: false);
      client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        expect(options.method, 'GET');
        expect(options.path, '/progress');
        expect(options.queryParameters['date'], date);
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'data': {
              'date': date,
              'sync_revision': ?getRevision,
              'training_sessions': const [
                {'training_session_id': 'execution-one', 'training_id': 'training-one'},
              ],
              'exercises_completed': const <Map<String, dynamic>>[],
            },
          },
        ));
      }));
      final source = TrainingRemoteDataSourceImpl(
        client,
        storage,
        OfflineSyncService(client, storage, isAuthenticated: () => true),
      );
      if (hasConfirmedCache) await storage.cacheData(cacheKey, confirmed);
      final result = await source.getCompletedExerciseIds(date: date);
      final cached = storage.getCachedMap(cacheKey);
      expect(storage.getPendingSyncActions(), isEmpty);
      expect(result.forSession('execution-one', 'training-one').ids.contains('te-1'),
          shouldRetainCompletion);
      expect(result.forSession('execution-one', 'another-training').ids, isEmpty);
      expect(cached?['sync_revision'], shouldRetainCompletion ? 7 : getRevision);
      final exercises = (cached?['exercises_completed'] as List?) ?? const [];
      expect(exercises.any((entry) => entry is Map &&
          entry['training_exercise_id'] == 'te-1' &&
          entry['training_session_id'] == 'execution-one'), shouldRetainCompletion);
    } finally {
      client?.dio.close();
      await Hive.close();
      // Only the temporary Hive fixture owned by this test is removed.
      await folder.delete(recursive: true);
    }
  }

  test('older GET cannot erase confirmed completion for the same execution', () async {
    await checkGetAgainstConfirmedCache(getRevision: 6, shouldRetainCompletion: true);
  });

  test('unversioned empty GET cannot erase known confirmed completion', () async {
    await checkGetAgainstConfirmedCache(getRevision: null, shouldRetainCompletion: true);
  });

  test('unversioned empty GET does not invent completion without a confirmed cache', () async {
    await checkGetAgainstConfirmedCache(
      getRevision: null, shouldRetainCompletion: false, hasConfirmedCache: false);
  });

  test('newer empty GET legitimately clears the confirmed completion', () async {
    await checkGetAgainstConfirmedCache(getRevision: 8, shouldRetainCompletion: false);
  });

  test('wrong-date GET preserves same-day legacy cache without revision', () async {
    const otherDate = '2026-09-30';
    final legacyProgress = <String, dynamic>{
      'date': date,
      'training_sessions': [
        {'training_session_id': 'execution-one', 'training_id': 'training-one'},
      ],
      'exercises_completed': [
        {
          'training_exercise_id': 'te-1',
          'exercise_id': 'exercise-one',
          'training_session_id': 'execution-one',
        },
      ],
    };
    final folder = await Directory.systemTemp.createTemp('exom-training-sync-cache-');
    ApiClient? client;
    try {
      Hive.init(folder.path);
      await Hive.openBox('cache_box');
      final storage = LocalStorage(
        currentSession: () => const LocalAuthSession(uid: 'owner-one'),
        environment: 'training-sync-cache-test',
      );
      client = ApiClient(baseUrl: 'https://api.example.test', useAuth: false);
      client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        expect(options.method, 'GET');
        expect(options.path, '/progress');
        expect(options.queryParameters['date'], date);
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'data': {
              'date': otherDate,
              'sync_revision': 8,
              'training_sessions': const [
                {'training_session_id': 'execution-one', 'training_id': 'training-one'},
              ],
              'exercises_completed': const <Map<String, dynamic>>[],
            },
          },
        ));
      }));
      final source = TrainingRemoteDataSourceImpl(
        client,
        storage,
        OfflineSyncService(client, storage, isAuthenticated: () => true),
      );
      await storage.cacheData(cacheKey, legacyProgress);
      await storage.cacheData('home_progress_$date', legacyProgress);
      await storage.cacheData('completed_exercises_$date', ['te-1']);

      final result = await source.getCompletedExerciseIds(date: date);

      expect(storage.getPendingSyncActions(), isEmpty);
      expect(result.forSession('execution-one', 'training-one').ids, contains('te-1'));
      expect(result.forSession('execution-one', 'another-training').ids, isEmpty);
      expect(storage.getCachedMap(cacheKey), legacyProgress);
      expect(storage.getCachedMap('home_progress_$date'), legacyProgress);
      expect(storage.getCachedList('completed_exercises_$date'), ['te-1']);
      expect(storage.getCachedMap('day_progress_$otherDate'), isNull);
      expect(storage.getCachedMap('home_progress_$otherDate'), isNull);
      expect(storage.getCachedList('completed_exercises_$otherDate'), isNull);
    } finally {
      client?.dio.close();
      await Hive.close();
      await folder.delete(recursive: true);
    }
  });

  test('wrong-date GET cannot replace confirmed exercise progress', () async {
    const otherDate = '2026-09-30';
    final folder = await Directory.systemTemp.createTemp('exom-training-sync-cache-');
    ApiClient? client;
    try {
      Hive.init(folder.path);
      await Hive.openBox('cache_box');
      final storage = LocalStorage(
        currentSession: () => const LocalAuthSession(uid: 'owner-one'),
        environment: 'training-sync-cache-test',
      );
      client = ApiClient(baseUrl: 'https://api.example.test', useAuth: false);
      client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        expect(options.method, 'GET');
        expect(options.path, '/progress');
        expect(options.queryParameters['date'], date);
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'data': {
              'date': otherDate,
              'sync_revision': 8,
              'training_sessions': const [
                {'training_session_id': 'execution-one', 'training_id': 'training-one'},
              ],
              'exercises_completed': const <Map<String, dynamic>>[],
            },
          },
        ));
      }));
      final source = TrainingRemoteDataSourceImpl(
        client,
        storage,
        OfflineSyncService(client, storage, isAuthenticated: () => true),
      );
      await storage.cacheData(cacheKey, confirmed);
      await storage.cacheData('home_progress_$date', confirmed);
      await storage.cacheData('completed_exercises_$date', ['te-1']);

      final result = await source.getCompletedExerciseIds(date: date);

      expect(storage.getPendingSyncActions(), isEmpty);
      expect(result.forSession('execution-one', 'training-one').ids, contains('te-1'));
      expect(result.forSession('execution-one', 'another-training').ids, isEmpty);
      expect(storage.getCachedMap(cacheKey), confirmed);
      expect(storage.getCachedMap('home_progress_$date'), confirmed);
      expect(storage.getCachedList('completed_exercises_$date'), ['te-1']);
      expect(storage.getCachedMap('day_progress_$otherDate'), isNull);
      expect(storage.getCachedMap('home_progress_$otherDate'), isNull);
      expect(storage.getCachedList('completed_exercises_$otherDate'), isNull);
    } finally {
      client?.dio.close();
      await Hive.close();
      await folder.delete(recursive: true);
    }
  });
}
