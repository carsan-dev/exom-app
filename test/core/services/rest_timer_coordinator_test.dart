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

  test('starts, replaces and cancels one active session', () async {
    final coordinator = PlatformRestTimerCoordinator();
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
    await coordinator.start(second);
    expect(coordinator.activeSession, same(second));
    await coordinator.cancel();

    expect(coordinator.activeSession, isNull);
    expect(calls.map((call) => call.method), [
      'cancel',
      'start',
      'cancel',
      'start',
      'cancel',
    ]);
  });
}
