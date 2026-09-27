import 'dart:async';
import 'dart:convert';
import 'store_process_lock.dart';
import 'package:path_provider/path_provider.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/core/utils/operation_id.dart';

class LocalStorage implements ActiveWorkoutLocalStore {
  LocalStorage({
    LocalAuthSession? Function()? currentSession,
    String environment = 'test',
  }) : _currentSession = currentSession,
       _environment = environment;
  final LocalAuthSession? Function()? _currentSession;
  final String _environment;
  // Production always injects Firebase identity. Unscoped mode is for isolated
  // stores/tests only; it must never adopt legacy data into a live account.
  String? get ownerId => _currentSession?.call()?.uid;
  String get environment => _environment;
  String? get sessionStamp {
    if (_currentSession == null) return 'isolated';
    final session = _currentSession();
    return session == null
        ? null
        : '${session.uid}:${session.generation}:$_environment';
  }

  static final Object _sessionZone = Object();
  // Shared by all store instances using this process's Hive boxes.
  static final Map<String, Future<void>> _legacyRecoveryLocks = {};
  static final Object _authSessionZone = Object();
  static String? get requestSessionKey =>
      Zone.current[_authSessionZone] as String?;
  Future<T> sessionTask<T>(Future<T> Function() action) {
    final session = _currentSession?.call();
    final authKey = session == null
        ? null
        : '${session.uid}:${session.generation}';
    final expected = Zone.current[_sessionZone] ?? sessionStamp ?? 'signed-out';
    return runZoned(
      () async {
        guardSession();
        final result = await action();
        guardSession();
        return result;
      },
      zoneValues: {
        _sessionZone: expected,
        _authSessionZone: requestSessionKey ?? authKey,
      },
    );
  }

  void guardSession() {
    final expected = Zone.current[_sessionZone];
    if (expected != null && expected != sessionStamp) {
      throw const LocalSessionChanged();
    }
  }

  Future<void> withSession(Future<void> Function() action) async {
    try {
      await sessionTask(action);
    } on LocalSessionChanged {
      // Old work stays persisted in its owner's namespace for later recovery.
    }
  }

  String _key(String key) {
    guardSession();
    if (_currentSession == null) return key;
    final uid = ownerId;
    final scope = base64Url.encode(
      utf8.encode(jsonEncode([_environment, uid])),
    );
    return 'v2:$scope:$key';
  }

  Map<String, Object?> get queueIdentity => {
    'format_version': 2,
    'owner_id': ownerId,
    'environment': _environment,
  };
  bool ownsEntry(Map<String, dynamic> item) =>
      _currentSession == null ||
      (ownerId != null &&
          item['owner_id'] == ownerId &&
          item['environment'] == _environment &&
          item['format_version'] == 2);
  // Legacy keys remain untouched, inaccessible to current-session consumers.
  // Recovery requires explicit ownership verification; logging in is insufficient.
  bool get hasUnattributedData =>
      _cache.containsKey(_pendingSyncKey) ||
      _cache.containsKey(_feedbackUploadQueueKey) ||
      _cache.containsKey(_progressPhotoUploadQueueKey);

  static const _authBox = 'auth_box';
  static const _cacheBox = 'cache_box';
  static const _settingsBox = 'settings_box';
  static const _activeWorkoutBox = 'active_workout_box';
  static const _pendingSyncKey = 'offline_sync_actions';
  static const _trainingExecutionsKey = 'training_executions';
  static const _completionDraftsKey = 'training_completion_drafts';
  static const _feedbackUploadQueueKey = 'feedback_upload_queue';
  static const _progressPhotoUploadQueueKey = 'progress_photo_upload_queue';
  static const _progressPhotoPickerIntentKey = 'progress_photo_picker_intent';
  static const _themeModeKey = 'theme_mode';
  static const _localeKey = 'locale';
  static const _unitSystemKey = 'unit_system';
  static const _restTimerSoundEnabledKey = 'rest_timer_sound_enabled';
  static const _legacyOnboardingCompleteKey = 'onboarding_complete';
  static const _onboardingIdentityKey = 'onboarding_complete_identity';
  static const _tutorialCompleteKey = 'tutorial_complete';

