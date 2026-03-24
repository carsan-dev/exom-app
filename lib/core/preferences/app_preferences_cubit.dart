import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/storage/local_storage.dart';

class AppPreferencesState extends Equatable {
  const AppPreferencesState({
    required this.themeMode,
    required this.locale,
    required this.unitSystem,
  });

  final ThemeMode themeMode;

  /// `null` means "follow the system locale".
  final Locale? locale;

  final UnitSystem unitSystem;

  bool get isSystemLocale => locale == null;

  AppPreferencesState copyWith({
    ThemeMode? themeMode,
    Object? locale = _sentinel,
    UnitSystem? unitSystem,
  }) {
    return AppPreferencesState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale == _sentinel ? this.locale : locale as Locale?,
      unitSystem: unitSystem ?? this.unitSystem,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    locale?.languageCode,
    locale?.countryCode,
    unitSystem,
  ];
}

const _sentinel = Object();

class AppPreferencesCubit extends Cubit<AppPreferencesState> {
  AppPreferencesCubit(this._localStorage)
    : super(
        AppPreferencesState(
          themeMode: _localStorage.getThemeModePreference(),
          locale: _localStorage.getLocalePreference(),
          unitSystem: _localStorage.getUnitSystemPreference(),
        ),
      );

  final LocalStorage _localStorage;

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (state.themeMode == themeMode) {
      return;
    }

    await _localStorage.saveThemeModePreference(themeMode);
    emit(state.copyWith(themeMode: themeMode));
  }

  Future<void> setLocale(Locale? locale) async {
    final normalizedLocale = localeFromStorageValue(
      localeToStorageValue(locale),
    );

    if (state.locale == normalizedLocale) {
      return;
    }

    await _localStorage.saveLocalePreference(normalizedLocale);
    emit(state.copyWith(locale: normalizedLocale));
  }

  Future<void> setUnitSystem(UnitSystem unitSystem) async {
    if (state.unitSystem == unitSystem) {
      return;
    }

    await _localStorage.saveUnitSystemPreference(unitSystem);
    emit(state.copyWith(unitSystem: unitSystem));
  }
}
