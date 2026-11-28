import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/core/services/rest_timer_session_guard.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/validated_session_gate.dart';
import 'package:exom_app/injection_container.dart';

/// Records every call to the native rest timer, in order.
class _RecordingRestTimer implements RestTimerCoordinator {
  _RecordingRestTimer({this.failCancel = false});

  final bool failCancel;
  final calls = <String>[];

  @override
  RestTimerSession? activeSession;

  @override
  Future<void> start(RestTimerSession session) async {
    activeSession = session;
    calls.add('start:${session.id}');
  }

  @override
  Future<void> finish() async {
    activeSession = null;
    calls.add('finish');
  }

  @override
  Future<void> cancel() async {
    activeSession = null;
    calls.add('cancel');
    if (failCancel) throw StateError('native cancel failed');
  }
}

/// DESCANSO-AVISO (OBS-11, «cerrar sesión»): the native rest timer has no
/// owner, so a rest left running without a valid owner would still ring
/// «Descanso terminado» on the login screen or for another account.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = UserEntity(
    id: 'owner',
    email: 'synthetic@example.invalid',
    role: 'CLIENT',
  );
  var session = const LocalAuthSession(uid: 'owner', generation: 1);
  late _RecordingRestTimer rest;

  RestTimerSession restSession() => RestTimerSession(
    id: 'training:exercise:1:0',
    exerciseName: 'Press',
    durationSeconds: 60,
    endsAt: DateTime.now().add(const Duration(minutes: 1)),
  );

  void register({bool failCancel = false}) {
    rest = _RecordingRestTimer(failCancel: failCancel);
    if (sl.isRegistered<RestTimerCoordinator>()) {
      sl.unregister<RestTimerCoordinator>();
    }
    sl.registerSingleton<RestTimerCoordinator>(rest);
  }

  setUp(() async {
    await sl.reset();
    session = const LocalAuthSession(uid: 'owner', generation: 1);
    final storage = LocalStorage(currentSession: () => session);
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerSingleton<ValidatedSessionGate>(
      ValidatedSessionGate(() => session),
    );
    sl.registerSingleton<ExecutionTimerCoordinator>(
      ExecutionTimerCoordinator()..updateOwner(storage.sessionStamp),
    );
    register();
    sl.registerLazySingleton<RestTimerSessionGuard>(
      () => RestTimerSessionGuard(() => sl<RestTimerCoordinator>()),
    );
  });

  tearDown(sl.reset);

  group('first resolution of the process', () {
    test('AuthLoading then AuthAuthenticated leaves a pending rest alone',
        () async {
      handleExecutionTimerSessionState(const AuthLoading());
      handleExecutionTimerSessionState(const AuthAuthenticated(user));
      await Future<void>.delayed(Duration.zero);
      expect(rest.calls, isEmpty);
    });

    test('AuthAuthenticated first does not cancel', () async {
      handleExecutionTimerSessionState(const AuthAuthenticated(user));
      await Future<void>.delayed(Duration.zero);
      expect(rest.calls, isEmpty);
    });

    test('AuthLoading alone (check still running) does not cancel', () async {
      handleExecutionTimerSessionState(const AuthLoading());
      handleExecutionTimerSessionState(const AuthLoading());
      await Future<void>.delayed(Duration.zero);
      expect(rest.calls, isEmpty);
    });

    for (final first in [
      const AuthUnauthenticated(),
      const AuthAccountLocked(),
    ]) {
      test('${first.runtimeType} first (401/403/423 in checkStatus) cancels '
          'once: there is no valid owner', () async {
        handleExecutionTimerSessionState(const AuthLoading());
        handleExecutionTimerSessionState(first);
        await Future<void>.delayed(Duration.zero);
        expect(rest.calls, ['cancel']);
        handleExecutionTimerSessionState(const AuthUnauthenticated());
        await Future<void>.delayed(Duration.zero);
        expect(rest.calls, ['cancel']);
      });
    }

    test('offline AuthAuthenticated then the validated one, same uid and '
        'generation, never cancels', () async {
      handleExecutionTimerSessionState(const AuthLoading());
      handleExecutionTimerSessionState(
        const AuthAuthenticated(
          UserEntity(
            id: 'owner',
            email: '',
            role: 'CLIENT',
            isServerValidated: false,
          ),
        ),
      );
      await rest.start(restSession());
      handleExecutionTimerSessionState(const AuthAuthenticated(user));
      await Future<void>.delayed(Duration.zero);
      expect(rest.calls, ['start:training:exercise:1:0']);
    });
  });

  test('revalidating the same session keeps the rest running', () async {
    handleExecutionTimerSessionState(const AuthAuthenticated(user));
    await rest.start(restSession());
    handleExecutionTimerSessionState(const AuthAuthenticated(user));
    await Future<void>.delayed(Duration.zero);
    expect(rest.calls, ['start:training:exercise:1:0']);
  });

  // In an active session AuthLoading only comes from logout or account
  // deletion (AuthBloc has no revalidation on resume:
  // test/features/auth/presentation/bloc/auth_bloc_resume_test.dart).
  for (final state in [
    const AuthLoading(),
    const AuthUnauthenticated(),
    const AuthAccountDeleted(),
  ]) {
    test('leaving the validated session (${state.runtimeType}) cancels the '
        'rest notification', () async {
      handleExecutionTimerSessionState(const AuthAuthenticated(user));
      await rest.start(restSession());
      handleExecutionTimerSessionState(state);
      await Future<void>.delayed(Duration.zero);
      expect(rest.calls, ['start:training:exercise:1:0', 'cancel']);
      // Further non-validated states do not cancel again.
      handleExecutionTimerSessionState(const AuthUnauthenticated());
      await Future<void>.delayed(Duration.zero);
      expect(rest.calls, hasLength(2));
    });
  }

  test('switching account cancels the previous account rest', () async {
    handleExecutionTimerSessionState(const AuthAuthenticated(user));
    await rest.start(restSession());
    session = const LocalAuthSession(uid: 'other', generation: 2);
    handleExecutionTimerSessionState(const AuthAuthenticated(user));
    await Future<void>.delayed(Duration.zero);
    expect(rest.calls, ['start:training:exercise:1:0', 'cancel']);
  });

  test('a failing native cancel is not left as an uncaught error', () async {
    register(failCancel: true);
    handleExecutionTimerSessionState(const AuthAuthenticated(user));
    handleExecutionTimerSessionState(const AuthUnauthenticated());
    await Future<void>.delayed(Duration.zero);
    expect(rest.calls, ['cancel']);
  });

  test('sl.reset clears the guard: a new process starts unresolved', () async {
    handleExecutionTimerSessionState(const AuthAuthenticated(user));
    await sl.reset();
    sl.registerSingleton<LocalStorage>(
      LocalStorage(currentSession: () => session),
    );
    sl.registerSingleton<ValidatedSessionGate>(
      ValidatedSessionGate(() => session),
    );
    sl.registerSingleton<ExecutionTimerCoordinator>(ExecutionTimerCoordinator());
    register();
    sl.registerLazySingleton<RestTimerSessionGuard>(
      () => RestTimerSessionGuard(() => sl<RestTimerCoordinator>()),
    );
    handleExecutionTimerSessionState(const AuthLoading());
    await Future<void>.delayed(Duration.zero);
    expect(rest.calls, isEmpty);
  });
}
