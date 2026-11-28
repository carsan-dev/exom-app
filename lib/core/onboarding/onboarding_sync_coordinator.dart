import 'dart:async';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/onboarding/onboarding_resolver.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/onboarding/data/onboarding_remote_datasource.dart';
import 'package:flutter/foundation.dart';

/// Applies the resolver effects and sends the pending onboarding mark of the
/// current identity (OP-D7, OP-D15, OP-D17).
///
/// It receives every [AuthState] change. Effects and sends only happen for a
/// server-validated [AuthAuthenticated] whose Firebase session is still the
/// one that was current when the state arrived. The send runs inside
/// [LocalStorage.sessionTask] and carries `exom.auth.expectedOwner`, so a
/// session switch before or during the request aborts it and keeps the entry.
///
/// Outcome: 2xx deletes the pending entry; any error (401, 403, 404, 423,
/// 5xx, other 4xx, network, session change) keeps it. There is at most one
/// automatic attempt per validated session plus one per [requestSync], and a
/// single request in flight per identity.
class OnboardingSyncCoordinator {
  OnboardingSyncCoordinator({
    required LocalStorage storage,
    required LocalAuthSession? Function() currentSession,
    required OnboardingRemoteDataSource remote,
  }) : _storage = storage,
       _currentSession = currentSession,
       _remote = remote;

  final LocalStorage _storage;
  final LocalAuthSession? Function() _currentSession;
  final OnboardingRemoteDataSource _remote;

  _ValidatedClient? _validated;
  final Set<String> _attemptedSessions = {};
  final Map<String, _InFlightSend> _inFlight = {};
  final Set<Future<void>> _work = {};

  /// Completes when every effect and send started so far has finished.
  Future<void> get settled async {
    while (_work.isNotEmpty) {
      await Future.wait(_work.toList());
    }
  }

  void handle(AuthState state) {
    final session = _currentSession();
    if (state is! AuthAuthenticated ||
        !state.user.isServerValidated ||
        session == null) {
      _validated = null;
      return;
    }
    final validated = _ValidatedClient(
      uid: session.uid,
      email: session.email,
      generation: session.generation,
      isClient: state.user.isClient,
    );
    _validated = validated;

    final resolution = resolveOnboarding(
      user: state.user,
      localDone: _storage.isOnboardingLocallyDone(
        uid: session.uid,
        email: session.email,
      ),
      hasPending: _storage.onboardingPendingFor(session.uid) != null,
    );
    _track(_apply(validated, resolution));
  }

  /// One extra attempt after the user submits or skips the onboarding.
  Future<void> requestSync() {
    final validated = _currentValidated();
    if (validated == null || !validated.isClient) return Future<void>.value();
    return _track(_send(validated));
  }

  _ValidatedClient? _currentValidated() {
    final validated = _validated;
    final session = _currentSession();
    if (validated == null ||
        session == null ||
        session.uid != validated.uid ||
        session.generation != validated.generation) {
      return null;
    }
    return validated;
  }

  Future<void> _apply(
    _ValidatedClient validated,
    OnboardingResolution resolution,
  ) async {
    try {
      final writes = <Future<void>>[
        if (resolution.writeLocalCache)
          _storage.cacheServerOnboardingDone(
            uid: validated.uid,
            email: validated.email,
          ),
        if (resolution.clearPending)
          _storage.clearOnboardingPending(validated.uid),
        if (resolution.registerRepair)
          _storage.registerOnboardingRepair(validated.uid),
      ];
      await Future.wait(writes);
    } catch (error) {
      _log('local effects failed (${error.runtimeType})');
      return;
    }

    if (!resolution.sendPending || !validated.isClient) return;
    if (!_attemptedSessions.add(validated.sessionKey)) return;
    await _send(validated);
  }

  Future<void> _send(_ValidatedClient validated) {
    final running = _inFlight[validated.uid];
    if (running != null && running.sessionKey == validated.sessionKey) {
      return running.future;
    }
    // A request of an older session of the same identity is still running:
    // queue behind it so there is never more than one request per identity.
    final send = running == null
        ? _sendOnce(validated)
        : running.future.then((_) => _sendOnce(validated));
    final entry = _InFlightSend(validated.sessionKey, send);
    _inFlight[validated.uid] = entry;
    return send.whenComplete(() {
      if (identical(_inFlight[validated.uid], entry)) {
        _inFlight.remove(validated.uid);
      }
    });
  }

  Future<void> _sendOnce(_ValidatedClient validated) async {
    try {
      final current = _currentValidated();
      if (current == null ||
          current.sessionKey != validated.sessionKey ||
          !current.isClient) {
        return;
      }
      final pending = _storage.onboardingPendingFor(validated.uid);
      if (pending == null) return;
      final outcome = pending['outcome'];
      await _storage.sessionTask(() async {
        await _remote.markOnboarding(
          expectedOwner: validated.uid,
          outcome: outcome is String ? outcome : null,
        );
        // The server answered 2xx for this owner: the entry is settled.
        await _storage.clearOnboardingPending(validated.uid);
      });
    } on LocalSessionChanged {
      _log('send aborted: session changed');
    } catch (error) {
      final status = ApiException.maybeFrom(error)?.statusCode;
      _log('send kept pending (status ${status ?? error.runtimeType})');
    }
  }

  Future<void> _track(Future<void> work) {
    _work.add(work);
    work.whenComplete(() => _work.remove(work));
    return work;
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[ONBOARDING_SYNC] $message');
  }
}

class _InFlightSend {
  const _InFlightSend(this.sessionKey, this.future);

  final String sessionKey;
  final Future<void> future;
}

class _ValidatedClient {
  const _ValidatedClient({
    required this.uid,
    required this.email,
    required this.generation,
    required this.isClient,
  });

  final String uid;
  final String? email;
  final int generation;
  final bool isClient;

  String get sessionKey => '$uid:$generation';
}
