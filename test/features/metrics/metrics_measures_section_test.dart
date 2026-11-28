// L6-D2 «06 Medidas corporales» of the metrics form: list of flat rows, body
// map on the C5b figure and the measure sheet (numeral steppers and «Hecho»).
// The save keeps its contract: only touched measures carry a new value, the
// untouched ones resend the loaded value, same keys, centimetres.
// Presentation only: the bloc and the use cases are the real ones; the
// repository is a recording fake. Uses the real DM Sans face.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:exom_app/core/models/body_zone.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_page.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'metrics_measures_helpers.dart';

/// Neck, chest and waist single; arm both sides; thigh only the left side;
/// hips, shoulders, forearm and calf without data.
final _metric = BodyMetricEntity(
  id: 'metric-1',
  date: DateTime(2026, 11, 19),
  weightKg: 68.4,
  heightCm: 180,
  muscleMassKg: 32.5,
  sleepHours: 7.5,
  neckCm: 38,
  chestCm: 96.5,
  waistCm: 74,
  armLeftCm: 33,
  armRightCm: 33.5,
  thighLeftCm: 55,
);

/// What every save carries besides its changes: the date of the selected day
/// («today» of the harness is the day of [_metric]). The loaded values are
/// not resent (M-1): the API keeps every absent key.
Map<String, dynamic> _datePayload() => {'date': '2026-11-19'};

class _Repository extends Fake implements MetricsRepository {
  _Repository(this.latest);

  final BodyMetricEntity? latest;
  final saved = <Map<String, dynamic>>[];

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async => latest;

  @override
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data) async {
    saved.add({...data});
    return latest ?? _metric;
  }
}

class _Profile extends Fake implements ProfileEntity {}

class _ProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async =>
      _Profile();
}

class _Storage extends LocalStorage {
  _Storage(this.unitSystem);

  final UnitSystem unitSystem;

  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => null;
  @override
  UnitSystem getUnitSystemPreference() => unitSystem;
  @override
  Map<String, dynamic>? getCachedMap(String key) => null;
}

Future<_Repository> _mount(
  WidgetTester tester, {
  BodyMetricEntity? latest,
  ThemeData? theme,
  Size size = const Size(390, 900),
  double textScale = 1.0,
  Locale locale = const Locale('es'),
  UnitSystem unitSystem = UnitSystem.metric,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final storage = _Storage(unitSystem);
  final repository = _Repository(latest);
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerFactory<MetricsBloc>(
    () => MetricsBloc(
      saveMetricUseCase: SaveMetricUseCase(repository),
      metricsRepository: repository,
      updateProfileUseCase: UpdateProfileUseCase(_ProfileRepository()),
    ),
  );
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>(
      create: (_) => AppPreferencesCubit(storage),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: theme ?? AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      // «Today» is the day of the loaded record, so the initial «latest» load
      // answers the record of the selected day (L6-UX7 b).
      builder: (_) => MetricsFormPage(clock: () => (latest ?? _metric).date),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return repository;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MetricsFormPage)));

