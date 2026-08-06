import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.exommethod.exom/rest_timer');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('starts, replaces, finishes and cancels one active session', () async {
    var soundEnabled = false;
    final coordinator = PlatformRestTimerCoordinator(
      notificationSoundEnabled: () => soundEnabled,
    );
    final first = RestTimerSession(
      id: 'first',
      exerciseName: 'Press',
      durationSeconds: 30,
      endsAt: DateTime(2030),
    );
    final second = RestTimerSession(
      id: 'second',
      exerciseName: 'Squat',
      durationSeconds: 60,
      endsAt: DateTime(2030, 1, 1, 0, 1),
    );

    await coordinator.start(first);
    expect(coordinator.activeSession, same(first));
    soundEnabled = true;
    await coordinator.start(second);
    expect(coordinator.activeSession, same(second));
    await coordinator.finish();

    expect(coordinator.activeSession, isNull);
    expect(calls.map((call) => call.method), [
      'cancel',
      'start',
      'cancel',
      'start',
      'finish',
    ]);
    expect((calls[4].arguments as Map)['id'], 'second');

    await coordinator.cancel();
    expect(calls.map((call) => call.method), [
      'cancel',
      'start',
      'cancel',
      'start',
      'finish',
      'cancel',
    ]);
    expect((calls[1].arguments as Map)['soundEnabled'], false);
    expect((calls[3].arguments as Map)['soundEnabled'], true);
  });
}
