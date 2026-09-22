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
  static const _feedbackUploadQueueKey = 'feedback_upload_queue';
  static const _progressPhotoUploadQueueKey = 'progress_photo_upload_queue';
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
