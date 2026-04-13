import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';

class LocalStorage {
  static const _authBox = 'auth_box';
  static const _cacheBox = 'cache_box';
  static const _settingsBox = 'settings_box';
  static const _pendingSyncKey = 'offline_sync_actions';
  static const _themeModeKey = 'theme_mode';
  static const _localeKey = 'locale';
  static const _unitSystemKey = 'unit_system';
  static const _legacyOnboardingCompleteKey = 'onboarding_complete';
  static const _onboardingIdentityKey = 'onboarding_complete_identity';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(_authBox),
      Hive.openBox(_cacheBox),
      Hive.openBox(_settingsBox),
    ]);
  }

  // Auth
  static Box get _auth => Hive.box(_authBox);
  static Box get _cache => Hive.box(_cacheBox);
  static Box get _settings => Hive.box(_settingsBox);

  Future<void> saveAuthToken(String token) => _auth.put('token', token);

  String? getAuthToken() => _auth.get('token');

  Future<void> clearAuth() => _auth.clear();

  Future<void> clearSessionData() async {
    await Future.wait([clearAuth(), clearCache()]);
  }

  // Cache
  Future<void> cacheData(String key, dynamic value) => _cache.put(key, value);

  T? getCachedData<T>(String key) => _cache.get(key) as T?;

  dynamic getCachedValue(String key) => _normalize(_cache.get(key));

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

  Future<void> removeCachedData(String key) => _cache.delete(key);

  Future<void> clearCache() => _cache.clear();

  List<Map<String, dynamic>> getPendingSyncActions() {
    final actions = getCachedList(_pendingSyncKey);
    if (actions == null) {
      return <Map<String, dynamic>>[];
    }

    return actions
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: true);
  }

  Future<void> savePendingSyncActions(List<Map<String, dynamic>> actions) =>
      _cache.put(_pendingSyncKey, actions);

  Future<void> clearPendingSyncActions() => _cache.delete(_pendingSyncKey);

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
    if (legacyIdentity == null || legacyIdentity == identity) {
      unawaited(_settings.put(_onboardingIdentityKey, identity));
      unawaited(_settings.put(scopedKey, true));
      return true;
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
