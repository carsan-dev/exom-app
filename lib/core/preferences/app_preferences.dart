import 'package:flutter/material.dart';

enum UnitSystem { metric, imperial }

class AppPreferencesDefaults {
  AppPreferencesDefaults._();

  static const themeMode = ThemeMode.dark;
  static const locale = Locale('es', 'ES');
  static const unitSystem = UnitSystem.metric;

  static const supportedLocales = [
    Locale('es'),
    Locale('es', 'ES'),
    Locale('en'),
  ];
}

String themeModeToStorageValue(ThemeMode themeMode) {
  switch (themeMode) {
    case ThemeMode.system:
      return 'system';
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
  }
}

ThemeMode themeModeFromStorageValue(String? value) {
  switch (value) {
    case 'system':
      return ThemeMode.system;
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return AppPreferencesDefaults.themeMode;
  }
}

String localeToStorageValue(Locale locale) {
  final countryCode = locale.countryCode;
  if (countryCode == null || countryCode.isEmpty) {
    return locale.languageCode;
  }

  return '${locale.languageCode}_$countryCode';
}

Locale localeFromStorageValue(String? value) {
  switch (value) {
    case 'en':
    case 'en_US':
      return const Locale('en');
    case 'es':
    case 'es_ES':
      return AppPreferencesDefaults.locale;
    default:
      return AppPreferencesDefaults.locale;
  }
}

String unitSystemToStorageValue(UnitSystem unitSystem) => unitSystem.name;

UnitSystem unitSystemFromStorageValue(String? value) {
  switch (value) {
    case 'imperial':
      return UnitSystem.imperial;
    case 'metric':
      return UnitSystem.metric;
    default:
      return AppPreferencesDefaults.unitSystem;
  }
}
