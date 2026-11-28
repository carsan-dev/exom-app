import 'dart:io';

// L4-I11: section «06 Medidas corporales» of the metrics form at large system
// text. L6-D2 replaced the zone columns beside the old figure with a list of
// flat rows and the C5b figure: the checks are now on the rows (no overflow,
// no split name, no cut value, 48 dp targets) and on the figure and its view
// tabs. Uses the real DM Sans face: the default test font (Ahem) fakes widths.
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/models/body_zone.dart';
import 'package:exom_app/core/theme/app_theme.dart';
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
  final updates = <Map<String, dynamic>>[];

  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async {
    updates.add({...data});
    return _Profile();
  }
}

class _Storage extends LocalStorage {
  _Storage([this.unitSystem = UnitSystem.metric]);

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

class _Harness {
  _Harness(this.repository, this.profile);
  final _Repository repository;
  final _ProfileRepository profile;
}

Future<_Harness> _mount(
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
  final profile = _ProfileRepository();
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerFactory<MetricsBloc>(
    () => MetricsBloc(
      saveMetricUseCase: SaveMetricUseCase(repository),
      metricsRepository: repository,
      updateProfileUseCase: UpdateProfileUseCase(profile),
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
  // The page is pushed (as the router does) so that a successful save can pop.
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      // «Today» is the day of the loaded record, so the initial «latest» load
      // answers the record of the selected day (L6-UX7 b).
      builder: (_) => MetricsFormPage(clock: () => (latest ?? _metric).date),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return _Harness(repository, profile);
}

Future<void> _openBodyMap(WidgetTester tester) async {
  final l10n = AppLocalizations.of(
    tester.element(find.byType(MetricsFormPage)),
  );
  await tester.scrollUntilVisible(
    find.text(l10n.bodyViewToggle),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(l10n.bodyViewToggle));
  await tester.pump();
  await tester.tap(find.text(l10n.bodyViewToggle));
  await tester.pump();
}

const _zones = [
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

/// Whether the paragraph of [text] lays out in a single line.
void _expectOneLine(WidgetTester tester, Finder text, String reason) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final oneLine = TextPainter(
    text: paragraph.text,
    textDirection: TextDirection.ltr,
    textScaler: paragraph.textScaler,
  )..layout();
  expect(
    paragraph.size.height,
    lessThanOrEqualTo(oneLine.height + 0.5),
    reason: '$reason wraps inside the word',
  );
  oneLine.dispose();
}

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
  });
  tearDown(sl.reset);

