import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/prompts/automatic_prompt_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const _sessionA = LocalAuthSession(uid: 'uid-A', email: 'A@exom.test');

/// Real Hive files: the Sunday reminder keys live in the settings box, per
/// identity, like `tutorial_complete::<identity>`, and survive a restart.
void main() {
  late Directory directory;
  late LocalStorage storage;

  Future<void> openBoxes() async {
    Hive.init(directory.path);
    await Hive.openBox('settings_box');
    await Hive.openBox('auth_box');
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-prompt-storage-');
    await openBoxes();
    storage = LocalStorage(currentSession: () => _sessionA);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('Sunday reminder keys are per identity and survive a restart', () async {
    expect(
      storage.isRecapSundayPromptOffFor(uid: 'uid-A', email: 'A@exom.test'),
      isFalse,
    );
    expect(
      storage.recapSundayPromptLastFor(uid: 'uid-A', email: 'A@exom.test'),
      isNull,
    );

    await storage.setRecapSundayPromptLastFor(
      uid: 'uid-A',
      email: 'A@exom.test',
      day: '2026-11-22',
    );
    await storage.setRecapSundayPromptOffFor(
      uid: 'uid-A',
      email: 'A@exom.test',
    );
    await Hive.close();
    await openBoxes();

    final box = Hive.box('settings_box');
    expect(box.get('recap_sunday_prompt_off::a@exom.test'), isTrue);
    expect(box.get('recap_sunday_prompt_last::a@exom.test'), '2026-11-22');
    expect(
      storage.isRecapSundayPromptOffFor(uid: 'uid-A', email: 'a@exom.test'),
      isTrue,
    );
    // Another user on the same device is isolated.
    expect(
      storage.isRecapSundayPromptOffFor(uid: 'uid-B', email: 'b@exom.test'),
      isFalse,
    );
    expect(
      storage.recapSundayPromptLastFor(uid: 'uid-B', email: 'b@exom.test'),
      isNull,
    );
  });

  test('no identity: nothing read or written', () async {
    await storage.setRecapSundayPromptOffFor(uid: ' ', email: null);
    await storage.setRecapSundayPromptLastFor(
      uid: ' ',
      email: null,
      day: '2026-11-22',
    );
    expect(Hive.box('settings_box').keys, isEmpty);
    expect(storage.isRecapSundayPromptOffFor(uid: ' ', email: null), isFalse);
  });

  test('LocalStorage-backed prompt store maps onto the same keys', () async {
    final store = LocalStorageAutomaticPromptStore(storage);
    expect(
      store.identityFor(uid: 'uid-A', email: 'A@exom.test'),
      'a@exom.test',
    );
    await store.setTutorialComplete(uid: 'uid-A', email: 'A@exom.test');
    expect(
      storage.isTutorialCompleteFor(uid: 'uid-A', email: 'a@exom.test'),
      isTrue,
    );
    await store.setRecapSundayPromptLast(
      uid: 'uid-A',
      email: 'A@exom.test',
      day: '2026-11-22',
    );
    expect(
      store.recapSundayPromptLast(uid: 'uid-A', email: 'A@exom.test'),
      '2026-11-22',
    );
    await store.setRecapSundayPromptOff(uid: 'uid-A', email: 'A@exom.test');
    expect(
      store.isRecapSundayPromptOff(uid: 'uid-A', email: 'A@exom.test'),
      isTrue,
    );
  });
}
