import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late LocalAuthSession? current;
  late LocalStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-progress-photo-storage-');
    Hive.init(directory.path);
    await Hive.openBox('cache_box');
    await Hive.openBox('settings_box');
    current = const LocalAuthSession(uid: 'A', generation: 1);
    storage = LocalStorage(
      currentSession: () => current,
      environment: 'https://test.exom.invalid',
    );
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('picker intent remains isolated and B cannot clear A recovery evidence', () async {
    await storage.saveProgressPhotoPickerIntent({
      'session_id': 'a-session',
      'view': 'FRONT',
      'state': 'picking',
    });
    final aIntent = storage.getProgressPhotoPickerIntent();
    expect(aIntent?['owner_id'], 'A');
    expect(aIntent?['session_stamp'], 'A:1:https://test.exom.invalid');

    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect(storage.getProgressPhotoPickerIntent(), isNull);
    await storage.clearProgressPhotoPickerIntent();

    current = const LocalAuthSession(uid: 'A', generation: 3);
    expect(storage.getProgressPhotoPickerIntent()?['session_id'], 'a-session');
    expect(storage.getProgressPhotoPickerIntent()?['state'], 'picking');
  });

  test('production storage namespaces progress photos and quarantines foreign formats', () async {
    final valid = {
      'id': 'A-current',
      ...storage.progressPhotoQueueIdentity,
    };
    final unknownFormat = {
      'id': 'A-unknown-format',
      'format_version': 99,
      'owner_id': 'A',
      'environment': storage.environment,
    };
    await storage.cacheData('progress_photo_upload_queue', [valid, unknownFormat]);

    expect(storage.getProgressPhotoUploadQueue().map((item) => item['id']), ['A-current']);

    await storage.saveProgressPhotoUploadQueue([
      {'id': 'A-retry', ...storage.progressPhotoQueueIdentity},
    ]);
    expect(
      storage.getCachedList('progress_photo_upload_queue')!.map((item) => (item as Map)['id']),
      ['A-unknown-format', 'A-retry'],
    );

    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect(storage.getProgressPhotoUploadQueue(), isEmpty);

    final otherEnvironment = LocalStorage(
      currentSession: () => current,
      environment: 'https://staging.exom.invalid',
    );
    expect(otherEnvironment.getProgressPhotoUploadQueue(), isEmpty);

    current = const LocalAuthSession(uid: 'A', generation: 3);
    expect(storage.getProgressPhotoUploadQueue().map((item) => item['id']), ['A-retry']);
    expect(
      storage.getCachedList('progress_photo_upload_queue')!.map((item) => (item as Map)['id']),
      ['A-unknown-format', 'A-retry'],
    );
  });
}
