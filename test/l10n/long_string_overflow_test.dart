import 'dart:io';

import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_page.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/widgets/android_nonlinear_text_scaler.dart';
import '../features/challenges/challenges_test_support.dart';
import '../features/profile/presentation/profile_scene.dart' as perfil;
import '../features/recap/presentation/pages/recap_detail_redesign_test.dart'
    show pumpDetail, recapDetailRich;
import '../features/recap/presentation/pages/recap_form_redesign_test.dart'
    show pumpRecapForm;
import '../features/recap/presentation/pages/recap_list_redesign_test.dart'
    show pumpRecapList, recapListRich;

const _codes = [
  'progress_conflict_review_required',
  'PROGRESS_VERSION_CONFLICT',
  'PROGRESS_HISTORY_AMBIGUOUS',
  'progress_receipt_missing',
  'feedback_discarded',
  'sync_failed',
  'compression_cancelled',
  'compression_invalid_input',
  'compression_timeout',
  'compression_busy',
  'compression_failed',
  'UPLOAD_EXPIRED',
  'UPLOAD_OBJECT_MISSING',
  'upload_session_changed',
  'UPLOAD_OPERATION_CONFLICT',
];

Future<void> _pump(WidgetTester tester, Widget Function(BuildContext) child) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: app!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: Builder(builder: child))),
    ),
  );
  await tester.pump();
}

final _metric = BodyMetricEntity(
  id: 'metric-1',
  date: DateTime(2026, 11, 18),
  weightKg: 68.4,
  heightCm: 180,
  muscleMassKg: 32.5,
  sleepHours: 7.5,
  waistCm: 74,
  chestCm: 100,
  armLeftCm: 35,
  armRightCm: 36,
);

class _MetricsRepository extends Fake implements MetricsRepository {
  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async => _metric;

  @override
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data) async => _metric;
}

class _Profile extends Fake implements ProfileEntity {}

class _ProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async => _Profile();
}

class _Storage extends LocalStorage {
  _Storage(this.unitSystem);

  final UnitSystem unitSystem;

  @override
  ThemeMode getThemeModePreference() => ThemeMode.light;
  @override
  Locale? getLocalePreference() => null;
  @override
  UnitSystem getUnitSystemPreference() => unitSystem;
  @override
  Map<String, dynamic>? getCachedMap(String key) => null;
}

