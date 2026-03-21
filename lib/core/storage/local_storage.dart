import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static const _authBox = 'auth_box';
  static const _cacheBox = 'cache_box';
  static const _settingsBox = 'settings_box';

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

  Future<void> saveAuthToken(String token) =>
      _auth.put('token', token);

  String? getAuthToken() => _auth.get('token');

  Future<void> clearAuth() => _auth.clear();

  // Cache
  Future<void> cacheData(String key, dynamic value) =>
      _cache.put(key, value);

  T? getCachedData<T>(String key) => _cache.get(key) as T?;

  Future<void> clearCache() => _cache.clear();

  // Settings
  Future<void> saveSetting(String key, dynamic value) =>
      _settings.put(key, value);

  T? getSetting<T>(String key, {T? defaultValue}) =>
      (_settings.get(key) as T?) ?? defaultValue;

  // User preferences
  String? get fcmToken => _auth.get('fcm_token');
  Future<void> saveFcmToken(String token) => _auth.put('fcm_token', token);

  bool get isOnboardingComplete =>
      _settings.get('onboarding_complete', defaultValue: false);
  Future<void> setOnboardingComplete() =>
      _settings.put('onboarding_complete', true);
}
