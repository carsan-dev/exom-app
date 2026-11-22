// L4-I6 / L5-D5: the figures of the profile page use the active locale.
// The bloc and the use cases are the real ones; the repositories are fakes.
import 'dart:io';

import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:exom_app/features/profile/presentation/pages/profile_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = ProfileEntity(id: 'user-1', firstName: 'Ana');

final _latest = BodyMetricEntity(
  id: 'metric-1',
  date: DateTime(2026, 11, 18),
  sleepHours: 7.5,
);

class _ProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> getProfile() async => _profile;

  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async =>
      _profile;

  @override
  Future<ProfileEntity> uploadAvatar(File file) async => _profile;
}

class _MetricsRepository extends Fake implements MetricsRepository {
  @override
  Future<List<BodyMetricEntity>> getWeightHistory() async => const [];

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async => _latest;
}

class _Storage extends LocalStorage {
  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => null;
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
}

Future<void> _mount(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final storage = _Storage();
  final profiles = _ProfileRepository();
  final metrics = _MetricsRepository();
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerFactory<ProfileBloc>(
    () => ProfileBloc(
      getProfileUseCase: GetProfileUseCase(profiles),
      updateProfileUseCase: UpdateProfileUseCase(profiles),
      uploadAvatarUseCase: UploadAvatarUseCase(profiles),
      metricsRepository: metrics,
    ),
  );
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>(
      create: (_) => AppPreferencesCubit(storage),
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfilePage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

// L5-B4 (D14-7): the sleep figure is a flat block whose unit «h» is a small
// span right after the digits (exomFigureSpans, the gap is letter spacing),
// so the plain text reads «7,5h»; the locale separator is what is checked.
void main() {
  tearDown(sl.reset);

  group('profile figures follow the active locale (L5-D5)', () {
    testWidgets('sleep average in Spanish uses a decimal comma', (
      tester,
    ) async {
      await _mount(tester, const Locale('es'));
      expect(find.text('7,5h', findRichText: true), findsOneWidget);
      expect(find.text('7.5h', findRichText: true), findsNothing);
    });

    testWidgets('sleep average in English uses a decimal point', (
      tester,
    ) async {
      await _mount(tester, const Locale('en'));
      expect(find.text('7.5h', findRichText: true), findsOneWidget);
      expect(find.text('7,5h', findRichText: true), findsNothing);
    });
  });
}
