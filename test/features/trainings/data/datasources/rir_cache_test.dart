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