Future<void> _save(WidgetTester tester) async {
  final wanted = _l10n(tester).saveMetricsButton.toLowerCase();
  await tester.tap(
    find.byWidgetPredicate(
      (widget) => widget is Text && widget.data?.toLowerCase() == wanted,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openBody(WidgetTester tester) async {
  final toggle = find.text(_l10n(tester).bodyViewToggle);
  await tester.scrollUntilVisible(
    toggle,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(toggle);
  await tester.pump();
  await tester.tap(toggle);
  await tester.pump();
}

const _zonesInOrder = [
  BodyZone.neck,
  BodyZone.shoulders,
  BodyZone.chest,
  BodyZone.waist,
  BodyZone.hips,
  BodyZone.upperArm,
  BodyZone.forearm,
  BodyZone.thigh,
  BodyZone.calf,
];

void main() {
  setUpAll(() async {
    final loader = FontLoader(AppTheme.bodyFontFamily);
    for (final file in Directory('assets/fonts').listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (name.startsWith('dm-sans-') && name.endsWith('.ttf')) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await loader.load();
    // The display face of the numerals: without it the metrics are the
    // fallback font's and the widths below mean nothing.
    final display = FontLoader(AppTheme.displayFontFamily)
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/barlow-condensed-800.ttf').readAsBytesSync(),
          ),
        ),
      );
    await display.load();
  });
  tearDown(sl.reset);

  group('list', () {
    testWidgets('one row per zone in the sketch order', (tester) async {
      await _mount(tester, latest: _metric, size: const Size(390, 3000));
      final tops = [
        for (final zone in _zonesInOrder) tester.getRect(measureRow(zone)).top,
      ];
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(9));
    });

    for (final (locale, values) in const [
      (
        'es',
        {
          BodyZone.neck: '38,0 cm',
          BodyZone.shoulders: 'Sin dato',
          BodyZone.chest: '96,5 cm',
          BodyZone.waist: '74,0 cm',
          BodyZone.hips: 'Sin dato',
          BodyZone.upperArm: 'I 33,0 · D 33,5 cm',
          BodyZone.forearm: 'Sin dato',
          BodyZone.thigh: 'I 55,0 · D —',
          BodyZone.calf: 'Sin dato',
        },
      ),
      (
        'en',
        {
          BodyZone.neck: '38.0 cm',
          BodyZone.shoulders: 'No data',
          BodyZone.chest: '96.5 cm',
          BodyZone.waist: '74.0 cm',
          BodyZone.hips: 'No data',
          BodyZone.upperArm: 'L 33.0 · R 33.5 cm',
          BodyZone.forearm: 'No data',
          BodyZone.thigh: 'L 55.0 · R —',
          BodyZone.calf: 'No data',
        },
      ),
    ]) {
      testWidgets('$locale values, «Sin dato» and a partial pair', (
        tester,
      ) async {
        await _mount(
          tester,
          latest: _metric,
          locale: Locale(locale),
          size: const Size(390, 3000),
        );
        final l10n = _l10n(tester);
        for (final MapEntry(key: zone, value: value) in values.entries) {
          expect(
            find.descendant(
              of: measureRow(zone),
              matching: find.text(zone.label(l10n)),
            ),
            findsOneWidget,
            reason: zone.name,
          );
          expect(measureValueText(tester, zone), value, reason: zone.name);
          expect(measureEdited(zone), findsNothing, reason: zone.name);
        }
        expect(find.text(l10n.measureHips), findsOneWidget);
      });
    }

    testWidgets('values use tabular figures', (tester) async {
      await _mount(tester, latest: _metric, size: const Size(390, 3000));
      final style = tester.widget<Text>(measureValue(BodyZone.neck)).style;
      expect(style?.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('every row is a button of at least 48 dp', (tester) async {
      await _mount(tester, latest: _metric, size: const Size(390, 3000));
      for (final zone in _zonesInOrder) {
        expect(
          tester.getSize(measureRow(zone)).height,
          greaterThanOrEqualTo(48),
        );
      }
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(measureRow(BodyZone.upperArm));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, contains('Brazo'));
      expect(node.label, contains('33,0'));
      handle.dispose();
    });
  });

  group('sheet', () {
    testWidgets('a single zone: kicker, title, «Última» and one stepper', (
      tester,
    ) async {
      await _mount(tester, latest: _metric);
      final l10n = _l10n(tester);
      await openMeasureSheet(tester, BodyZone.waist);
      expect(measureSheet(), findsOneWidget);
      expect(
        find.descendant(
          of: measureSheet(),
          matching: find.text(l10n.metricsMeasureSheetKicker.toUpperCase()),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: measureSheet(), matching: find.text('CINTURA')),
        findsOneWidget,
      );
      expect(plainText(tester, measureLast()), 'Última: 74,0 cm · 19 nov');
      expect(measureStepper('waist_cm'), findsOneWidget);
      expect(
        find.descendant(
          of: measureStepper('waist_cm'),
          matching: find.textContaining('74', findRichText: true),
        ),
        findsWidgets,
      );
      expect(find.text(l10n.metricsMeasureDone.toUpperCase()), findsOneWidget);
    });

    testWidgets('a pair: both sides in «Última», two stacked steppers', (
      tester,
    ) async {
      await _mount(tester, latest: _metric);
      final l10n = _l10n(tester);
      await openMeasureSheet(tester, BodyZone.upperArm);
      expect(
        plainText(tester, measureLast()),
        'Última: I 33,0 · D 33,5 cm · 19 nov',
      );
      final left = tester.getRect(measureStepper('arm_left_cm'));
      final right = tester.getRect(measureStepper('arm_right_cm'));
      expect(right.top, greaterThan(left.bottom), reason: 'stacked');
      expect(find.text(l10n.leftSideLabel), findsOneWidget);
      expect(find.text(l10n.rightSideLabel), findsOneWidget);
    });

    for (final (locale, left, right) in [
      ('es', '33,0', '33,5'),
      ('en', '33.0', '33.5'),
    ]) {
      testWidgets('$locale pair numerals show one fixed decimal', (
        tester,
      ) async {
        await _mount(tester, latest: _metric, locale: Locale(locale));
        await openMeasureSheet(tester, BodyZone.upperArm);
        String numeral(String key) => tester
            .widget<ExomNumeral>(
              find.descendant(
                of: measureStepper(key),
                matching: find.byType(ExomNumeral),
              ),
            )
            .value;
        expect(numeral('arm_left_cm'), left);
        expect(numeral('arm_right_cm'), right);
      });
    }

    testWidgets('a zone without data has no «Última» line', (tester) async {
      await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.hips);
      expect(measureSheet(), findsOneWidget);
      expect(measureLast(), findsNothing);
      expect(measureStepper('hips_cm'), findsOneWidget);
    });

    testWidgets('no «Borrar valor»: the API keeps an omitted measure', (
      tester,
    ) async {
      // POST /metrics upserts with the fields it receives: an omitted measure
      // keeps its stored value and the app never sends null, so the sheet
      // cannot offer to delete a value (L6-D2, reported to the owner).
      await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.waist);
      expect(find.textContaining('Borrar'), findsNothing);
      expect(
        find.descendant(of: measureSheet(), matching: find.byType(TextButton)),
        findsNothing,
      );
    });
  });

  group('save payload (only touched measures change)', () {
    testWidgets('untouched: the loaded values, nothing else', (tester) async {
      final repository = await _mount(tester, latest: _metric);
      await _save(tester);
      // L6-UX4: nothing changed, so nothing is sent.
      expect(repository.saved, isEmpty);
    });

    testWidgets('typed waist «73,5» + «Hecho»: only waist_cm changes', (
      tester,
    ) async {
      final repository = await _mount(tester, latest: _metric);
      final l10n = _l10n(tester);
      await openMeasureSheet(tester, BodyZone.waist);
      await typeMeasure(tester, 'waist_cm', '73,5');
      await tapMeasureDone(tester);
      expect(measureSheet(), findsNothing);
      expect(measureValueText(tester, BodyZone.waist), '73,5 cm');
      expect(measureEdited(BodyZone.waist), findsOneWidget);
      expect(
        find.descendant(
          of: measureEdited(BodyZone.waist),
          matching: find.text(l10n.metricsMeasureEdited),
        ),
        findsOneWidget,
      );
      await _save(tester);
      expect(repository.saved.single, {..._datePayload(), 'waist_cm': 73.5});
    });

    testWidgets('+ on the right arm: only arm_right_cm moves 0.5', (
      tester,
    ) async {
      final repository = await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.upperArm);
      await stepMeasure(tester, 'arm_right_cm');
      await tapMeasureDone(tester);
      expect(measureValueText(tester, BodyZone.upperArm), 'I 33,0 · D 34,0 cm');
      await _save(tester);
      expect(repository.saved.single, {
        ..._datePayload(),
        'arm_right_cm': 34.0,
      });
    });

    testWidgets('the missing side of a pair can be filled alone', (
      tester,
    ) async {
      final repository = await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.thigh);
      await typeMeasure(tester, 'thigh_right_cm', '56');
      await tapMeasureDone(tester);
      expect(measureValueText(tester, BodyZone.thigh), 'I 55,0 · D 56,0 cm');
      await _save(tester);
      expect(repository.saved.single, {
        ..._datePayload(),
        'thigh_right_cm': 56.0,
      });
    });

    testWidgets('a zone without data opened and closed with «Hecho» but not '
        'changed sends nothing for it', (tester) async {
      final repository = await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.hips);
      await tapMeasureDone(tester);
      expect(measureValueText(tester, BodyZone.hips), 'Sin dato');
      expect(measureEdited(BodyZone.hips), findsNothing);
      await _save(tester);
      // L6-UX4: nothing changed, so nothing is sent.
      expect(repository.saved, isEmpty);
    });

    testWidgets('dismissing the sheet discards its changes', (tester) async {
      final repository = await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.waist);
      await stepMeasure(tester, 'waist_cm');
      final route = ModalRoute.of(tester.element(measureSheet()))!;
      expect(route, isA<ExomSheetRoute<dynamic>>());
      route.navigator!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(measureSheet(), findsNothing);
      expect(measureValueText(tester, BodyZone.waist), '74,0 cm');
      await _save(tester);
      // L6-UX4: nothing changed, so nothing is sent.
      expect(repository.saved, isEmpty);
    });

    for (final locale in const [Locale('es'), Locale('en')]) {
      group('typed entries (${locale.languageCode})', () {
        for (final MapEntry(key: raw, value: sent) in const {
          '78,6': 78.6,
          '78.6': 78.6,
          '78': 78.0,
          '78,60': 78.6,
        }.entries) {
          testWidgets('waist "$raw" sends $sent', (tester) async {
            final repository = await _mount(
              tester,
              latest: _metric,
              locale: locale,
            );
            await openMeasureSheet(tester, BodyZone.waist);
            await typeMeasure(tester, 'waist_cm', raw);
            await tapMeasureDone(tester);
            await _save(tester);
            expect(repository.saved.single['waist_cm'], sent);
          });
        }
        // An invalid typed value never reaches the draft: «Hecho» keeps the
        // sheet open with the review message, and the save sends the loaded
        // value (before L6 the save itself was blocked by a snack bar).
        for (final raw in ['78,6,1', 'abc', ',', '']) {
          testWidgets('waist "$raw" is refused by «Hecho»', (tester) async {
            final repository = await _mount(
              tester,
              latest: _metric,
              locale: locale,
            );
            final l10n = _l10n(tester);
            await openMeasureSheet(tester, BodyZone.waist);
            await typeMeasure(tester, 'waist_cm', raw);
            await tapMeasureDone(tester);
            expect(measureSheet(), findsOneWidget);
            expect(
              find.text(
                l10n.measurementReviewTemplate(
                  BodyZone.waist.label(l10n).toLowerCase(),
                ),
              ),
              findsOneWidget,
            );
            Navigator.of(tester.element(measureSheet())).pop();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await _save(tester);
            // L6-UX4: nothing changed, so nothing is sent.
            expect(repository.saved, isEmpty);
          });
        }
      });
    }

    testWidgets('a pair takes comma and point in any locale', (tester) async {
      final repository = await _mount(
        tester,
        latest: _metric,
        locale: const Locale('en'),
      );
      await openMeasureSheet(tester, BodyZone.upperArm);
      await typeMeasure(tester, 'arm_left_cm', '35,5');
      await typeMeasure(tester, 'arm_right_cm', '36.5');
      await tapMeasureDone(tester);
      expect(measureValueText(tester, BodyZone.upperArm), 'L 35.5 · R 36.5 cm');
      await _save(tester);
      expect(repository.saved.single['arm_left_cm'], 35.5);
      expect(repository.saved.single['arm_right_cm'], 36.5);
    });

    testWidgets('imperial: inches in the sheet, centimetres in the payload', (
      tester,
    ) async {
      final repository = await _mount(
        tester,
        latest: _metric,
        unitSystem: UnitSystem.imperial,
      );
      await openMeasureSheet(tester, BodyZone.waist);
      expect(
        find.descendant(
          of: measureStepper('waist_cm'),
          matching: find.textContaining('29,1', findRichText: true),
        ),
        findsWidgets,
      );
      await stepMeasure(tester, 'waist_cm');
      await tapMeasureDone(tester);
      expect(measureValueText(tester, BodyZone.waist), '29,6 in');
      expect(measureValueText(tester, BodyZone.neck), '15,0 in');
      await _save(tester);
      expect(repository.saved.single, {
        ..._datePayload(),
        // 29.6 in, converted as the old field did.
        'waist_cm': 29.6 * 2.54,
      });
    });
  });

  group('body', () {
    testWidgets('the C5b figure with the hint; no zone tapped yet', (
      tester,
    ) async {
      await _mount(tester, latest: _metric);
      await _openBody(tester);
      final l10n = _l10n(tester);
      final selector = tester.widget<RecapAnatomySelector>(
        find.byType(RecapAnatomySelector),
      );
      expect(selector.selectedZoneIds, isEmpty);
      expect(selector.zoneMarks, {
        'neck_front': RecapZoneMark.withData,
        'shoulder_left_front': RecapZoneMark.withoutData,
        'shoulder_right_front': RecapZoneMark.withoutData,
        'shoulder_left_back': RecapZoneMark.withoutData,
        'shoulder_right_back': RecapZoneMark.withoutData,
        'chest_left': RecapZoneMark.withData,
        'chest_right': RecapZoneMark.withData,
        'abdomen': RecapZoneMark.withData,
        'hip_flexors': RecapZoneMark.withoutData,
        'glutes_left': RecapZoneMark.withoutData,
        'glutes_right': RecapZoneMark.withoutData,
        'biceps_left': RecapZoneMark.withData,
        'biceps_right': RecapZoneMark.withData,
        'triceps_left': RecapZoneMark.withData,
        'triceps_right': RecapZoneMark.withData,
        'forearm_left_front': RecapZoneMark.withoutData,
        'forearm_right_front': RecapZoneMark.withoutData,
        'forearm_left_back': RecapZoneMark.withoutData,
        'forearm_right_back': RecapZoneMark.withoutData,
        // A pair with one side counts as with data.
        'quadriceps_left': RecapZoneMark.withData,
        'quadriceps_right': RecapZoneMark.withData,
        'hamstrings_left': RecapZoneMark.withData,
        'hamstrings_right': RecapZoneMark.withData,
        'shin_left': RecapZoneMark.withoutData,
        'shin_right': RecapZoneMark.withoutData,
        'calves_left': RecapZoneMark.withoutData,
        'calves_right': RecapZoneMark.withoutData,
      });
      expect(find.text(l10n.metricsMeasureTapZone), findsOneWidget);
      expect(
        tester.getRect(find.text(l10n.metricsMeasureTapZone)).top,
        greaterThan(tester.getRect(find.byType(RecapAnatomySelector)).bottom),
      );
      for (final label in [l10n.frontViewLabel, l10n.backViewLabel]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('a zone opens its sheet and stays selected in lime', (
      tester,
    ) async {
      final repository = await _mount(tester, latest: _metric);
      await _openBody(tester);
      final handle = tester.ensureSemantics();
      final arm = find.bySemanticsLabel(RegExp(r'^Brazo'));
      expect(arm, findsNWidgets(2), reason: 'both biceps plates');
      await tester.ensureVisible(arm.first);
      await tester.pump();
      // The semantic box is not hit-tested; the figure under it takes the tap.
      await tester.tap(arm.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      handle.dispose();
      expect(measureSheet(), findsOneWidget);
      expect(measureStepper('arm_left_cm'), findsOneWidget);
      await stepMeasure(tester, 'arm_left_cm', up: false);
      await tapMeasureDone(tester);
      final selector = tester.widget<RecapAnatomySelector>(
        find.byType(RecapAnatomySelector),
      );
      expect(selector.selectedZoneIds, {
        'biceps_left',
        'biceps_right',
        'triceps_left',
        'triceps_right',
      });
      await _save(tester);
      expect(repository.saved.single, {..._datePayload(), 'arm_left_cm': 32.5});
    });

    testWidgets('a part that cannot be measured opens nothing', (tester) async {
      await _mount(tester, latest: _metric);
      await _openBody(tester);
      final figure = find.descendant(
        of: find.byType(RecapAnatomySelector),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter != null && w.size.height > 200,
        ),
      );
      await tester.ensureVisible(figure);
      await tester.pump();
      final rect = tester.getRect(figure);
      // The head, at (170, 60) of the 340 x 720 view box.
      await tester.tapAt(
        rect.topLeft + Offset(170 * rect.width / 340, 60 * rect.height / 720),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(measureSheet(), findsNothing);
    });
  });

  group('large text (A-D1)', () {
    for (final locale in const ['es', 'en']) {
      for (final width in const [320.0, 360.0, 412.0]) {
        testWidgets('$locale ${width}dp x2.0: rows and values are whole', (
          tester,
        ) async {
          await _mount(
            tester,
            latest: _metric,
            locale: Locale(locale),
            size: Size(width, 6000),
            textScale: 2.0,
          );
          expect(tester.takeException(), isNull);
          for (final zone in _zonesInOrder) {
            final row = tester.getRect(measureRow(zone));
            final value = tester.getRect(measureValue(zone));
            expect(value.left, greaterThanOrEqualTo(row.left), reason: '$zone');
            expect(value.right, lessThanOrEqualTo(row.right), reason: '$zone');
            expect(
              value.bottom,
              lessThanOrEqualTo(row.bottom),
              reason: '$zone',
            );
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: measureValue(zone),
                matching: find.byType(RichText),
              ),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: '$zone');
          }
          if (width == 320) {
            // The pair value went under its label and stays at the end.
            final label = tester.getRect(
              find.descendant(
                of: measureRow(BodyZone.upperArm),
                matching: find.text(BodyZone.upperArm.label(_l10n(tester))),
              ),
            );
            final pair = tester.getRect(measureValue(BodyZone.upperArm));
            expect(pair.top, greaterThanOrEqualTo(label.bottom));
          }
        });
      }
    }

    for (final locale in const ['es', 'en']) {
      testWidgets('$locale 320dp x2.0: the pair sheet does not overflow', (
        tester,
      ) async {
        await _mount(
          tester,
          latest: _metric,
          locale: Locale(locale),
          size: const Size(320, 640),
          textScale: 2.0,
        );
        await openMeasureSheet(tester, BodyZone.upperArm);
        expect(tester.takeException(), isNull);
        expect(measureSheet(), findsOneWidget);
        await tester.ensureVisible(measureStepper('arm_right_cm'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(measureDone(), findsOneWidget);
      });
    }

    testWidgets('320dp x1.0: the value stays on the label line', (
      tester,
    ) async {
      await _mount(tester, latest: _metric, size: const Size(320, 3000));
      final label = tester.getRect(
        find.descendant(
          of: measureRow(BodyZone.upperArm),
          matching: find.text(BodyZone.upperArm.label(_l10n(tester))),
        ),
      );
      final pair = tester.getRect(measureValue(BodyZone.upperArm));
      expect(pair.top, lessThan(label.bottom));
    });
  });

  group('large text (A-D1) 384dp x2.0: the sheet shows whole values', () {
    // 1080 x 2340 at 450 dpi: 384 dp wide. «299,5» is the longest 3-digit
    // value the sheet accepts (the cap is 300 cm).
    const typedValues = {
      'arm_left_cm': ['33,5', '34,0', '56,4', '299,5'],
      'arm_right_cm': ['56,7', '34,0', '299,5'],
      'thigh_left_cm': ['56,4', '56,7', '299,5'],
      'thigh_right_cm': ['33,5', '56,7', '299,5'],
    };

    /// Natural width of the text of [paragraph] at the system scale.
    double naturalWidth(RenderParagraph paragraph, double scale) {
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: ui.TextDirection.ltr,
        textScaler: TextScaler.linear(scale),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    for (final locale in const ['es', 'en']) {
      for (final entry in typedValues.entries) {
        for (final typed in entry.value) {
          testWidgets('$locale ${entry.key} «$typed»: numeral and field', (
            tester,
          ) async {
            await _mount(
              tester,
              latest: _metric,
              locale: Locale(locale),
              size: const Size(384, 2340),
              textScale: 2.0,
            );
            final zone = entry.key.startsWith('arm')
                ? BodyZone.upperArm
                : BodyZone.thigh;
            await openMeasureSheet(tester, zone);
            final shown = locale == 'en' ? typed.replaceAll(',', '.') : typed;
            await typeMeasure(tester, entry.key, shown);
            expect(tester.takeException(), isNull);

            void expectWhole(Finder text, Rect box) {
              final paragraph = tester.renderObject<RenderParagraph>(text);
              final natural = naturalWidth(paragraph, 2.0);
              expect(
                paragraph.size.width,
                greaterThanOrEqualTo(natural - 0.5),
                reason: 'text narrower than its content',
              );
              final rect = tester.getRect(text);
              expect(rect.left, greaterThanOrEqualTo(box.left - 0.5));
              expect(rect.right, lessThanOrEqualTo(box.right + 0.5));
            }

            // Typing: the field shows the whole value.
            final field = find.descendant(
              of: measureStepper(entry.key),
              matching: find.byKey(ExomNumeralStepper.fieldKey),
            );
            final editable = tester
                .state<EditableTextState>(
                  find.descendant(
                    of: field,
                    matching: find.byType(EditableText),
                  ),
                )
                .renderEditable;
            final painter = TextPainter(
              text: TextSpan(
                text: shown,
                style: tester
                    .widget<EditableText>(
                      find.descendant(
                        of: field,
                        matching: find.byType(EditableText),
                      ),
                    )
                    .style,
              ),
              textDirection: ui.TextDirection.ltr,
              textScaler: TextScaler.linear(2.0),
            )..layout();
            final needed = painter.width;
            painter.dispose();
            expect(
              editable.size.width,
              greaterThanOrEqualTo(needed),
              reason: 'field narrower than «$shown»',
            );

            // Settled: the numeral shows the whole value.
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await tester.pump();
            final box = tester.getRect(
              find.descendant(
                of: measureStepper(entry.key),
                matching: find.byKey(ExomNumeralStepper.valueKey),
              ),
            );
            final numeralText = find.descendant(
              of: find.descendant(
                of: measureStepper(entry.key),
                matching: find.byKey(ExomNumeralStepper.valueKey),
              ),
              matching: find.byType(RichText),
            );
            for (final element in numeralText.evaluate()) {
              expectWhole(find.byWidget(element.widget), box);
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('A-D1 stacked typed field', () {
    EditableTextState editableOf(WidgetTester tester, String fieldKey) =>
        tester.state<EditableTextState>(
          find.descendant(
            of: measureStepper(fieldKey),
            matching: find.byType(EditableText),
          ),
        );

    // The widest typed value, «299,25» (3 digits, 2 decimals), whole at every
    // scale of the range on a 384 dp screen.
    for (final locale in const ['es', 'en']) {
      for (final scale in const [1.0, 1.3, 1.6, 2.0]) {
        testWidgets('$locale 384dp x$scale: «299,25» is whole', (tester) async {
          await _mount(
            tester,
            latest: _metric,
            locale: Locale(locale),
            size: const Size(384, 2340),
            textScale: scale,
          );
          await openMeasureSheet(tester, BodyZone.upperArm);
          final shown = locale == 'en' ? '299.25' : '299,25';
          await typeMeasure(tester, 'arm_left_cm', shown);
          expect(tester.takeException(), isNull);
          final state = editableOf(tester, 'arm_left_cm');
          final painter = TextPainter(
            text: TextSpan(text: shown, style: state.widget.style),
            textDirection: ui.TextDirection.ltr,
            textScaler: TextScaler.linear(scale),
          )..layout();
          final needed = painter.width;
          painter.dispose();
          expect(
            state.renderEditable.size.width,
            greaterThanOrEqualTo(needed),
            reason: 'field narrower than «$shown»',
          );
        });
      }
    }

    for (final locale in const ['es', 'en']) {
      testWidgets('$locale 384dp x2.0: stacked semantics keep value and '
          'actions, the unit is no extra node', (tester) async {
        final handle = tester.ensureSemantics();
        await _mount(
          tester,
          latest: _metric,
          locale: Locale(locale),
          size: const Size(384, 832),
          textScale: 2.0,
        );
        await openMeasureSheet(tester, BodyZone.upperArm);
        await typeMeasure(
          tester,
          'arm_left_cm',
          locale == 'en' ? '33.5' : '33,5',
        );
        await tester.pump();
        // Stacked: the ± sit under the field (the row would be on one line).
        final plus = tester.getRect(
          find.descendant(
            of: measureStepper('arm_left_cm'),
            matching: find.byIcon(ExomIcons.add),
          ),
        );
        final field = tester.getRect(
          find.descendant(
            of: measureStepper('arm_left_cm'),
            matching: find.byKey(ExomNumeralStepper.fieldKey),
          ),
        );
        expect(plus.top, greaterThanOrEqualTo(field.bottom - 0.5));

        // The control's node: the one carrying the ± actions. The widget's
        // semantics root is an ancestor that merges the whole scroll area.
        SemanticsNode? control;
        void seek(SemanticsNode n) {
          if (n.getSemanticsData().hasAction(SemanticsAction.increase) &&
              n.getSemanticsData().value.contains('33')) {
            control = n;
          }
          n.visitChildren((child) {
            seek(child);
            return true;
          });
        }

        seek(tester.getSemantics(measureStepper('arm_left_cm')));
        final node = control!;
        final data = node.getSemanticsData();
        final expected = locale == 'en' ? '33.5 cm' : '33,5 cm';
        expect(
          data.value.replaceAll(' ', ' '),
          expected,
          reason: 'the control announces value and unit',
        );
        expect(data.hasAction(SemanticsAction.increase), isTrue);
        expect(data.hasAction(SemanticsAction.decrease), isTrue);
        expect(data.increasedValue, isNotEmpty);
        expect(data.decreasedValue, isNotEmpty);

        // The «cm» painted between the ± is excluded: no node of its own
        // announces the unit, so it is read once, with the value.
        bool isUnitNode(SemanticsNode n) {
          final d = n.getSemanticsData();
          return d.label.trim() == 'cm' || d.value.trim() == 'cm';
        }

        var unitNodes = 0;
        void walk(SemanticsNode n) {
          if (isUnitNode(n)) unitNodes++;
          n.visitChildren((child) {
            walk(child);
            return true;
          });
        }

        walk(node);
        expect(unitNodes, 0);
        handle.dispose();
      });
    }

    testWidgets('a width change keeps focus, text and selection', (
      tester,
    ) async {
      await _mount(
        tester,
        latest: _metric,
        size: const Size(600, 900),
        textScale: 1.6,
      );
      await openMeasureSheet(tester, BodyZone.upperArm);
      await typeMeasure(tester, 'arm_left_cm', '33,');
      final before = editableOf(tester, 'arm_left_cm');
      before.widget.controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 2,
      );
      await tester.pump();
      final rowHeight = tester.getSize(measureStepper('arm_left_cm')).height;
      expect(before.widget.focusNode.hasFocus, isTrue);

      // Narrower: the row becomes the stacked form.
      tester.view.physicalSize = const Size(384, 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getSize(measureStepper('arm_left_cm')).height,
        greaterThan(rowHeight),
        reason: 'the stacked form is taller',
      );
      final after = editableOf(tester, 'arm_left_cm');
      expect(identical(after, before), isTrue, reason: 'not remounted');
      expect(after.widget.focusNode.hasFocus, isTrue);
      expect(after.widget.controller.text, '33,');
      expect(
        after.widget.controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 2),
      );

      // And back to the row.
      tester.view.physicalSize = const Size(600, 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final back = editableOf(tester, 'arm_left_cm');
      expect(identical(back, before), isTrue, reason: 'not remounted back');
      expect(back.widget.focusNode.hasFocus, isTrue);
      expect(back.widget.controller.text, '33,');
    });

    testWidgets('the error shows whole under the ± when stacked', (
      tester,
    ) async {
      await _mount(
        tester,
        latest: _metric,
        size: const Size(384, 832),
        textScale: 2.0,
      );
      final l10n = _l10n(tester);
      await openMeasureSheet(tester, BodyZone.upperArm);
      await typeMeasure(tester, 'arm_left_cm', ',');
      await tapMeasureDone(tester);
      expect(measureSheet(), findsOneWidget);
      // The user taps the field again: it and its whole error are revealed.
      await tester.tap(
        find.descendant(
          of: measureStepper('arm_left_cm'),
          matching: find.byKey(ExomNumeralStepper.fieldKey),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final message = find.text(
        l10n.measurementReviewTemplate(
          BodyZone.upperArm.label(l10n).toLowerCase(),
        ),
      );
      expect(message, findsOneWidget);
      final text = tester.getRect(message);
      final plus = tester.getRect(
        find.descendant(
          of: measureStepper('arm_left_cm'),
          matching: find.byIcon(ExomIcons.add),
        ),
      );
      expect(text.top, greaterThanOrEqualTo(plus.bottom - 0.5));
      // Inside the scrolling area, above the pinned «Hecho».
      final scroll = tester.getRect(
        find
            .descendant(
              of: measureSheet(),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      expect(text.top, greaterThanOrEqualTo(scroll.top));
      expect(text.bottom, lessThanOrEqualTo(scroll.bottom + 0.5));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: message, matching: find.byType(RichText)).first,
      );
      expect(paragraph.didExceedMaxLines, isFalse);
    });
  });

  group('L4-I16 focus in the sheet', () {
    testWidgets('typing focus survives a rotation of the screen', (
      tester,
    ) async {
      await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.upperArm);
      final numeral = find.descendant(
        of: measureStepper('arm_left_cm'),
        matching: find.byKey(ExomNumeralStepper.valueKey),
      );
      await tester.tap(numeral);
      await tester.pump();
      final field = find.descendant(
        of: measureStepper('arm_left_cm'),
        matching: find.byKey(ExomNumeralStepper.fieldKey),
      );
      bool focused() => tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus;
      expect(focused(), isTrue);
      // Portrait to landscape and back.
      tester.view.physicalSize = const Size(900, 390);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(field, findsOneWidget);
      expect(focused(), isTrue, reason: 'landscape');
      tester.view.physicalSize = const Size(390, 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(focused(), isTrue, reason: 'back to portrait');
      // The text typed before the rotation is still the one applied.
      await tester.enterText(field, '34');
      await tester.pump();
      await tapMeasureDone(tester);
      expect(measureValueText(tester, BodyZone.upperArm), 'I 34,0 · D 33,5 cm');
    });
  });

  group('L6 medidas menores', () {
    String numeral(WidgetTester tester, String key) => tester
        .widget<ExomNumeral>(
          find.descendant(
            of: measureStepper(key),
            matching: find.byType(ExomNumeral),
          ),
        )
        .value;

    // Issue 1: POST /metrics stores the measures as Float, so «33,25» is
    // saved as 33.25; the numeral must show that, not «33,3».
    for (final (locale, typed, shown, row, sent) in const [
      ('es', '33,25', '33,25', 'I 33,25 · D 33,5 cm', 33.25),
      ('en', '33.25', '33.25', 'L 33.25 · R 33.5 cm', 33.25),
      // A third decimal is rounded on input to the two the app shows.
      ('es', '33,256', '33,26', 'I 33,26 · D 33,5 cm', 33.26),
      // A typed half rounds up despite binary floating point: 1.005 * 100
      // is 100.4999…, which used to show and send 1,00.
      ('es', '1,005', '1,01', 'I 1,01 · D 33,5 cm', 1.01),
      ('es', '2,675', '2,68', 'I 2,68 · D 33,5 cm', 2.68),
    ]) {
      testWidgets('$locale typed «$typed» shows «$shown» and sends $sent', (
        tester,
      ) async {
        final repository = await _mount(
          tester,
          latest: _metric,
          locale: Locale(locale),
        );
        await openMeasureSheet(tester, BodyZone.upperArm);
        await typeMeasure(tester, 'arm_left_cm', typed);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(numeral(tester, 'arm_left_cm'), shown);
        await tapMeasureDone(tester);
        expect(measureValueText(tester, BodyZone.upperArm), row);
        await openMeasureSheet(tester, BodyZone.upperArm);
        expect(numeral(tester, 'arm_left_cm'), shown, reason: 'reopened');
        Navigator.of(tester.element(measureSheet())).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await _save(tester);
        expect(repository.saved.single['arm_left_cm'], sent);
      });
    }

    // Issue 2 (and the missing test of issue 4): a pair with only one side
    // measured. The empty side shows «—», never the other side's value, and
    // nothing is saved for it.
    testWidgets('a pair with one side: the empty side shows «—»', (
      tester,
    ) async {
      final repository = await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.thigh);
      expect(numeral(tester, 'thigh_left_cm'), '55,0');
      expect(numeral(tester, 'thigh_right_cm'), '—');
      expect(
        find.descendant(
          of: measureStepper('thigh_right_cm'),
          matching: find.textContaining('55', findRichText: true),
        ),
        findsNothing,
      );
      // Changing the measured side leaves the other one empty.
      await stepMeasure(tester, 'thigh_left_cm');
      expect(numeral(tester, 'thigh_right_cm'), '—');
      await tapMeasureDone(tester);
      expect(measureValueText(tester, BodyZone.thigh), 'I 55,5 · D —');
      await _save(tester);
      expect(repository.saved.single, {
        ..._datePayload(),
        'thigh_left_cm': 55.5,
      });
      expect(repository.saved.single.containsKey('thigh_right_cm'), isFalse);
    });

    testWidgets('a pair with one side drafted: the other side stays «—»', (
      tester,
    ) async {
      final repository = await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.forearm);
      await typeMeasure(tester, 'forearm_right_cm', '27,5');
      await tapMeasureDone(tester);
      await openMeasureSheet(tester, BodyZone.forearm);
      expect(numeral(tester, 'forearm_right_cm'), '27,5');
      expect(numeral(tester, 'forearm_left_cm'), '—');
      await tapMeasureDone(tester);
      expect(measureValueText(tester, BodyZone.forearm), 'I — · D 27,5 cm');
      await _save(tester);
      expect(repository.saved.single['forearm_right_cm'], 27.5);
      expect(repository.saved.single.containsKey('forearm_left_cm'), isFalse);
    });

    // A zone with no data at all showed its starting value («95,0») as if
    // it were measured. Every side without a value shows «—»; ± starts from
    // the seed of the zone.
    testWidgets('a single zone without data shows «—», ± starts at the seed', (
      tester,
    ) async {
      final repository = await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.hips);
      expect(numeral(tester, 'hips_cm'), '—');
      expect(
        find.descendant(
          of: measureStepper('hips_cm'),
          matching: find.textContaining('95', findRichText: true),
        ),
        findsNothing,
      );
      await stepMeasure(tester, 'hips_cm');
      expect(numeral(tester, 'hips_cm'), '95,5');
      await tapMeasureDone(tester);
      expect(measureValueText(tester, BodyZone.hips), '95,5 cm');
      await _save(tester);
      expect(repository.saved.single, {..._datePayload(), 'hips_cm': 95.5});
    });

    testWidgets('a pair without data: both sides «—», ± from the seed', (
      tester,
    ) async {
      final repository = await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.calf);
      expect(numeral(tester, 'calf_left_cm'), '—');
      expect(numeral(tester, 'calf_right_cm'), '—');
      await stepMeasure(tester, 'calf_left_cm', up: false);
      expect(numeral(tester, 'calf_left_cm'), '36,5');
      expect(numeral(tester, 'calf_right_cm'), '—');
      await tapMeasureDone(tester);
      // «Hecho» only returns the changed side.
      expect(measureValueText(tester, BodyZone.calf), 'I 36,5 · D —');
      await _save(tester);
      expect(repository.saved.single, {
        ..._datePayload(),
        'calf_left_cm': 36.5,
      });
    });

    testWidgets('a zone without data: «Hecho» untouched changes nothing', (
      tester,
    ) async {
      final repository = await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.shoulders);
      expect(numeral(tester, 'shoulders_cm'), '—');
      await tapMeasureDone(tester);
      expect(measureEdited(BodyZone.shoulders), findsNothing);
      await _save(tester);
      // L6-UX4: nothing changed, so nothing is sent.
      expect(repository.saved, isEmpty);
    });

    testWidgets('the empty side of a measured pair steps from the other', (
      tester,
    ) async {
      final repository = await _mount(tester, latest: _metric);
      await openMeasureSheet(tester, BodyZone.thigh);
      expect(numeral(tester, 'thigh_right_cm'), '—');
      await stepMeasure(tester, 'thigh_right_cm');
      expect(numeral(tester, 'thigh_right_cm'), '55,5');
      await tapMeasureDone(tester);
      expect(measureValueText(tester, BodyZone.thigh), 'I 55,0 · D 55,5 cm');
      await _save(tester);
      expect(repository.saved.single, {
        ..._datePayload(),
        'thigh_right_cm': 55.5,
      });
    });

    // Issue 3: the plates of a pair name their side.
    for (final (locale, left, right) in const [
      ('es', 'Brazo, lado izquierdo, 33,0 cm', 'Brazo, lado derecho, 33,5 cm'),
      ('en', 'Arm, left side, 33.0 cm', 'Arm, right side, 33.5 cm'),
    ]) {
      testWidgets('$locale plates of a pair name their side', (tester) async {
        await _mount(tester, latest: _metric, locale: Locale(locale));
        await _openBody(tester);
        final handle = tester.ensureSemantics();
        expect(find.bySemanticsLabel(left), findsOneWidget);
        expect(find.bySemanticsLabel(right), findsOneWidget);
        handle.dispose();
        final labelOf = tester
            .widget<RecapAnatomySelector>(find.byType(RecapAnatomySelector))
            .zoneLabelOf!;
        expect(labelOf('triceps_left'), left);
        expect(labelOf('triceps_right'), right);
      });
    }

    testWidgets('plates of a pair with one side: the empty one says so', (
      tester,
    ) async {
      await _mount(tester, latest: _metric);
      await _openBody(tester);
      final labelOf = tester
          .widget<RecapAnatomySelector>(find.byType(RecapAnatomySelector))
          .zoneLabelOf!;
      expect(labelOf('quadriceps_left'), 'Muslo, lado izquierdo, 55,0 cm');
      expect(labelOf('quadriceps_right'), 'Muslo, lado derecho, —');
      // Single zones keep their name and value.
      expect(labelOf('chest_left'), 'Pecho, 96,5 cm');
      expect(labelOf('chest_right'), 'Pecho, 96,5 cm');
    });

    // Issue 4: closing the sheet gives the focus back to its trigger.
    Future<FocusNode> focusRow(WidgetTester tester, BodyZone zone) async {
      await tester.scrollUntilVisible(
        measureRow(zone),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
      await tester.pump();
      final focus = Focus.of(
        tester.element(
          find
              .descendant(
                of: find.descendant(
                  of: measureRow(zone),
                  matching: find.byType(InkWell),
                ),
                matching: find.byType(Text),
              )
              .first,
        ),
      );
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);
      return focus;
    }

    Future<void> activate(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(measureSheet(), findsOneWidget);
    }

    testWidgets('focus returns to the row after «Hecho»', (tester) async {
      await _mount(tester, latest: _metric);
      final rowFocus = await focusRow(tester, BodyZone.upperArm);
      await activate(tester);
      expect(rowFocus.hasPrimaryFocus, isFalse, reason: 'focus in the sheet');
      await tapMeasureDone(tester);
      expect(measureSheet(), findsNothing);
      expect(rowFocus.hasPrimaryFocus, isTrue);
    });

    testWidgets('focus returns to the row after dismissing the sheet', (
      tester,
    ) async {
      await _mount(tester, latest: _metric);
      final rowFocus = await focusRow(tester, BodyZone.thigh);
      await activate(tester);
      Navigator.of(tester.element(measureSheet())).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(measureSheet(), findsNothing);
      expect(rowFocus.hasPrimaryFocus, isTrue);
    });
  });
}
