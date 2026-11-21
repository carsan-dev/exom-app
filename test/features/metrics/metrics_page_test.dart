// L4 unit 2: Métricas on the V4 system. Presentation only: the bloc and the
// use cases are the real ones; the repository is a recording fake.
import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/models/body_zone.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/anatomy_selector.dart';
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
import 'package:intl/intl.dart';

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
  _Repository(this.latest, {this.gate});

  final BodyMetricEntity? latest;

  /// When set, the latest metric does not arrive until it completes.
  final Completer<void>? gate;
  final saved = <Map<String, dynamic>>[];

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async {
    await gate?.future;
    return latest;
  }

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
  _Storage(this.profile);

  /// The cached `profile_me` document.
  final Map<String, dynamic>? profile;

  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => null;
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
  @override
  Map<String, dynamic>? getCachedMap(String key) =>
      key == 'profile_me' ? profile : null;
}

class _Harness {
  _Harness(this.repository, this.profile, this.theme);
  final _Repository repository;
  final _ProfileRepository profile;

  /// The app theme: changing it notifies the page's inherited dependencies.
  final ValueNotifier<ThemeData> theme;
}

Future<_Harness> _mount(
  WidgetTester tester, {
  BodyMetricEntity? latest,
  ThemeData? theme,
  Size size = const Size(390, 900),
  double textScale = 1.0,
  Locale locale = const Locale('es'),
  Map<String, dynamic>? profileCache,
  Completer<void>? latestGate,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final storage = _Storage(profileCache);
  final repository = _Repository(latest, gate: latestGate);
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
  final themeNotifier = ValueNotifier<ThemeData>(theme ?? AppTheme.dark);
  addTearDown(themeNotifier.dispose);
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>(
      create: (_) => AppPreferencesCubit(storage),
      child: ValueListenableBuilder<ThemeData>(
        valueListenable: themeNotifier,
        builder: (context, currentTheme, _) => MaterialApp(
          navigatorKey: navigatorKey,
          theme: currentTheme,
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
    ),
  );
  // The page is pushed (as the router does) so that a successful save can pop.
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => const MetricsFormPage()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return _Harness(repository, profile, themeNotifier);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MetricsFormPage)));

/// Every painted text run with its effective font size. Icon glyphs (icon
/// fonts) are not text and are skipped.
List<({String text, double size})> _textRuns(WidgetTester tester) {
  final runs = <({String text, double size})>[];
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    void visit(InlineSpan span, TextStyle? inherited) {
      final style = inherited?.merge(span.style) ?? span.style;
      if (span is TextSpan) {
        final text = span.text;
        final isIcon =
            style?.fontFamily == 'MaterialIcons' ||
            (style?.fontFamily?.contains('MaterialIcons') ?? false) ||
            (style?.fontFamily?.contains('Lucide') ?? false);
        if (text != null && text.trim().isNotEmpty && !isIcon) {
          runs.add((text: text, size: style?.fontSize ?? 14.0));
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, style);
        }
      }
    }

    visit(richText.text, null);
  }
  return runs;
}

void _expectNoTextBelow13(WidgetTester tester) {
  final runs = _textRuns(tester);
  expect(runs, isNotEmpty);
  final small = runs.where((run) => run.size < 13).toList();
  expect(
    small,
    isEmpty,
    reason:
        'text below 13 logical px: ${small.map((r) => '"${r.text}" ${r.size}').join(', ')}',
  );
}

/// The save button label may be painted in capitals: match case-insensitively.
Finder _saveButton(AppLocalizations l10n) {
  final wanted = l10n.saveMetricsButton.toLowerCase();
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data?.toLowerCase() == wanted,
  );
}

Finder _fieldOfLabel(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextFormField),
);

Finder _fieldWithText(String text) => find.byWidgetPredicate(
  (w) => w is TextFormField && w.controller?.text == text,
);

/// Scrolls [target] clear of the pinned save bar so it can be tapped.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
  await tester.pump();
}

