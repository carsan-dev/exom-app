import 'dart:async';
import 'package:exom_app/core/utils/operation_id.dart';
import 'package:flutter/services.dart';

/// Native notifications own expiry audio, including while Flutter is suspended.
class ExecutionTimerCoordinator {
  ExecutionTimerCoordinator({
    MethodChannel? channel,
    bool Function()? soundEnabled,
    DateTime Function()? now,
    bool Function()? isAuthorized,
  }) : _channel =
           channel ??
           const MethodChannel('com.exommethod.exom/execution_timer'),
       _soundEnabled = soundEnabled ?? (() => true),
       _now = now ?? DateTime.now,
       _isAuthorized = isAuthorized ?? (() => true);

  final MethodChannel _channel;
  final bool Function() _soundEnabled;
  final DateTime Function() _now;
  final bool Function() _isAuthorized;
  Future<void> _tail = Future<void>.value();
  Object? _key;
  DateTime? _deadline;
  String? _id;
  String? _owner;
  int _generation = 0;
  int _sessionRevision = 0;
  int get sessionRevision => _sessionRevision;

  void updateOwner(String? owner) {
    if (_owner == owner) return;
    _owner = owner;
    _sessionRevision++;
    final id = _id;
    _generation++;
    _key = null;
    _deadline = null;
    _id = null;
    if (id != null) unawaited(_enqueue(() => _invoke('cancel', {'id': id})));
  }

  Future<void> start({required Object key, required DateTime deadline}) {
    if (!_isAuthorized() || !deadline.isAfter(_now())) {
      return Future<void>.value();
    }
    if (_key == key && _deadline == deadline) return Future<void>.value();
    final prior = _id;
    final generation = ++_generation;
    final id = 'execution-$generation-${newOperationId()}';
    _key = key;
    _deadline = deadline;
    _id = id;
    return _enqueue(() async {
      if (prior != null) await _invoke('cancel', {'id': prior});
      if (generation != _generation ||
          !_isAuthorized() ||
          !deadline.isAfter(_now())) {
        return;
      }
      await _invoke('start', {
        'id': id,
        'endsAtMillis': deadline.millisecondsSinceEpoch,
        'durationSeconds': (deadline.difference(_now()).inMilliseconds / 1000)
            .ceil(),
        'soundEnabled': _soundEnabled(),
      });
    });
  }

  Future<void> cancel(Object key) {
    if (_key != key) return Future<void>.value();
    final id = _id;
    _generation++;
    _key = null;
    _deadline = null;
    _id = null;
    return id == null
        ? Future<void>.value()
        : _enqueue(() => _invoke('cancel', {'id': id}));
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next;
    return next;
  }

  Future<void> _invoke(String method, Map<String, Object> arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Platforms without native delivery still retain the canonical timer.
    } on PlatformException {
      // Notification permissions must never prevent workout execution.
    }
  }
}
