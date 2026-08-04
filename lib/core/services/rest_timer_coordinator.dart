import 'package:flutter/services.dart';

class RestTimerSession {
  final String id;
  final String exerciseName;
  final int durationSeconds;
  final DateTime endsAt;

  const RestTimerSession({
    required this.id,
    required this.exerciseName,
    required this.durationSeconds,
    required this.endsAt,
  });

  Map<String, Object> toMap() => {
    'id': id,
    'exerciseName': exerciseName,
    'durationSeconds': durationSeconds,
    'endsAtMillis': endsAt.millisecondsSinceEpoch,
  };
}

abstract class RestTimerCoordinator {
  RestTimerSession? get activeSession;

  Future<void> start(RestTimerSession session);
  Future<void> cancel();
}

class PlatformRestTimerCoordinator implements RestTimerCoordinator {
  static const MethodChannel _channel = MethodChannel(
    'com.exommethod.exom/rest_timer',
  );

  RestTimerSession? _activeSession;

  @override
  RestTimerSession? get activeSession => _activeSession;

  @override
  Future<void> start(RestTimerSession session) async {
    if (_activeSession?.id != session.id) {
      await cancel();
    }
    _activeSession = session;
    try {
      await _channel.invokeMethod<void>('start', session.toMap());
    } on MissingPluginException {
      // Unit tests and unsupported platforms keep internal countdown working.
    } on PlatformException {
      // Notification denial/failure must never stop workout progression.
    }
  }

  @override
  Future<void> cancel() async {
    _activeSession = null;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // No native integration on this platform.
    } on PlatformException {
      // Native cancellation failure does not affect internal state.
    }
  }
}
