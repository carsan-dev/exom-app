import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/onboarding/onboarding_resolver.dart';
import 'package:exom_app/core/onboarding/onboarding_sync_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../helpers/onboarding_harness.dart';
import '../../helpers/onboarding_remote_fakes.dart';

const _sessionA = LocalAuthSession(uid: 'uid-A', email: 'a@exom.test');
const _markKeyA = 'onboarding_complete::a@exom.test';

/// Real Hive files in a temporary directory: closing and reopening the boxes
/// simulates an app crash / restart between steps.
void main() {
  late Directory directory;
  late LocalStorage storage;

  Future<void> openBoxes() async {
    Hive.init(directory.path);
    await Hive.openBox('settings_box');
    await Hive.openBox('auth_box');
  }

  Future<void> restart() async {
    await Hive.close();
    await openBoxes();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-onb-storage-');
    await openBoxes();
    storage = LocalStorage(currentSession: () => _sessionA);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  group('OP-APP-11 crash windows', () {
    test('(a) after PUT + local write, before POST: pending survives a '
        'restart and is sent on the next validated session', () async {
      await storage.markOnboardingLocallyDone(
        uid: 'uid-A',
        email: 'a@exom.test',
        outcome: OnboardingOutcomes.completed,
      );
      await restart();

      final pending = storage.onboardingPendingFor('uid-A');
      expect(pending, isNotNull);
      expect(pending!['outcome'], OnboardingOutcomes.completed);
      expect(pending['owner_id'], 'uid-A');
      expect(pending['environment'], 'test');
      expect(pending['format_version'], 1);
      expect(pending['created_at'], isA<String>());
      expect(Hive.box('settings_box').get(_markKeyA), isTrue);

      final remote = FakeOnboardingRemote();
      final coordinator = OnboardingSyncCoordinator(
        storage: storage,
        currentSession: () => _sessionA,
        remote: remote,
      );
      coordinator.handle(
        AuthAuthenticated(userFromServer(profile: pendingProfile)),
      );
      await coordinator.settled;

      expect(remote.calls.single.outcome, OnboardingOutcomes.completed);
      expect(storage.onboardingPendingFor('uid-A'), isNull);
    });

    test('(b) legacy mark without pending resolves as R4', () async {
      await storage.setOnboardingCompleteFor(
        uid: 'uid-A',
        email: 'a@exom.test',
      );
      await restart();

      expect(storage.onboardingPendingFor('uid-A'), isNull);
      final result = resolveOnboarding(
        user: userFromServer(profile: pendingProfile),
        localDone: storage.isOnboardingLocallyDone(
          uid: 'uid-A',
          email: 'a@exom.test',
        ),
      );
      expect(result.needsOnboarding, isFalse);
      expect(result.registerRepair, isTrue);
    });

    test('(c) pending without mark still counts as done locally', () async {
      await storage.registerOnboardingRepair('uid-A');
      await restart();

      expect(
        storage.isOnboardingCompleteFor(uid: 'uid-A', email: 'a@exom.test'),
        isFalse,
      );
      expect(
        storage.isOnboardingLocallyDone(uid: 'uid-A', email: 'a@exom.test'),
        isTrue,
      );
    });

    test('mark and pending are written together (single putAll)', () async {
      await storage.markOnboardingLocallyDone(
        uid: 'uid-A',
        email: 'a@exom.test',
        outcome: OnboardingOutcomes.skipped,
      );
      final box = Hive.box('settings_box');
      expect(box.get(_markKeyA), isTrue);
      expect(box.get('onboarding_complete'), isTrue);
      expect(box.get('onboarding_complete_identity'), 'a@exom.test');
      expect(storage.onboardingPendingFor('uid-A')?['outcome'], 'SKIPPED');
    });

    test('repair never overwrites an existing entry', () async {
      await storage.markOnboardingLocallyDone(
        uid: 'uid-A',
        email: 'a@exom.test',
        outcome: OnboardingOutcomes.skipped,
      );
      await storage.registerOnboardingRepair('uid-A');

      expect(storage.onboardingPendingFor('uid-A')?['outcome'], 'SKIPPED');
    });

    test('pending with an unknown outcome is not attributable', () async {
      await storage.markOnboardingLocallyDone(
        uid: 'uid-A',
        email: 'a@exom.test',
        outcome: 'BOGUS',
      );

      expect(storage.onboardingPendingFor('uid-A'), isNull);
    });
  });

  group('OP-CMP-04 existing Hive marks', () {
    test('per-identity key is unchanged', () async {
      await Hive.box('settings_box').put(_markKeyA, true);
      expect(
        storage.isOnboardingCompleteFor(uid: 'uid-A', email: 'A@Exom.test '),
        isTrue,
      );
      expect(
        storage.isOnboardingLocallyDone(uid: 'uid-A', email: 'a@exom.test'),
        isTrue,
      );
    });

    test('uid identity when there is no email', () async {
      await Hive.box(
        'settings_box',
      ).put('onboarding_complete::uid:uid-A', true);
      expect(storage.isOnboardingLocallyDone(uid: 'uid-A'), isTrue);
    });

    test('legacy global key with the same identity migrates', () async {
      final box = Hive.box('settings_box');
      await box.put('onboarding_complete', true);
      await box.put('onboarding_complete_identity', 'a@exom.test');

      expect(
        storage.isOnboardingLocallyDone(uid: 'uid-A', email: 'a@exom.test'),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(box.get(_markKeyA), isTrue);
    });

    test('orphan legacy global key is rejected and removed', () async {
      final box = Hive.box('settings_box');
      await box.put('onboarding_complete', true);

      expect(
        storage.isOnboardingLocallyDone(uid: 'uid-A', email: 'a@exom.test'),
        isFalse,
      );
      await Future<void>.delayed(Duration.zero);
      expect(box.containsKey('onboarding_complete'), isFalse);
    });

    test('legacy global key of another identity is not adopted', () async {
      final box = Hive.box('settings_box');
      await box.put('onboarding_complete', true);
      await box.put('onboarding_complete_identity', 'b@exom.test');

      expect(
        storage.isOnboardingLocallyDone(uid: 'uid-A', email: 'a@exom.test'),
        isFalse,
      );
    });

    test('mark and pending survive logout (clearSessionData)', () async {
      await storage.markOnboardingLocallyDone(
        uid: 'uid-A',
        email: 'a@exom.test',
        outcome: OnboardingOutcomes.completed,
      );
      await storage.clearSessionData();
      await restart();

      expect(Hive.box('settings_box').get(_markKeyA), isTrue);
      expect(storage.onboardingPendingFor('uid-A'), isNotNull);
    });
  });

  test('OP-APP-16 pending of A is not visible as pending of B', () async {
    await storage.markOnboardingLocallyDone(
      uid: 'uid-A',
      email: 'a@exom.test',
      outcome: OnboardingOutcomes.completed,
    );
    expect(storage.onboardingPendingFor('uid-B'), isNull);
    expect(
      storage.isOnboardingLocallyDone(uid: 'uid-B', email: 'b@exom.test'),
      isFalse,
    );
  });
}
