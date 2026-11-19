import 'dart:io';

// L4-I11: body-map zone columns of the metrics form at large system text.
// Uses the real DM Sans face: the default test font (Ahem) fakes widths.
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
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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
  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => null;
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final storage = _Storage();
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
    MaterialPageRoute<void>(builder: (_) => const MetricsFormPage()),
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

const _baseline = <String, String>{
  'es 390.0 1.0':
      'neck:20.00,332.00,95.42,48.00 shoulders:20.00,395.11,95.42,48.00 chest:20.00,473.33,95.42,49.00 waist:20.00,552.56,95.42,49.00 hips:20.00,631.78,95.42,48.00 upperArm:274.58,381.80,95.42,68.00 forearm:274.58,466.40,95.42,48.00 thigh:274.58,564.20,95.42,48.00 calf:274.58,645.40,95.42,48.00',
  'en 390.0 1.0':
      'neck:20.00,332.00,95.42,48.00 shoulders:20.00,395.11,95.42,48.00 chest:20.00,473.33,95.42,49.00 waist:20.00,552.56,95.42,49.00 hips:20.00,631.78,95.42,48.00 upperArm:274.58,381.80,95.42,68.00 forearm:274.58,466.40,95.42,48.00 thigh:274.58,564.20,95.42,48.00 calf:274.58,645.40,95.42,48.00',
};

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

/// The tappable zone control that wraps the zone name.
Finder _zoneControl(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
    .first;

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

  group('zone columns never overflow nor split a name', () {
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
            await _openBodyMap(tester);
            expect(tester.takeException(), isNull);
            final l10n = AppLocalizations.of(
              tester.element(find.byType(MetricsFormPage)),
            );
            for (final zone in _zones) {
              final label = zone.label(l10n);
              final text = find.text(label);
              expect(text, findsOneWidget, reason: label);
              await tester.ensureVisible(text);
              await tester.pump();
              final paragraph = tester.renderObject<RenderParagraph>(text);
              // Zone names are single words: one line means none is split.
              expect(label.contains(' '), isFalse, reason: label);
              final oneLine = TextPainter(
                text: paragraph.text,
                textDirection: TextDirection.ltr,
                textScaler: paragraph.textScaler,
              )..layout();
              expect(
                paragraph.size.height,
                lessThanOrEqualTo(oneLine.height + 0.5),
                reason: '$label wraps inside the word',
              );
              final rect = tester.getRect(_zoneControl(label));
              expect(rect.height, greaterThanOrEqualTo(48), reason: label);
              expect(rect.left, greaterThanOrEqualTo(0), reason: label);
              expect(rect.right, lessThanOrEqualTo(width), reason: label);
              // Tapping selects the zone: its editor appears next to the
              // zone control, both showing the zone name.
              await tester.tap(_zoneControl(label));
              await tester.pump();
              expect(text, findsNWidgets(2), reason: '$label: editor');
              expect(tester.takeException(), isNull, reason: label);
              // The selected name is painted bold: it must still be one
              // line, and selecting must not change the layout.
              final selected = find.descendant(
                of: _zoneControl(label),
                matching: find.text(label),
              );
              final selectedParagraph = tester.renderObject<RenderParagraph>(
                selected,
              );
              final selectedOneLine = TextPainter(
                text: selectedParagraph.text,
                textDirection: TextDirection.ltr,
                textScaler: selectedParagraph.textScaler,
              )..layout();
              expect(
                selectedParagraph.size.height,
                lessThanOrEqualTo(selectedOneLine.height + 0.5),
                reason: '$label selected wraps inside the word',
              );
              expect(
                selectedParagraph.text.style?.fontWeight,
                FontWeight.w700,
                reason: '$label selected is bold',
              );
              expect(
                tester.getRect(_zoneControl(label)),
                rect,
                reason: '$label: selecting moves the control',
              );
            }
          });
        }
      }
    }
  });

  group('side-by-side layout is kept where the names fit', () {
    // Zone control rects (left, top, width, height) of the default case
    // (390 dp, 1.0x), measured on the layout before this change.
    for (final locale in const ['es', 'en']) {
      testWidgets('$locale 390dp x1.0', (tester) async {
        await _mount(tester, latest: _metric, locale: Locale(locale));
        await _openBodyMap(tester);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(MetricsFormPage)),
        );
        final out = <String>[];
        for (final zone in _zones) {
          final r = tester.getRect(_zoneControl(zone.label(l10n)));
          out.add(
            '${zone.name}:${r.left.toStringAsFixed(2)},'
            '${r.top.toStringAsFixed(2)},${r.width.toStringAsFixed(2)},'
            '${r.height.toStringAsFixed(2)}',
          );
        }
        expect(tester.takeException(), isNull);
        expect(out.join(' '), _baseline['$locale 390.0 1.0']);
      });
    }
  });

  group('stacked layout when the names do not fit the side columns', () {
    // The layout follows the width of the column and the text scale: these
    // combinations were side by side before and split a name or overflowed.
    for (final locale in const ['es', 'en']) {
      for (final (width, scale) in const [(390.0, 1.3), (320.0, 1.0)]) {
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
          final rects = [
            for (final zone in _zones)
              tester.getRect(_zoneControl(zone.label(l10n))),
          ];
          expect(tester.takeException(), isNull);
          // One column: same left edge and width, none above the previous.
          for (final r in rects) {
            expect(r.left, rects.first.left);
            expect(r.width, rects.first.width);
          }
          final tops = rects.map((r) => r.top).toList()..sort();
          expect(tops.toSet().length, rects.length);
        });
      }
    }
  });
}
