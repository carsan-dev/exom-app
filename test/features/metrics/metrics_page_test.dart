// L4 unit 2: Métricas on the V4 system. Presentation only: the bloc and the
// use cases are the real ones; the repository is a recording fake.
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
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
        locale: const Locale('es'),
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
            (style?.fontFamily?.contains('MaterialIcons') ?? false);
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
}
