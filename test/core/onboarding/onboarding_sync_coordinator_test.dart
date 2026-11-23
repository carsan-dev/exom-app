import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/onboarding/onboarding_resolver.dart';
import 'package:exom_app/core/onboarding/onboarding_sync_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/onboarding/data/onboarding_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/onboarding_harness.dart';
import '../../helpers/onboarding_remote_fakes.dart';

const _sessionA = LocalAuthSession(
  uid: 'uid-A',
  email: 'a@exom.test',
  generation: 1,
);
const _sessionB = LocalAuthSession(
  uid: 'uid-B',
  email: 'b@exom.test',
  generation: 2,
);
const _markKeyA = 'onboarding_complete::a@exom.test';

AuthAuthenticated _validated(
  Map<String, Object?> profile, {
  String role = 'CLIENT',
  String id = 'db-A',
  String email = 'a@exom.test',
}) => AuthAuthenticated(
  userFromServer(id: id, email: email, role: role, profile: profile),
);

String _pendingKey(String environment, String uid) =>
    'onboarding_sync_pending::'
    '${base64Url.encode(utf8.encode(jsonEncode([environment, uid])))}';

void main() {
  late Directory directory;
  late SessionFirebaseAuthService firebase;
  late LocalStorage storage;

  setUp(() async {
    directory = await openInMemorySettingsBox();
    firebase = SessionFirebaseAuthService(_sessionA);
    storage = LocalStorage(currentSession: () => firebase.currentSession);
  });

  tearDown(() => closeSettingsBox(directory));

  OnboardingSyncCoordinator coordinatorWith(
    OnboardingRemoteDataSource remote,
  ) => OnboardingSyncCoordinator(
    storage: storage,
    currentSession: () => firebase.currentSession,
    remote: remote,
  );

  Future<void> seedPendingA([String? outcome = OnboardingOutcomes.completed]) =>
      storage.markOnboardingLocallyDone(
        uid: 'uid-A',
        email: 'a@exom.test',
        outcome: outcome,
      );

  group('OP-APP-09 send outcome', () {
    final cases = <String, Object? Function()>{
      '200': () => null,
      '401': () => httpError(401),
      '403': () => httpError(403),
      '404': () => httpError(404),
      '409': () => httpError(409),
      '423': () => httpError(423),
      '500': () => httpError(500),
      '503': () => httpError(503),
      'network': networkError,
      'timeout': () => DioException(
        requestOptions: RequestOptions(path: '/profile/me/onboarding'),
        type: DioExceptionType.receiveTimeout,
      ),
    };
    for (final entry in cases.entries) {
      test(
        '${entry.key} ${entry.key == '200' ? 'clears' : 'keeps'} pending',
        () async {
          final remote = FakeOnboardingRemote();
          final error = entry.value();
          if (error != null) remote.responses.add(() => throw error);
          final coordinator = coordinatorWith(remote);
          await seedPendingA();

          coordinator.handle(_validated(pendingProfile));
          await coordinator.settled;

          expect(remote.calls, hasLength(1));
          expect(remote.calls.single.expectedOwner, 'uid-A');
          expect(remote.calls.single.outcome, OnboardingOutcomes.completed);
          if (error == null) {
            expect(storage.onboardingPendingFor('uid-A'), isNull);
          } else {
            expect(storage.onboardingPendingFor('uid-A'), isNotNull);
          }
          expect(settingsBox.get(_markKeyA), isTrue);
        },
      );
    }

    test('offline synthetic session never sends', () async {
      final remote = FakeOnboardingRemote();
      final coordinator = coordinatorWith(remote);
      await seedPendingA();

      coordinator.handle(
        const AuthAuthenticated(
          UserEntity(id: 'uid-A', email: 'a@exom.test', role: 'CLIENT'),
        ),
      );
      await coordinator.requestSync();
      await coordinator.settled;

      expect(remote.calls, isEmpty);
      expect(storage.onboardingPendingFor('uid-A'), isNotNull);
    });

    test('a single request in flight per identity', () async {
      final remote = FakeOnboardingRemote();
      final gate = Completer<void>();
      remote.responses.add(() => gate.future);
      final coordinator = coordinatorWith(remote);
      await seedPendingA();

      coordinator.handle(_validated(pendingProfile));
      await Future<void>.delayed(Duration.zero);
      unawaited(coordinator.requestSync());
      unawaited(coordinator.requestSync());
      await Future<void>.delayed(Duration.zero);
      expect(remote.calls, hasLength(1));

      gate.complete();
      await coordinator.settled;
      expect(remote.calls, hasLength(1));
      expect(storage.onboardingPendingFor('uid-A'), isNull);
    });

    test('at most one automatic attempt per validated session', () async {
      final remote = FakeOnboardingRemote();
      remote.responses.addAll([
        () => throw httpError(503),
        () => throw httpError(503),
        () => throw httpError(503),
      ]);
      final coordinator = coordinatorWith(remote);
      await seedPendingA();

      coordinator.handle(_validated(pendingProfile));
      await coordinator.settled;
      coordinator.handle(const AuthLoading());
      coordinator.handle(_validated(pendingProfile));
      await coordinator.settled;
      expect(remote.calls, hasLength(1), reason: 'same session, no loop');

      firebase.session = const LocalAuthSession(
        uid: 'uid-A',
        email: 'a@exom.test',
        generation: 5,
      );
      coordinator.handle(_validated(pendingProfile));
      await coordinator.settled;
      expect(remote.calls, hasLength(2), reason: 'new validated session');
      expect(storage.onboardingPendingFor('uid-A'), isNotNull);
    });
  });

  group('effects', () {
    test(
      'OP-APP-12 R4 self-repair sends without outcome, 2xx clears',
      () async {
        final remote = FakeOnboardingRemote();
        final coordinator = coordinatorWith(remote);
        await storage.setOnboardingCompleteFor(
          uid: 'uid-A',
          email: 'a@exom.test',
        );
        expect(storage.onboardingPendingFor('uid-A'), isNull);

        coordinator.handle(_validated(pendingProfile));
        await coordinator.settled;

        expect(remote.calls, hasLength(1));
        expect(remote.calls.single.outcome, isNull);
        expect(storage.onboardingPendingFor('uid-A'), isNull);
        expect(settingsBox.get(_markKeyA), isTrue);
      },
    );

    test('OP-APP-12 R4 failure keeps the repair entry for later', () async {
      final remote = FakeOnboardingRemote()
        ..responses.add(() => throw networkError());
      final coordinator = coordinatorWith(remote);
      await storage.setOnboardingCompleteFor(
        uid: 'uid-A',
        email: 'a@exom.test',
      );

      coordinator.handle(_validated(pendingProfile));
      await coordinator.settled;

      final pending = storage.onboardingPendingFor('uid-A');
      expect(pending, isNotNull);
      expect(pending!['outcome'], isNull);
    });

    test('R5 resends the stored outcome without a new repair', () async {
      final remote = FakeOnboardingRemote();
      final coordinator = coordinatorWith(remote);
      await seedPendingA(OnboardingOutcomes.skipped);

      coordinator.handle(_validated(pendingProfile));
      await coordinator.settled;

      expect(remote.calls.single.outcome, OnboardingOutcomes.skipped);
    });

    test('OP-APP-13 R2 server done writes the Hive mark', () async {
      final remote = FakeOnboardingRemote();
      final coordinator = coordinatorWith(remote);

      coordinator.handle(_validated(doneProfile));
      await coordinator.settled;

      expect(settingsBox.get(_markKeyA), isTrue);

      expect(remote.calls, isEmpty);
      expect(storage.onboardingPendingFor('uid-A'), isNull);
    });

    test('OP-APP-13 R3 server done clears the pending, no POST', () async {
      final remote = FakeOnboardingRemote();
      final coordinator = coordinatorWith(remote);
      await seedPendingA();

      coordinator.handle(_validated(doneProfile));
      await coordinator.settled;

      expect(remote.calls, isEmpty);
      expect(storage.onboardingPendingFor('uid-A'), isNull);
      expect(settingsBox.get(_markKeyA), isTrue);
    });

    for (final role in ['ADMIN', 'SUPER_ADMIN']) {
      test(
        'OP-APP-14 $role: no POST, pending of that identity cleared',
        () async {
          final remote = FakeOnboardingRemote();
          final coordinator = coordinatorWith(remote);
          await seedPendingA();

          coordinator.handle(_validated(pendingProfile, role: role));
          await coordinator.requestSync();
          await coordinator.settled;

          expect(remote.calls, isEmpty);
          expect(storage.onboardingPendingFor('uid-A'), isNull);
        },
      );
    }

    test('OP-CMP-03 old API: pending sent, 404 keeps it', () async {
      final remote = FakeOnboardingRemote()
        ..responses.add(() => throw httpError(404));
      final coordinator = coordinatorWith(remote);
      await seedPendingA();

      coordinator.handle(_validated(legacyProfile));
      await coordinator.settled;

      expect(remote.calls, hasLength(1));
      expect(storage.onboardingPendingFor('uid-A'), isNotNull);
    });

    test('OP-CMP-03 old API with nothing pending sends nothing', () async {
      final remote = FakeOnboardingRemote();
      final coordinator = coordinatorWith(remote);
      await storage.setOnboardingCompleteFor(
        uid: 'uid-A',
        email: 'a@exom.test',
      );

      coordinator.handle(_validated(legacyProfile));
      await coordinator.settled;

      expect(remote.calls, isEmpty);
      expect(storage.onboardingPendingFor('uid-A'), isNull);
    });
  });

  group('OP-APP-16 ownership of the pending entry', () {
    test('an entry of another environment is invisible and not sent', () async {
      final other = LocalStorage(
        currentSession: () => firebase.currentSession,
        environment: 'https://other.exom.test/api/v1',
      );
      await other.markOnboardingLocallyDone(
        uid: 'uid-A',
        email: 'a@exom.test',
        outcome: OnboardingOutcomes.completed,
      );
      final remote = FakeOnboardingRemote();
      final coordinator = coordinatorWith(remote);

      expect(storage.onboardingPendingFor('uid-A'), isNull);
      coordinator.handle(_validated(legacyProfile));
      await coordinator.settled;

      expect(remote.calls, isEmpty);
      expect(other.onboardingPendingFor('uid-A'), isNotNull);
    });

    for (final entry in <String, Map<String, Object?>>{
      'foreign owner_id': {
        'format_version': 1,
        'owner_id': 'uid-B',
        'environment': 'test',
        'outcome': 'COMPLETED',
      },
      'unknown format_version': {
        'format_version': 99,
        'owner_id': 'uid-A',
        'environment': 'test',
        'outcome': 'COMPLETED',
      },
      'no owner_id': {
        'format_version': 1,
        'environment': 'test',
        'outcome': 'COMPLETED',
      },
    }.entries) {
      test('an entry with ${entry.key} is kept and never sent', () async {
        final key = _pendingKey('test', 'uid-A');
        await settingsBox.put(key, entry.value);
        final remote = FakeOnboardingRemote();
        final coordinator = coordinatorWith(remote);

        expect(storage.onboardingPendingFor('uid-A'), isNull);
        coordinator.handle(_validated(legacyProfile));
        await coordinator.requestSync();
        await coordinator.settled;

        expect(remote.calls, isEmpty);
        expect(settingsBox.get(key), entry.value);
      });
    }
  });

  group('OP-APP-10 user switch A -> B (real ApiClient interceptors)', () {
    late List<String?> authorizations;
    late Future<void> Function()? beforeRespond;
    late ApiClient client;

    setUp(() {
      authorizations = [];
      beforeRespond = null;
      client = ApiClient(
        baseUrl: 'https://api.exom.test/api/v1',
        authTokenProvider: firebase,
      );
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            authorizations.add(options.headers['Authorization']?.toString());
            await beforeRespond?.call();
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'onboarding_completed_at': '2026-11-23T10:00:00.000Z',
                    'onboarding_outcome': 'COMPLETED',
                  },
                },
              ),
              true,
            );
          },
        ),
      );
    });

    test('B signs in during A\'s request: A\'s entry is kept, never sent '
        'with B, and sent later with A', () async {
      final coordinator = coordinatorWith(
        OnboardingRemoteDataSourceImpl(client),
      );
      await seedPendingA();
      beforeRespond = () async {
        firebase.session = _sessionB;
      };

      coordinator.handle(_validated(pendingProfile));
      await coordinator.settled;

      expect(authorizations, ['Bearer token-uid-A']);
      expect(
        storage.onboardingPendingFor('uid-A'),
        isNotNull,
        reason: 'the response of the old session is discarded',
      );

      beforeRespond = null;
      coordinator.handle(
        _validated(pendingProfile, id: 'db-B', email: 'b@exom.test'),
      );
      await coordinator.requestSync();
      await coordinator.settled;
      expect(authorizations, [
        'Bearer token-uid-A',
      ], reason: 'B has nothing pending and never sends A\'s entry');
      expect(storage.onboardingPendingFor('uid-A'), isNotNull);

      firebase.session = const LocalAuthSession(
        uid: 'uid-A',
        email: 'a@exom.test',
        generation: 3,
      );
      coordinator.handle(_validated(pendingProfile));
      await coordinator.settled;

      expect(authorizations, ['Bearer token-uid-A', 'Bearer token-uid-A']);
      expect(storage.onboardingPendingFor('uid-A'), isNull);
    });

    test(
      'B signs in after A validated but before the send: no request',
      () async {
        final coordinator = coordinatorWith(
          OnboardingRemoteDataSourceImpl(client),
        );
        coordinator.handle(_validated(pendingProfile));
        await coordinator.settled;
        await seedPendingA();
        firebase.session = _sessionB;

        await coordinator.requestSync();
        await coordinator.settled;

        expect(authorizations, isEmpty);
        expect(storage.onboardingPendingFor('uid-A'), isNotNull);
      },
    );

    test('expectedOwner blocks A\'s request under B\'s session', () async {
      firebase.session = _sessionB;
      final remote = OnboardingRemoteDataSourceImpl(client);

      await expectLater(
        remote.markOnboarding(expectedOwner: 'uid-A', outcome: 'COMPLETED'),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(authorizations, isEmpty);
    });

    test('request body: outcome present, or omitted for self-repair', () async {
      final bodies = <Object?>[];
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            bodies.add('${options.method} ${options.uri.path}');
            bodies.add(options.data);
            handler.next(options);
          },
        ),
      );
      final remote = OnboardingRemoteDataSourceImpl(client);

      await remote.markOnboarding(expectedOwner: 'uid-A', outcome: 'SKIPPED');
      await remote.markOnboarding(expectedOwner: 'uid-A');

      expect(bodies, [
        'POST /api/v1/profile/me/onboarding',
        {'outcome': 'SKIPPED'},
        'POST /api/v1/profile/me/onboarding',
        <String, Object?>{},
      ]);
    });
  });
}