  // A process owns the Hive store for its lifetime. A second process fails
  // before opening cached boxes; a crash releases the OS lock automatically.
  static StoreProcessLock? _processLock;
  static Future<void> init() async {
    if (_processLock != null) return;
    final directory = await getApplicationDocumentsDirectory();
    _processLock = await StoreProcessLock.acquire(directory);
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
      Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
    }
    await Future.wait([
      Hive.openBox(_authBox),
      Hive.openBox(_cacheBox),
      Hive.openBox(_settingsBox),
      Hive.openBox<ActiveWorkoutHiveModel>(_activeWorkoutBox),
    ]);
  }

  // Auth
  static Box get _auth => Hive.box(_authBox);
  static Box get _cache => Hive.box(_cacheBox);
  static Box get _settings => Hive.box(_settingsBox);
  static Box<ActiveWorkoutHiveModel> get _activeWorkouts =>
      Hive.box<ActiveWorkoutHiveModel>(_activeWorkoutBox);

  Future<void> saveAuthToken(String token) => _auth.put('token', token);

  String? getAuthToken() => _auth.get('token');

  Future<void> clearAuth() => _auth.clear();

  Future<void> clearSessionData() async {
    await clearAuth();
  }

  // An acknowledged execution remains final. Until then the durable, owned
  // completion action is authoritative across a crash between queue and registry writes.
  Map<String, dynamic> _effectiveTrainingExecution(
      Map<String, dynamic> entry, List<Map<String, dynamic>> actions) {
    if (const ['confirmed', 'completed'].contains(entry['status'])) return entry;
    final matches = actions.where((action) =>
        action['type'] == 'complete_training' &&
        action['training_session_id'] == entry['id'] &&
        entry['id'] is String && (entry['id'] as String).isNotEmpty &&
        action['training_id'] == entry['training_id'] &&
        action['date'] == entry['assignment_date']);
    if (matches.any((action) => action['last_error'] ==
        'progress_conflict_review_required')) {
      return {...entry, 'status': 'conflict'};
    }
    if (matches.any((action) =>
        const ['queued', 'uploading'].contains(action['status']))) {
      return {...entry, 'status': 'pending-sync'};
    }
    if (matches.any((action) => action['status'] == 'failed')) {
      return {...entry, 'status': 'failed'};
    }
    return entry;
  }

  // Execution registry is owner-scoped and never reconstructed from a retry.
  List<Map<String, dynamic>> getTrainingExecutions(String trainingId, String date) {
    final actions = getPendingSyncActions();
    final registered = (getCachedList(_trainingExecutionsKey) ?? const [])
        .whereType<Map>()
        .map((entry) => _effectiveTrainingExecution(
            Map<String, dynamic>.from(entry), actions))
        .where((entry) => entry['training_id'] == trainingId &&
            entry['assignment_date'] == date &&
            const ['pending', 'pending-finalize', 'failed', 'conflict']
                .contains(entry['status']))
        .toList();
    final recordedIds = (getCachedList(_trainingExecutionsKey) ?? const [])
        .whereType<Map>()
        .map((entry) => entry['id'])
        .toSet();
    // Recover drafts written by the earlier date-keyed schema even if the
    // registry was never populated. Never adopt an unbound legacy draft.
    for (final draft in getActiveWorkouts()) {
      final id = draft.sessionId;
      if (draft.trainingId == trainingId && id != null &&
          (draft.exerciseId.endsWith(':$date') ||
           draft.exerciseId.endsWith(':$date:$id')) &&
          !recordedIds.contains(id) &&
          !registered.any((entry) => entry['id'] == id)) {
        registered.add({
          'id': id, 'training_id': trainingId,
          'assignment_date': date, 'status': 'pending',
        });
      }
    }
    return registered;
  }

  // Only entries in the current owner/environment namespace are visible.
  // The registry retains pending-sync entries even when their date is no longer
  // displayed; unbound legacy data is deliberately not adopted here.
  List<Map<String, dynamic>> getPendingTrainingExecutions() {
    if (_currentSession != null && ownerId == null) return [];
    final actions = getPendingSyncActions();
    final entries = (getCachedList(_trainingExecutionsKey) ?? const [])
        .whereType<Map>()
        .map((entry) => _effectiveTrainingExecution(
            Map<String, dynamic>.from(entry), actions))
        .where((entry) =>
            entry['id'] is String && (entry['id'] as String).isNotEmpty &&
            entry['training_id'] is String &&
            entry['assignment_date'] is String &&
            const ['pending', 'pending-finalize', 'pending-sync', 'failed', 'conflict']
                .contains(entry['status']))
        .toList();
    final registered = (getCachedList(_trainingExecutionsKey) ?? const [])
        .whereType<Map>().map((entry) => entry['id']).toSet();
    // Recover only drafts with a verifiable date/session suffix in this scope.
    for (final draft in getActiveWorkouts()) {
      final id = draft.sessionId;
      if (id == null || registered.contains(id)) continue;
      final match = RegExp(r':(\d{4}-\d{2}-\d{2}):').firstMatch('${draft.exerciseId}:');
      if (match == null ||
          !draft.exerciseId.endsWith(':${match.group(1)}') &&
          !draft.exerciseId.endsWith(':${match.group(1)}:$id')) {
        continue;
      }
      entries.add({
        'id': id, 'training_id': draft.trainingId,
        'assignment_date': match.group(1), 'status': 'pending',
      });
      registered.add(id);
    }
    return entries;
  }

  // Display-only: acknowledged executions stay in the scoped registry, but
  // must never re-enter the pending execution selector used for writes.
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(
      String trainingId, String date) {
    if (_currentSession != null && ownerId == null) return [];
    return (getCachedList(_trainingExecutionsKey) ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((entry) =>
            entry['id'] is String && (entry['id'] as String).isNotEmpty &&
            entry['training_id'] == trainingId &&
            entry['assignment_date'] == date &&
            const ['confirmed', 'completed'].contains(entry['status']))
        .toList();
  }

  bool hasCompletedTrainingExecution(String trainingId, String date) =>
      (getCachedList(_trainingExecutionsKey) ?? const []).whereType<Map>().any(
        (entry) => entry['training_id'] == trainingId &&
            entry['assignment_date'] == date &&
            const ['completed', 'confirmed'].contains(entry['status']));

  Future<String> createTrainingExecution(String trainingId, String date,
      {String? trainingName}) =>
      sessionTask(() async {
        final id = newOperationId();
        final executions = List<dynamic>.from(
          getCachedList(_trainingExecutionsKey) ?? const [],
        );
        executions.add({
          'id': id,
          'training_id': trainingId,
          'assignment_date': date,
          'training_name': ?trainingName,
          'status': 'pending-finalize',
        });
        await cacheData(_trainingExecutionsKey, executions);
        return id;
      });

  Map<String, dynamic>? getTrainingCompletionDraft(
      String trainingId, String date, String executionId) {
    final draft = getCachedMap(_completionDraftsKey)?[executionId];
    if (draft is! Map || draft['training_id'] != trainingId ||
        draft['assignment_date'] != date) {
      return null;
    }
    return Map<String, dynamic>.from(draft);
  }

  Future<void> saveTrainingCompletionDraft(String trainingId, String date,
      String executionId, {int? rpe, String? notes}) => sessionTask(() async {
    if (rpe != null && (rpe < 1 || rpe > 10)) {
      throw RangeError.range(rpe, 1, 10, 'rpe');
    }
    final drafts = getCachedMap(_completionDraftsKey) ?? <String, dynamic>{};
    drafts[executionId] = {
      if (drafts[executionId] is Map &&
          (drafts[executionId] as Map)['discarded_action'] != null)
        'discarded_action': (drafts[executionId] as Map)['discarded_action'],
      'training_id': trainingId,
      'assignment_date': date,
      'rpe': ?rpe,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    await cacheData(_completionDraftsKey, drafts);
  });

  Future<void> preserveDiscardedTrainingCompletion(Map<String, dynamic> action) =>
      sessionTask(() async {
        final id = action['training_session_id'] as String?;
        final trainingId = action['training_id'] as String?;
        final date = action['date'] as String?;
        if (id == null || trainingId == null || date == null) return;
        final drafts = getCachedMap(_completionDraftsKey) ?? <String, dynamic>{};
        drafts[id] = {
          'training_id': trainingId,
          'assignment_date': date,
          if (action['rpe'] != null) 'rpe': action['rpe'],
          if (action['notes'] != null) 'notes': action['notes'],
          'discarded_action': Map<String, dynamic>.from(action),
        };
        await cacheData(_completionDraftsKey, drafts);
      });

  Future<void> setTrainingExecutionStatus(String id, String status) =>
      sessionTask(() async {
        if (!const ['pending-finalize', 'pending-sync', 'failed', 'conflict',
          'confirmed'].contains(status)) {
          throw ArgumentError.value(status, 'status');
        }
        final executions = (getCachedList(_trainingExecutionsKey) ?? const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
        for (final entry in executions) {
          if (entry['id'] == id &&
              entry['status'] != 'confirmed') {
            entry['status'] = status;
            await cacheData(_trainingExecutionsKey, executions);
            return;
          }
        }
        // A legacy execution may have a draft but no registry row.
        if (status == 'confirmed') {
          executions.add({'id': id, 'status': status});
          await cacheData(_trainingExecutionsKey, executions);
        }
      });

  Future<void> completeTrainingExecution(String id) => sessionTask(() async {
    await setTrainingExecutionStatus(id, 'confirmed');
    final drafts = getCachedMap(_completionDraftsKey) ?? <String, dynamic>{};
    drafts.remove(id);
    await cacheData(_completionDraftsKey, drafts);
  });

  // Cache
  Future<void> cacheData(String key, dynamic value) =>
      _cache.put(_key(key), value);

  T? getCachedData<T>(String key) => _cache.get(_key(key)) as T?;

  dynamic getCachedValue(String key) => _normalize(_cache.get(_key(key)));

  Map<String, dynamic>? getCachedMap(String key) {
    final value = getCachedValue(key);
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List<dynamic>? getCachedList(String key) {
    final value = getCachedValue(key);
    if (value is List<dynamic>) {
      return value;
    }
    if (value is List) {
      return List<dynamic>.from(value);
    }
    return null;
  }

  Future<void> removeCachedData(String key) => _cache.delete(_key(key));

  Future<void> clearCache() async {
    final prefix = _key('');
    final preserved = {
      _key(_pendingSyncKey),
      _key(_trainingExecutionsKey),
      _key(_completionDraftsKey),
      _key(_feedbackUploadQueueKey),
      _key(_progressPhotoUploadQueueKey),
    };
    // Cache clearing never discards queues, evidence or active workouts.
    final keys = _cache.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix) && !preserved.contains(key))
        .toList();
    await _cache.deleteAll(keys);
  }

  List<Map<String, dynamic>> getPendingSyncActions() {
    final actions = getCachedList(_pendingSyncKey);
    if (actions == null) {
      return <Map<String, dynamic>>[];
    }

    return actions
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where(ownsEntry)
        .toList(growable: true);
  }

  Future<void> savePendingSyncActions(List<Map<String, dynamic>> actions) =>
      _saveQueue(_pendingSyncKey, actions);

  Future<void> clearPendingSyncActions() => _saveQueue(_pendingSyncKey, []);

  List<Map<String, dynamic>> getFeedbackUploadQueue() {
    return (getCachedList(_feedbackUploadQueueKey) ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where(ownsEntry)
        .toList(growable: true);
  }

  Future<void> saveFeedbackUploadQueue(List<Map<String, dynamic>> queue) =>
      _saveQueue(_feedbackUploadQueueKey, queue);

  /// Progress-photo evidence has an independent versioned format. Unknown,
  /// foreign and unattributed records remain in Hive but are never adopted.
  Map<String, Object?> get progressPhotoQueueIdentity => {
    'format_version': 1,
    'owner_id': ownerId,
    'environment': _environment,
  };

  bool ownsProgressPhotoQueueEntry(Map<String, dynamic> item) =>
      _currentSession == null ||
      (ownerId != null &&
          item['owner_id'] == ownerId &&
          item['environment'] == _environment &&
          item['format_version'] == 1);

  List<Map<String, dynamic>> getProgressPhotoUploadQueue() {
    return (getCachedList(_progressPhotoUploadQueueKey) ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where(ownsProgressPhotoQueueEntry)
        .toList(growable: true);
  }

  Future<void> saveProgressPhotoUploadQueue(
    List<Map<String, dynamic>> queue,
  ) => _saveQueueFor(
    _progressPhotoUploadQueueKey,
    queue,
    ownsProgressPhotoQueueEntry,
  );

  /// Android picker recovery is deliberately isolated from upload queue data.
  /// The record can only be read in the same owner/environment/version scope.
  Future<void> saveProgressPhotoPickerIntent(Map<String, dynamic> intent) async {
    final session = sessionStamp;
    if (session == null) throw const LocalSessionChanged();
    await saveSetting(_progressPhotoPickerIntentStorageKey(), {
      ...intent,
      'format_version': 1,
      'owner_id': ownerId,
      'environment': environment,
      'session_stamp': session,
    });
    guardSession();
  }

  Map<String, dynamic>? getProgressPhotoPickerIntent() {
    final value = getSetting<dynamic>(_progressPhotoPickerIntentStorageKey());
    if (value is! Map) return null;
    final intent = Map<String, dynamic>.from(value);
    return intent['format_version'] == 1 &&
            intent['owner_id'] == ownerId &&
            intent['environment'] == environment
        ? intent
        : null;
  }

  Future<void> clearProgressPhotoPickerIntent() =>
      _settings.delete(_progressPhotoPickerIntentStorageKey());

  String _progressPhotoPickerIntentStorageKey() {
    final scope = base64Url.encode(utf8.encode(jsonEncode([1, environment, ownerId])));
    return '$_progressPhotoPickerIntentKey:$scope';
  }

  Future<void> _saveQueue(String key, List<Map<String, dynamic>> entries) =>
      _saveQueueFor(key, entries, ownsEntry);

  Future<void> _saveQueueFor(
    String key,
    List<Map<String, dynamic>> entries,
    bool Function(Map<String, dynamic>) owns,
  ) {
    final quarantined = (getCachedList(key) ?? const []).where(
      (entry) => entry is! Map<String, dynamic> || !owns(entry),
    );
    return _cache.put(_key(key), [...quarantined, ...entries]);
  }

  ActiveWorkoutLocalStore bindActiveWorkoutStore() =>
      _SessionWorkoutStore(this, sessionStamp);

  // Legacy workouts have no owner field. Only a v2 key written in the
  // authenticated owner/environment namespace can prove their provenance.
  ActiveWorkoutHiveModel? recoverableLegacyWorkout(
    String trainingId, String exerciseId, String date,
  ) {
    if (ownerId == null || sessionStamp == null) return null;
    final key = '$exerciseId:$date';
    final draft = getActiveWorkout(key);
    return draft != null && draft.exerciseId == key &&
            draft.trainingId == trainingId && draft.sessionId == null
        ? draft
        : null;
  }

  bool get hasQuarantinedWorkoutDrafts {
    final prefix = _key('');
    return _activeWorkouts.keys.whereType<String>().any((key) =>
        !key.startsWith('v2:') ||
        (key.startsWith(prefix) &&
            _activeWorkouts.get(key)?.sessionId == null &&
            !_activeWorkouts.get(key)!.exerciseId.contains(':')));
  }

  Future<String> recoverLegacyWorkout(
    String trainingId, String exerciseId, String date,
  ) => sessionTask(() async {
    final recoveryKey = '$exerciseId:$date';
    final scopedKey = _key(recoveryKey);
    final previous = _legacyRecoveryLocks[scopedKey];
    final release = Completer<void>();
    final tail = release.future;
    _legacyRecoveryLocks[scopedKey] = tail;
    try {
      if (previous != null) await previous;
      guardSession();
      final draft = recoverableLegacyWorkout(trainingId, exerciseId, date);
      final executions = List<dynamic>.from(
        getCachedList(_trainingExecutionsKey) ?? const [],
      );
      final existing = executions.whereType<Map>().where((entry) =>
          entry['legacy_draft_key'] == recoveryKey &&
          entry['training_id'] == trainingId &&
          entry['assignment_date'] == date).toList();
      final id = existing.isEmpty ? null : existing.first['id'] as String;
      if (draft == null) {
        if (id != null && getActiveWorkout('$recoveryKey:$id') != null) return id;
        throw StateError('Legacy workout cannot be attributed');
      }
      final executionId = id ?? newOperationId();
      if (id == null) {
        executions.add({
          'id': executionId, 'training_id': trainingId,
          'assignment_date': date, 'status': 'pending',
          'legacy_draft_key': recoveryKey,
        });
        await cacheData(_trainingExecutionsKey, executions);
      }
      guardSession();
      final target = '$recoveryKey:$executionId';
      // Write first. A retry after a crash resumes the same execution without
      // replacing its potentially newer draft or deleting the older evidence.
      if (getActiveWorkout(target) != null) return executionId;
      await saveActiveWorkout(draft.copyWith(exerciseId: target, sessionId: executionId));
      guardSession();
      await removeActiveWorkout(draft.exerciseId);
      guardSession();
      return executionId;
    } finally {
      if (identical(_legacyRecoveryLocks[scopedKey], tail)) {
        _legacyRecoveryLocks.remove(scopedKey);
      }
      release.complete();
    }
  });

  // Active workout
  ValueListenable<Box<ActiveWorkoutHiveModel>> watchActiveWorkouts() =>
      _activeWorkouts.listenable();

  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) =>
      _activeWorkouts.get(_key(exerciseId));

  List<ActiveWorkoutHiveModel> getActiveWorkouts() => _activeWorkouts.keys
      .whereType<String>()
      .where((key) => key.startsWith(_key('')))
      .map((key) => _activeWorkouts.get(key)!)
      .toList(growable: false);

  List<ActiveWorkoutHiveModel> getForeignActiveWorkouts(String trainingId) {
    return getActiveWorkouts()
        .where((entry) => entry.trainingId != trainingId)
        .toList(growable: false);
  }

  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel workout) =>
      _activeWorkouts.put(_key(workout.exerciseId), workout);

  @override
  Future<void> removeActiveWorkout(String exerciseId) =>
      _activeWorkouts.delete(_key(exerciseId));

  Future<void> clearForeignActiveWorkouts(String trainingId) async {
    final keys = getActiveWorkouts()
        .where((entry) => entry.trainingId != trainingId)
        .map((entry) => _key(entry.exerciseId))
        .toList(growable: false);
    if (keys.isEmpty) return;
    await _activeWorkouts.deleteAll(keys);
  }

  // Settings
  Future<void> saveSetting(String key, dynamic value) =>
      _settings.put(key, value);

  T? getSetting<T>(String key, {T? defaultValue}) =>
      (_settings.get(key) as T?) ?? defaultValue;

  Future<void> saveThemeModePreference(ThemeMode themeMode) =>
      saveSetting(_themeModeKey, themeModeToStorageValue(themeMode));

  ThemeMode getThemeModePreference() =>
      themeModeFromStorageValue(getSetting<String>(_themeModeKey));

  Future<void> saveLocalePreference(Locale? locale) =>
      saveSetting(_localeKey, localeToStorageValue(locale));

  Locale? getLocalePreference() =>
      localeFromStorageValue(getSetting<String>(_localeKey));

  Future<void> saveUnitSystemPreference(UnitSystem unitSystem) =>
      saveSetting(_unitSystemKey, unitSystemToStorageValue(unitSystem));

  UnitSystem getUnitSystemPreference() =>
      unitSystemFromStorageValue(getSetting<String>(_unitSystemKey));

  Future<void> saveRestTimerSoundEnabled(bool enabled) =>
      saveSetting(_restTimerSoundEnabledKey, enabled);

  bool getRestTimerSoundEnabled() =>
      getSetting<bool>(_restTimerSoundEnabledKey, defaultValue: true) ?? true;

  // User preferences
  String? get fcmToken => _auth.get('fcm_token');
  Future<void> saveFcmToken(String token) => _auth.put('fcm_token', token);

  String? resolveOnboardingIdentity({String? uid, String? email}) {
    final normalizedEmail = email?.trim().toLowerCase();
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      return normalizedEmail;
    }

    final normalizedUid = uid?.trim();
    if (normalizedUid != null && normalizedUid.isNotEmpty) {
      return 'uid:$normalizedUid';
    }

    return null;
  }

  bool isOnboardingCompleteFor({required String uid, String? email}) {
    final identity = resolveOnboardingIdentity(uid: uid, email: email);
    if (identity == null) {
      return false;
    }

    final scopedKey = '$_legacyOnboardingCompleteKey::$identity';
    final scopedValue = _settings.get(scopedKey);
    if (scopedValue is bool) {
      return scopedValue;
    }

    final legacyComplete =
        _settings.get(_legacyOnboardingCompleteKey, defaultValue: false) ==
        true;
    if (!legacyComplete) {
      return false;
    }

    final legacyIdentity = _settings.get(_onboardingIdentityKey) as String?;
    // Strict: only migrate if legacyIdentity matches exactly.
    // Null legacyIdentity = unsafe (stale global flag from prior install/user), reject.
    if (legacyIdentity != null && legacyIdentity == identity) {
      unawaited(_settings.put(scopedKey, true));
      return true;
    }

    // Clear orphan legacy flag (no identity) so it stops auto-migrating future users.
    if (legacyIdentity == null) {
      unawaited(_settings.delete(_legacyOnboardingCompleteKey));
    }

    return false;
  }

  Future<void> setOnboardingCompleteFor({
    required String uid,
    String? email,
  }) async {
    final identity = resolveOnboardingIdentity(uid: uid, email: email);
    if (identity == null) {
      return;
    }

    await _settings.put(_legacyOnboardingCompleteKey, true);
    await _settings.put(_onboardingIdentityKey, identity);
    await _settings.put('$_legacyOnboardingCompleteKey::$identity', true);
  }

  // Tutorial guide
  bool isTutorialCompleteFor({required String uid, String? email}) {
    final identity = resolveOnboardingIdentity(uid: uid, email: email);
    if (identity == null) return false;
    return _settings.get(
          '$_tutorialCompleteKey::$identity',
          defaultValue: false,
        ) ==
        true;
  }

  Future<void> setTutorialCompleteFor({
    required String uid,
    String? email,
  }) async {
    final identity = resolveOnboardingIdentity(uid: uid, email: email);
    if (identity == null) return;
    await _settings.put('$_tutorialCompleteKey::$identity', true);
  }

  dynamic _normalize(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _normalize(item)),
      );
    }

    if (value is List) {
      return value.map(_normalize).toList(growable: false);
    }

    return value;
  }
}

class LocalSessionChanged implements Exception {
  const LocalSessionChanged();
}

class _SessionWorkoutStore implements ActiveWorkoutLocalStore {
  _SessionWorkoutStore(this.storage, this.session);
  final LocalStorage storage;
  final String? session;
  void _check() {
    if (session == null || storage.sessionStamp != session) {
      throw const LocalSessionChanged();
    }
  }

  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) {
    _check();
    return storage.getActiveWorkout(exerciseId);
  }

  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel workout) async {
    _check();
    await storage.saveActiveWorkout(workout);
    _check();
  }

  @override
  Future<void> removeActiveWorkout(String exerciseId) async {
    _check();
    await storage.removeActiveWorkout(exerciseId);
    _check();
  }
}