  // Was «zone columns never overflow nor split a name»: the same widths and
  // scales on the rows that replaced the columns. Each row keeps its name on
  // one line, a 48 dp target inside the screen, its whole value (moved under
  // the name when they do not fit together, still at the end) and opens the
  // sheet of its zone.
  group('measure rows never overflow, split a name nor cut a value', () {
    for (final locale in const ['es', 'en']) {
      for (final width in const [320.0, 360.0, 390.0, 412.0]) {
        for (final scale in const [1.0, 1.3, 1.31, 1.35, 1.5, 2.0]) {
          testWidgets('$locale ${width}dp x$scale', (tester) async {
            await _mount(
              tester,
              latest: _metric,
              size: Size(width, 900),
              textScale: scale,
              locale: Locale(locale),
            );
            expect(tester.takeException(), isNull);
            final l10n = AppLocalizations.of(
              tester.element(find.byType(MetricsFormPage)),
            );
            for (final zone in _zones) {
              final label = zone.label(l10n);
              // Zone names are single words: one line means none is split.
              expect(label.contains(' '), isFalse, reason: label);
              await tester.scrollUntilVisible(
                measureRow(zone),
                200,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pump();
              final name = find.descendant(
                of: measureRow(zone),
                matching: find.text(label),
              );
              expect(name, findsOneWidget, reason: label);
              _expectOneLine(tester, name, label);
              final row = tester.getRect(measureRow(zone));
              expect(row.height, greaterThanOrEqualTo(48), reason: label);
              expect(row.left, greaterThanOrEqualTo(0), reason: label);
              expect(row.right, lessThanOrEqualTo(width), reason: label);
              final value = tester.getRect(measureValue(zone));
              expect(value.left, greaterThanOrEqualTo(row.left), reason: label);
              expect(value.right, lessThanOrEqualTo(row.right), reason: label);
              expect(value.top, greaterThanOrEqualTo(row.top), reason: label);
              expect(
                value.bottom,
                lessThanOrEqualTo(row.bottom),
                reason: label,
              );
              final nameRect = tester.getRect(name);
              if (value.top >= nameRect.bottom) {
                // Under the name: still at the end of the row, past the name.
                expect(
                  value.right,
                  greaterThan(nameRect.right),
                  reason: '$label value at the end',
                );
              }
            }
            // Opening a row shows the sheet of its zone without overflow.
            await openMeasureSheet(tester, BodyZone.upperArm);
            expect(tester.takeException(), isNull);
            expect(measureSheet(), findsOneWidget);
            expect(
              find.descendant(
                of: measureSheet(),
                matching: find.text(
                  BodyZone.upperArm.label(l10n).toUpperCase(),
                ),
              ),
              findsOneWidget,
            );
          });
        }
      }
    }
  });

  // Was «side-by-side layout» and «stacked layout»: there are no zone columns
  // any more. The figure keeps its size, centred and inside the screen, at
  // every width and scale, front and back.
  group('body view keeps the figure inside the screen', () {
    for (final locale in const ['es', 'en']) {
      for (final (width, scale) in const [
        (320.0, 1.0),
        (320.0, 2.0),
        (390.0, 1.0),
        (390.0, 1.3),
        (412.0, 2.0),
      ]) {
        testWidgets('$locale ${width}dp x$scale', (tester) async {
          await _mount(
            tester,
            latest: _metric,
            size: Size(width, 900),
            textScale: scale,
            locale: Locale(locale),
          );
          await _openBodyMap(tester);
          expect(tester.takeException(), isNull);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(MetricsFormPage)),
          );
          final figure = find.descendant(
            of: find.byType(RecapAnatomySelector),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is CustomPaint && w.painter != null && w.size.height > 200,
            ),
          );
          for (final view in [l10n.frontViewLabel, l10n.backViewLabel]) {
            await tester.ensureVisible(find.text(view));
            await tester.pump();
            await tester.tap(find.text(view));
            await tester.pump(const Duration(milliseconds: 300));
            final rect = tester.getRect(figure);
            expect(rect.height, 450, reason: view);
            expect(rect.left, greaterThanOrEqualTo(0), reason: view);
            expect(rect.right, lessThanOrEqualTo(width), reason: view);
            expect(
              (rect.center.dx - width / 2).abs(),
              lessThan(1),
              reason: '$view centred',
            );
            expect(tester.takeException(), isNull, reason: view);
          }
          final hint = find.text(l10n.metricsMeasureTapZone);
          await tester.ensureVisible(hint);
          await tester.pump();
          expect(tester.getRect(hint).right, lessThanOrEqualTo(width - 20));
        });
      }
    }
  });

  // Was «L4-I14 measure hints follow the locale decimal separator»: the empty
  // fields and their «0,0» hints are gone; the figures of the list and of the
  // sheet stepper carry the separator now, in metric and imperial.
  group('L4-I14 measure figures follow the locale decimal separator', () {
    for (final (locale, imperialList, imperialFigure, metricList) in const [
      ('es', '29,1 in', '29,1', '74,0 cm'),
      ('en', '29.1 in', '29.1', '74.0 cm'),
    ]) {
      testWidgets('$locale imperial shows $imperialList', (tester) async {
        await _mount(
          tester,
          latest: _metric,
          locale: Locale(locale),
          unitSystem: UnitSystem.imperial,
          size: const Size(390, 3000),
        );
        expect(measureValueText(tester, BodyZone.waist), imperialList);
        await openMeasureSheet(tester, BodyZone.waist);
        expect(
          find.descendant(
            of: measureStepper('waist_cm'),
            matching: find.textContaining(imperialFigure, findRichText: true),
          ),
          findsWidgets,
        );
        final other = locale == 'es' ? '29.1' : '29,1';
        expect(
          find.descendant(
            of: measureStepper('waist_cm'),
            matching: find.textContaining(other, findRichText: true),
          ),
          findsNothing,
        );
      });

      testWidgets('$locale metric shows $metricList', (tester) async {
        await _mount(
          tester,
          latest: _metric,
          locale: Locale(locale),
          size: const Size(390, 3000),
        );
        expect(measureValueText(tester, BodyZone.waist), metricList);
        expect(
          measureValueText(tester, BodyZone.upperArm),
          locale == 'es' ? 'I 35,0 · D 36,0 cm' : 'L 35.0 · R 36.0 cm',
        );
      });
    }
  });

  group('L4-I18 view tabs', () {
    for (final locale in const ['es', 'en']) {
      for (final width in const [360.0, 320.0]) {
        for (final scale in const [1.0, 1.3, 1.6]) {
          testWidgets('$locale ${width}dp x$scale', (tester) async {
            await _mount(
              tester,
              latest: _metric,
              size: Size(width, 900),
              textScale: scale,
              locale: Locale(locale),
            );
            await _openBodyMap(tester);
            final l10n = AppLocalizations.of(
              tester.element(find.byType(MetricsFormPage)),
            );
            for (final label in [l10n.frontViewLabel, l10n.backViewLabel]) {
              final text = find.text(label);
              await tester.ensureVisible(text);
              await tester.pump();
              final tab = find
                  .ancestor(of: text, matching: find.byType(GestureDetector))
                  .first;
              final box = tester.getRect(tab);
              final textRect = tester.getRect(text);
              final paragraph = tester.renderObject<RenderParagraph>(text);
              // Segment padding of ExomSegmentedControl (8 dp each side).
              const gap = 8;
              expect(tester.takeException(), isNull, reason: label);
              expect(box.height, greaterThanOrEqualTo(48), reason: label);
              expect(
                textRect.left - box.left,
                greaterThanOrEqualTo(gap - 0.01),
                reason: '$label touches the left edge of its tab',
              );
              expect(
                box.right - textRect.right,
                greaterThanOrEqualTo(gap - 0.01),
                reason: '$label touches the right edge of its tab',
              );
              expect(
                paragraph.text.style!.fontSize! * paragraph.textScaler.scale(1),
                greaterThanOrEqualTo(13),
                reason: '$label is painted below 13 px',
              );
            }
          });
        }
      }
    }
  });
}
