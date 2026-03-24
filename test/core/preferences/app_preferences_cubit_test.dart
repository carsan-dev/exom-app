import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPreferencesCubit', () {
    test('loads stored theme, locale and unit system', () {
      final storage = FakeLocalStorage(
        themeMode: ThemeMode.system,
        locale: const Locale('en'),
        unitSystem: UnitSystem.imperial,
      );

      final cubit = AppPreferencesCubit(storage);

      expect(cubit.state.themeMode, ThemeMode.system);
      expect(cubit.state.locale, const Locale('en'));
      expect(cubit.state.unitSystem, UnitSystem.imperial);
      expect(cubit.state.isSystemLocale, false);
    });

    test('defaults to system locale when no locale is stored', () {
      final storage = FakeLocalStorage();
      final cubit = AppPreferencesCubit(storage);

      expect(cubit.state.locale, isNull);
      expect(cubit.state.isSystemLocale, true);
    });

    test('persists updates before emitting new state', () async {
      final storage = FakeLocalStorage();
      final cubit = AppPreferencesCubit(storage);

      await cubit.setThemeMode(ThemeMode.light);
      await cubit.setLocale(const Locale('en'));
      await cubit.setUnitSystem(UnitSystem.imperial);

      expect(storage.themeMode, ThemeMode.light);
      expect(storage.locale, const Locale('en'));
      expect(storage.unitSystem, UnitSystem.imperial);
      expect(cubit.state.themeMode, ThemeMode.light);
      expect(cubit.state.locale, const Locale('en'));
      expect(cubit.state.unitSystem, UnitSystem.imperial);
    });
  });
}

class FakeLocalStorage extends LocalStorage {
  FakeLocalStorage({
    this.themeMode = ThemeMode.dark,
    this.locale,
    this.unitSystem = UnitSystem.metric,
  });

  ThemeMode themeMode;
  Locale? locale;
  UnitSystem unitSystem;

  @override
  ThemeMode getThemeModePreference() => themeMode;

  @override
  Future<void> saveThemeModePreference(ThemeMode value) async {
    themeMode = value;
  }

  @override
  Locale? getLocalePreference() => locale;

  @override
  Future<void> saveLocalePreference(Locale? value) async {
    locale = value;
  }

  @override
  UnitSystem getUnitSystemPreference() => unitSystem;

  @override
  Future<void> saveUnitSystemPreference(UnitSystem value) async {
    unitSystem = value;
  }
}
