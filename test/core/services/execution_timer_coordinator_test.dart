import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.exommethod.exom/execution_timer');
  final calls = <MethodCall>[];
  var now = DateTime(2026, 10, 10);
  setUp(() {
    calls.clear();
    now = DateTime(2026, 10, 10);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'actual remaining deadline, mute, duplicate suppression and exact cancellation',
    () async {
      final coordinator = ExecutionTimerCoordinator(
        now: () => now,
        soundEnabled: () => false,
      );
      final deadline = now.add(const Duration(seconds: 45));
      await coordinator.start(key: 'set-1', deadline: deadline);
      await coordinator.start(key: 'set-1', deadline: deadline);
      expect(calls.length, 1);
      final arguments = calls.single.arguments as Map;
      expect(arguments['endsAtMillis'], deadline.millisecondsSinceEpoch);
      expect(arguments['durationSeconds'], 45);
      expect(arguments['soundEnabled'], false);
      expect(arguments.containsKey('exerciseName'), false);
      await coordinator.cancel('another-set');
      expect(calls.length, 1);
      await coordinator.cancel('set-1');
      expect(calls.last.method, 'cancel');
      expect((calls.last.arguments as Map)['id'], arguments['id']);
    },
  );

  test(
    'expired historical timer never schedules or replays Dart audio',
    () async {
      final coordinator = ExecutionTimerCoordinator(now: () => now);
      await coordinator.start(key: 'expired', deadline: now);
      await coordinator.start(
        key: 'expired',
        deadline: now.subtract(const Duration(seconds: 1)),
      );
      expect(calls, isEmpty);
      await coordinator.start(
        key: 'current',
        deadline: now.add(const Duration(seconds: 1)),
      );
      now = now.add(const Duration(seconds: 2));
      expect(calls.map((call) => call.method), ['start']);
    },
  );

  test('replacement and stale cancel cannot cancel the new round', () async {
    final coordinator = ExecutionTimerCoordinator(now: () => now);
    await coordinator.start(
      key: ('exercise', 1),
      deadline: now.add(const Duration(seconds: 10)),
    );
    await coordinator.start(
      key: ('exercise', 2),
      deadline: now.add(const Duration(seconds: 20)),
    );
    await coordinator.cancel(('exercise', 1));
    expect(calls.map((call) => call.method), ['start', 'cancel', 'start']);
    expect(
      (calls[0].arguments as Map)['id'],
      isNot((calls[2].arguments as Map)['id']),
    );
  });

  test(
    'in-flight start is serialized before session invalidation and next start',
    () async {
      final accepted = Completer<void>();
      final release = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (calls.length == 1) {
              accepted.complete();
              await release.future;
            }
            return null;
          });
      final coordinator = ExecutionTimerCoordinator(now: () => now)
        ..updateOwner('owner-1');
      final first = coordinator.start(
        key: 'first',
        deadline: now.add(const Duration(seconds: 10)),
      );
      await accepted.future;
      coordinator.updateOwner('owner-2');
      final second = coordinator.start(
        key: 'second',
        deadline: now.add(const Duration(seconds: 20)),
      );
      expect(calls.length, 1);
      release.complete();
      await first;
      await second;
      expect(calls.map((call) => call.method), ['start', 'cancel', 'start']);
      expect(
        (calls[1].arguments as Map)['id'],
        (calls[0].arguments as Map)['id'],
      );
    },
  );

  test('execution cancellation never invokes the rest channel', () async {
    const restChannel = MethodChannel('com.exommethod.exom/rest_timer');
    final restCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(restChannel, (call) async {
          restCalls.add(call);
          return null;
        });
    final rest = PlatformRestTimerCoordinator();
    await rest.start(
      RestTimerSession(
        id: 'rest',
        exerciseName: 'Rest',
        durationSeconds: 30,
        endsAt: now.add(const Duration(seconds: 30)),
      ),
    );
    final before = restCalls.length;
    final execution = ExecutionTimerCoordinator(now: () => now);
    await execution.start(
      key: 'exercise',
      deadline: now.add(const Duration(seconds: 10)),
    );
    await execution.cancel('exercise');
    expect(restCalls.length, before);
    expect(rest.activeSession?.id, 'rest');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(restChannel, null);
  });
}