void main() {
  // The body map picks side-by-side or stacked zones by measuring the names,
  // so it needs the real DM Sans face: the default test font (Ahem) is far
  // wider and would always stack them.
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

  group('text size floor (13 px)', () {
    testWidgets('with a loaded metric', (tester) async {
      await _mount(tester, latest: _metric);
      _expectNoTextBelow13(tester);
    });

    testWidgets('with a loaded metric, scrolled to the measurements', (
      tester,
    ) async {
      await _mount(tester, latest: _metric);
      await _scrollTo(tester, find.text('Cintura'));
      _expectNoTextBelow13(tester);
    });

    testWidgets('empty day, manual weight entry', (tester) async {
      await _mount(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.text(l10n.manualEntryToggle), findsOneWidget);
      _expectNoTextBelow13(tester);
    });

    testWidgets('body map with a selected zone', (tester) async {
      await _mount(tester, latest: _metric);
      final l10n = _l10n(tester);
      await _scrollTo(tester, find.text(l10n.bodyViewToggle));
      await tester.tap(find.text(l10n.bodyViewToggle));
      await tester.pump();
      _expectNoTextBelow13(tester);
    });

    testWidgets('320 dp wide at 1.3x text keeps every section laid out', (
      tester,
    ) async {
      await _mount(
        tester,
        latest: _metric,
        size: const Size(320, 800),
        textScale: 1.3,
      );
      final l10n = _l10n(tester);
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, find.text(l10n.bodyViewToggle));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.bodyViewToggle));
      await tester.pump();
      expect(tester.takeException(), isNull);
      _expectNoTextBelow13(tester);
    });

    testWidgets('light theme', (tester) async {
      await _mount(tester, latest: _metric, theme: AppTheme.light);
      _expectNoTextBelow13(tester);
    });

    testWidgets('muscle mass estimate dialog', (tester) async {
      await _mount(tester, latest: _metric);
      final l10n = _l10n(tester);
      await _scrollTo(tester, find.text(l10n.calculateEstimateButton));
      await tester.tap(find.text(l10n.calculateEstimateButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      _expectNoTextBelow13(tester);
    });
  });

  group('body map alignment', () {
    testWidgets('zone columns are as tall as the rendered body; tabs >= 48', (
      tester,
    ) async {
      await _mount(tester, latest: _metric);
      final l10n = _l10n(tester);
      await _scrollTo(tester, find.text(l10n.bodyViewToggle));
      await tester.tap(find.text(l10n.bodyViewToggle));
      await tester.pump();

      final bodyHeight = tester
          .getSize(
            find
                .descendant(
                  of: find.byType(AnatomySelector),
                  matching: find.byType(CustomPaint),
                )
                .first,
          )
          .height;
      final columns = find.byWidgetPredicate(
        (w) =>
            w is Align &&
            (w.alignment == Alignment.topRight ||
                w.alignment == Alignment.topLeft) &&
            w.child is SizedBox,
      );
      expect(columns, findsNWidgets(2));
      for (final column in columns.evaluate()) {
        final box = find.descendant(
          of: find.byWidget(column.widget),
          matching: find.byType(SizedBox),
        );
        expect(tester.getSize(box.first).height, bodyHeight);
      }

      for (final label in [l10n.frontViewLabel, l10n.backViewLabel]) {
        final tab = find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first;
        expect(tester.getSize(tab).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('existing actions', () {
    testWidgets('saving without edits sends the loaded values and the date', (
      tester,
    ) async {
      final h = await _mount(tester, latest: _metric);
      final l10n = _l10n(tester);
      await tester.tap(_saveButton(l10n));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      expect(h.repository.saved, hasLength(1));
      expect(h.repository.saved.single, {
        'date': today,
        'height_cm': 180.0,
        'weight_kg': 68.4,
        'sleep_hours': 7.5,
        'muscle_mass_kg': 32.5,
        'chest_cm': 100.0,
        'arm_left_cm': 35.0,
        'arm_right_cm': 36.0,
        'waist_cm': 74.0,
      });
      expect(h.profile.updates, [
        {'height': 180.0},
      ]);
    });

    testWidgets('editing a measure sends the edited value', (tester) async {
      final h = await _mount(tester, latest: _metric);
      final l10n = _l10n(tester);
      await _scrollTo(tester, find.text('Cintura'));
      await tester.enterText(_fieldOfLabel('Cintura'), '73,5');
      await tester.pump();
      await tester.tap(_saveButton(l10n));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.repository.saved.single['waist_cm'], 73.5);
    });

    testWidgets('the date button opens the date picker', (tester) async {
      await _mount(tester, latest: _metric);
      final l10n = _l10n(tester);
      await tester.tap(find.text(l10n.todayLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('an empty day saves only the date', (tester) async {
      final h = await _mount(tester);
      final l10n = _l10n(tester);
      await tester.tap(_saveButton(l10n));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.repository.saved, hasLength(1));
      expect(h.repository.saved.single.keys, ['date']);
    });
  });

  group('L4-I4 decimal separator', () {
    final decimals = BodyMetricEntity(
      id: 'metric-2',
      date: DateTime(2026, 11, 18),
      weightKg: 68.4,
      heightCm: 180.5,
      muscleMassKg: 32.5,
      sleepHours: 7.5,
      waistCm: 74.5,
      armLeftCm: 35.5,
      armRightCm: 36,
    );

    List<String> fieldTexts(WidgetTester tester) => [
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      ))
        if (field.controller!.text.isNotEmpty) field.controller!.text,
    ];

    testWidgets('es shows the loaded values with a comma', (tester) async {
      await _mount(tester, latest: decimals, size: const Size(390, 6000));
      expect(
        fieldTexts(tester),
        containsAll(['180,5', '32,5', '7,5', '74,5', '35,5', '36,0']),
      );
      expect(fieldTexts(tester).where((t) => t.contains('.')), isEmpty);
      expect(find.text('68,4 kg'), findsOneWidget);
    });

    testWidgets('en shows the loaded values with a point', (tester) async {
      await _mount(
        tester,
        latest: decimals,
        size: const Size(390, 6000),
        locale: const Locale('en'),
      );
      expect(
        fieldTexts(tester),
        containsAll(['180.5', '32.5', '7.5', '74.5', '35.5', '36.0']),
      );
      expect(fieldTexts(tester).where((t) => t.contains(',')), isEmpty);
      expect(find.text('68.4 kg'), findsOneWidget);
    });

    testWidgets('choosing sleep hours fills the field with the locale sep', (
      tester,
    ) async {
      await _mount(tester, latest: decimals, size: const Size(390, 6000));
      await tester.tap(find.text('9 h'));
      await tester.pump();
      expect(fieldTexts(tester), contains('9,0'));
    });

    // Typed entries: the event sent to the bloc is the same number as before
    // this change (characterisation of the unchanged parser).
    for (final locale in [const Locale('es'), const Locale('en')]) {
      group('typed entries (${locale.languageCode})', () {
        final cases = <String, double?>{
          '78,6': 78.6,
          '78.6': 78.6,
          '78': 78.0,
          ' 78,60 ': 78.6,
          '': null,
        };
        for (final entry in cases.entries) {
          testWidgets('waist "${entry.key}" sends ${entry.value}', (
            tester,
          ) async {
            final h = await _mount(tester, latest: _metric, locale: locale);
            final l10n = _l10n(tester);
            final label = BodyZone.waist.label(l10n);
            await _scrollTo(tester, find.text(label));
            await tester.enterText(_fieldOfLabel(label), entry.key);
            await tester.pump();
            await tester.tap(_saveButton(l10n));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(h.repository.saved, hasLength(1));
            expect(h.repository.saved.single['waist_cm'], entry.value);
          });
        }
        for (final raw in ['78,6,1', 'abc', ',']) {
          testWidgets('waist "$raw" is rejected, nothing is sent', (
            tester,
          ) async {
            final h = await _mount(tester, latest: _metric, locale: locale);
            final l10n = _l10n(tester);
            final label = BodyZone.waist.label(l10n);
            await _scrollTo(tester, find.text(label));
            await tester.enterText(_fieldOfLabel(label), raw);
            await tester.pump();
            await tester.tap(_saveButton(l10n));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(h.repository.saved, isEmpty);
            expect(find.byType(SnackBar), findsOneWidget);
          });
        }
      });
    }

    testWidgets('left/right pair accepts comma and point in any locale', (
      tester,
    ) async {
      final h = await _mount(
        tester,
        latest: _metric,
        locale: const Locale('en'),
      );
      final l10n = _l10n(tester);
      final label = BodyZone.upperArm.label(l10n);
      await _scrollTo(tester, find.text(label));
      final fields = find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), '35,5');
      await tester.enterText(fields.at(1), '36.5');
      await tester.pump();
      await tester.tap(_saveButton(l10n));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.repository.saved.single['arm_left_cm'], 35.5);
      expect(h.repository.saved.single['arm_right_cm'], 36.5);
    });

    testWidgets('sleep field accepts "7,5"', (tester) async {
      final h = await _mount(
        tester,
        latest: _metric,
        size: const Size(390, 6000),
      );
      final l10n = _l10n(tester);
      final sleep = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller!.text == '7,5',
      );
      await tester.enterText(sleep, '6,25');
      await tester.pump();
      await tester.tap(_saveButton(l10n));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.repository.saved.single['sleep_hours'], 6.25);
    });
  });

  group('profile preload and SEEN estimate', () {
    const profile = <String, dynamic>{
      'height': 180,
      'current_weight': 72.5,
      'birth_date': '1990-01-01',
      'sex': 'male',
    };

    for (final (locale, height, weight) in const [
      ('es', '180,0', '72,5'),
      ('en', '180.0', '72.5'),
    ]) {
      testWidgets('$locale: the cached profile fills height and weight with '
          'the locale separator', (tester) async {
        // The latest metric never arrives: only the profile preload fills.
        await _mount(
          tester,
          profileCache: profile,
          locale: Locale(locale),
          latestGate: Completer<void>(),
          size: const Size(390, 6000),
        );
        expect(_fieldWithText(height), findsOneWidget);
        // The weight field is shown in manual entry mode.
        await tester.tap(find.byType(Switch));
        await tester.pump();
        expect(_fieldWithText(weight), findsOneWidget);
      });
    }

    testWidgets('a dependency change after typing does not overwrite it', (
      tester,
    ) async {
      final h = await _mount(
        tester,
        profileCache: profile,
        latestGate: Completer<void>(),
        size: const Size(390, 6000),
      );
      await tester.tap(find.byType(Switch));
      await tester.pump();
      final height = tester
          .widget<TextFormField>(_fieldWithText('180,0'))
          .controller!;
      final weight = tester
          .widget<TextFormField>(_fieldWithText('72,5'))
          .controller!;
      // A theme change notifies the page's inherited dependencies (so would
      // a locale or keyboard change).
      Future<void> changeDependencies(ThemeData theme) async {
        h.theme.value = theme;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      await tester.enterText(_fieldWithText('180,0'), '175,5');
      await tester.enterText(_fieldWithText('72,5'), '80,5');
      await changeDependencies(AppTheme.light);
      expect(height.text, '175,5');
      expect(weight.text, '80,5');

      // A field the user emptied stays empty: the preload runs once.
      height.clear();
      weight.clear();
      await changeDependencies(AppTheme.dark);
      expect(height.text, isEmpty);
      expect(weight.text, isEmpty);
    });

    for (final (locale, estimatePattern, asmiPattern) in [
      ('es', RegExp(r'\d+,\d kg '), RegExp(r'ASMI \d+,\d{2} kg/m²')),
      ('en', RegExp(r'\d+\.\d kg '), RegExp(r'ASMI \d+\.\d{2} kg/m²')),
    ]) {
      testWidgets('$locale: the SEEN notice uses the locale separator', (
        tester,
      ) async {
        await _mount(
          tester,
          // The calf of the loaded metric prefills the dialog, so no field is
          // focused (a focus change rebuilds fields whose controllers the
          // page has already disposed when the dialog closes).
          latest: BodyMetricEntity(
            id: 'metric-2',
            date: DateTime(2026, 11, 18),
            heightCm: 180,
            calfLeftCm: 38.5,
            calfRightCm: 38.5,
          ),
          profileCache: profile,
          locale: Locale(locale),
          size: const Size(390, 1600),
        );
        final l10n = _l10n(tester);
        await _scrollTo(tester, find.text(l10n.calculateEstimateButton));
        await tester.tap(find.text(l10n.calculateEstimateButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(l10n.calculateAndUseButton));
        // A single frame: the dialog's controllers are disposed as it closes.
        await tester.pump();
        final notice = find.byType(SnackBar);
        expect(notice, findsOneWidget);
        final text = tester
            .widget<Text>(
              find.descendant(of: notice, matching: find.byType(Text)),
            )
            .data!;
        expect(text, contains(estimatePattern));
        expect(text, contains(asmiPattern));
      });
    }
  });
}