/// Mounts the real metrics form (registered in `sl` with fakes) at [width]dp.
Future<void> _pumpMetricsForm(
  WidgetTester tester, {
  required Locale locale,
  required double width,
  required double scale,
  required UnitSystem unitSystem,
  bool nonlinear = false,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final storage = _Storage(unitSystem);
  final repository = _MetricsRepository();
  final profile = _ProfileRepository();
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerFactory<MetricsBloc>(
    () => MetricsBloc(
      saveMetricUseCase: SaveMetricUseCase(repository),
      metricsRepository: repository,
      updateProfileUseCase: UpdateProfileUseCase(profile),
    ),
  );
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>(
      create: (_) => AppPreferencesCubit(storage),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: nonlinear
                ? AndroidNonlinearTextScaler(scale)
                : TextScaler.linear(scale),
          ),
          child: app!,
        ),
        home: const MetricsFormPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  // L5-B2 «Retos»: the main scene and its all-achievements sheet at 320 dp
  // with 1.3x and 1.6x text, in both languages (CC 3).
  for (final locale in const [Locale('es'), Locale('en')]) {
    for (final scale in const [1.3, 1.6]) {
      testWidgets(
        'Retos does not overflow at 320dp, ${scale}x, ${locale.languageCode}',
        (tester) async {
          await pumpChallengesPage(
            tester,
            realisticRepository(locale),
            width: 320,
            height: 6000,
            locale: locale,
            textScaler: TextScaler.linear(scale),
          );
          expect(tester.takeException(), isNull);
          await openAchievementsBoard(
            tester,
            locale.languageCode == 'es' ? 'Ver todos' : 'View all',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // L5-B4 «Perfil»: the main scene at 320 dp with 1.3x and 1.6x text, in
  // both languages (CC 3).
  for (final locale in const [Locale('es'), Locale('en')]) {
    for (final scale in const [1.3, 1.6]) {
      testWidgets(
        'Perfil does not overflow at 320dp, ${scale}x, ${locale.languageCode}',
        (tester) async {
          await perfil.pumpProfileScene(
            tester,
            width: 320,
            height: 6000,
            locale: locale,
            textScaler: TextScaler.linear(scale),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // L5-C3 «Recap, detalle»: the full scene at 320 and 360 dp with 1.0x, 1.3x
  // and 1.6x text (Android non-linear scaler), in both languages (CC 3).
  group('Recap detalle does not overflow', () {
    tearDown(() async => sl.reset());
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final width in const [320.0, 360.0]) {
        for (final scale in const [1.0, 1.3, 1.6]) {
          testWidgets(
            'at ${width.toInt()}dp, ${scale}x, ${locale.languageCode}',
            (tester) async {
              await pumpDetail(
                tester,
                extra: recapDetailRich,
                width: width,
                locale: locale,
                textScaler: AndroidNonlinearTextScaler(scale),
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  // L5-C4 «Recap, lista»: the main scene (rows with three values, featured
  // row, pinned action) at 320 and 360 dp with 1.0x, 1.3x and 1.6x text, in
  // both languages (CC 3); 2.0x scrolling is in recap_list_redesign_test.dart.
  group('Recap lista does not overflow', () {
    setUpAll(() async {
      await initializeDateFormatting('es');
      await initializeDateFormatting('en');
    });
    tearDown(() async => sl.reset());
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final width in const [320.0, 360.0]) {
        for (final scale in const [1.0, 1.3, 1.6]) {
          testWidgets(
            'at ${width.toInt()}dp, ${scale}x, ${locale.languageCode}',
            (tester) async {
              await pumpRecapList(
                tester,
                recaps: recapListRich(),
                width: width,
                locale: locale,
                textScaler: AndroidNonlinearTextScaler(scale),
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  // L5-C5a «Recap, formulario por pasos»: the start view and the five steps
  // with their longest content (invalid value and its reasons, many chosen
  // zones, optional switches on) at 320 and 360 dp with 1.0x, 1.3x and 1.6x
  // text, in both languages (CC 3); 2.0x scrolling is in
  // recap_form_redesign_test.dart.
  group('Recap formulario por pasos does not overflow', () {
    setUpAll(() async {
      await initializeDateFormatting('es');
      await initializeDateFormatting('en');
    });
    tearDown(() async => sl.reset());
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final width in const [320.0, 360.0]) {
        for (final scale in const [1.0, 1.3, 1.6]) {
          for (final step in const [0, 1, 2, 3, 4, 5]) {
            testWidgets(
              'step $step at ${width.toInt()}dp, ${scale}x, ${locale.languageCode}',
              (tester) async {
                await pumpRecapForm(
                  tester,
                  step: step,
                  width: width,
                  locale: locale,
                  rich: true,
                  textScaler: AndroidNonlinearTextScaler(scale),
                );
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  });

  testWidgets('error and upload states do not overflow at 320dp, 1.3x text', (tester) async {
    await _pump(tester, (context) {
      final l10n = AppLocalizations.of(context);
      return Column(
        children: [
          for (final code in _codes)
            ErrorWidget2(message: localizedErrorCode(l10n, code)!, onRetry: () {}),
          ErrorWidget2(message: l10n.errorBadRequest, onRetry: () {}),
          ErrorWidget2(message: l10n.errorConflict, onRetry: () {}),
          ErrorWidget2(message: l10n.errorRateLimited, onRetry: () {}),
          ErrorWidget2(message: l10n.trainingProgressSaveError, onRetry: () {}),
          ErrorWidget2(message: l10n.activeExerciseContextMissing),
        ],
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('execution picker dialog and notices do not overflow', (tester) async {
    await _pump(tester, (context) {
      final l10n = AppLocalizations.of(context);
      return Column(
        children: [
          Text(l10n.quarantinedWorkoutNotice),
          Text(l10n.circuitSummary(12, 12)),
          Text(l10n.optionsCount(5)),
          Text(l10n.timerSegmentRemaining('10:00', '120:00')),
          AlertDialog(
            title: Text(l10n.selectTrainingExecution),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(l10n.recoverSavedExerciseDraft),
                  subtitle: Text(l10n.restoreSavedSetsNewExecution),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () {}, child: Text(l10n.cancel)),
              FilledButton(onPressed: () {}, child: Text(l10n.newTrainingExecution)),
            ],
          ),
        ],
      );
    });
    expect(tester.takeException(), isNull);
  });

  group('MetricsFormPage does not overflow', () {
    // Real DM Sans face: the default test font (Ahem) fakes widths.
    setUpAll(() async {
      final loader = FontLoader(AppTheme.bodyFontFamily);
      var loaded = 0;
      for (final file in Directory('assets/fonts').listSync().whereType<File>()) {
        final name = file.uri.pathSegments.last;
        if (name.startsWith('dm-sans-') && name.endsWith('.ttf')) {
          loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
          loaded++;
        }
      }
      expect(loaded, greaterThan(0), reason: 'no dm-sans-*.ttf font found');
      await loader.load();
    });
    setUp(sl.reset);
    tearDown(sl.reset);

    // Scrolls the whole form in steps (off-screen content is not laid out
    // until reached) and checks for layout exceptions after every step.
    Future<void> sweep(WidgetTester tester, String label) async {
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      await tester.drag(scrollable, const Offset(0, 100000));
      await tester.pump();
      expect(position.pixels, position.minScrollExtent, reason: label);
      var steps = 0;
      while (position.pixels < position.maxScrollExtent) {
        await tester.drag(scrollable, const Offset(0, -250));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$label step $steps');
        expect(++steps, lessThan(200), reason: '$label never reaches the end');
      }
      expect(position.pixels, position.maxScrollExtent, reason: label);
      expect(steps, greaterThan(0), reason: '$label is not scrollable');
    }

    // L5-E9b (CC 3): 320 dp at 1.3x and 1.6x and 360 dp at 1.6x, with the
    // linear scaler and the Android 14+ nonlinear one, and 2.0x reachable by
    // scrolling.
    const cases = [
      (320.0, 1.3, false),
      (320.0, 1.3, true),
      (320.0, 1.6, false),
      (320.0, 1.6, true),
      (360.0, 1.6, false),
      (360.0, 1.6, true),
      (320.0, 2.0, false),
    ];
    for (final locale in const ['es', 'en']) {
      for (final unit in UnitSystem.values) {
        for (final (width, scale, nonlinear) in cases) {
          final scaler = nonlinear ? 'android' : 'linear';
          testWidgets('$locale ${unit.name} ${width.toInt()}dp x$scale $scaler '
              'full form', (tester) async {
            await _pumpMetricsForm(
              tester,
              locale: Locale(locale),
              width: width,
              scale: scale,
              unitSystem: unit,
              nonlinear: nonlinear,
            );
            final l10n = AppLocalizations.of(tester.element(find.byType(MetricsFormPage)));
            expect(find.byType(MetricsFormPage), findsOneWidget);
            expect(tester.takeException(), isNull);
            // List mode of the measurements.
            await sweep(tester, 'list');
            expect(find.text(l10n.saveMetricsButton.toUpperCase()), findsOneWidget);
            // Body-map mode, front and back views.
            await tester.ensureVisible(find.text(l10n.bodyViewToggle));
            await tester.pump();
            await tester.tap(find.text(l10n.bodyViewToggle));
            await tester.pump();
            expect(tester.takeException(), isNull);
            await sweep(tester, 'body map front');
            final back = find.text(l10n.backViewLabel);
            expect(back, findsOneWidget);
            await tester.ensureVisible(back);
            await tester.pump();
            await tester.tap(back);
            await tester.pump();
            expect(tester.takeException(), isNull);
            await sweep(tester, 'body map back');
            expect(find.text(l10n.saveMetricsButton.toUpperCase()), findsOneWidget);
          });
        }
      }
    }
  });
}
