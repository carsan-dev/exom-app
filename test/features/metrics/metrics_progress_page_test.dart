// L4 unit 4: «Progreso» frame of Métricas. Real bloc and use cases; the
// repository is a recording fake. The day form it opens is covered by
// metrics_page_test.dart.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_page.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_progress_page.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

BodyMetricEntity _w(int month, int day, double kg) => BodyMetricEntity(
  id: 'w-$month-$day',
  date: DateTime(2026, month, day),
  weightKg: kg,
);

/// Eight weekly weights, 30 Sep → 18 Nov 2026 (49 days = 7 weeks).
final _weekly = [
  _w(9, 30, 70.9),
  _w(10, 7, 70.6),
  _w(10, 14, 70.4),
  _w(10, 21, 69.9),
  _w(10, 28, 69.6),
  _w(11, 4, 69.2),
  _w(11, 11, 68.8),
  _w(11, 18, 68.4),
];

final _latest = BodyMetricEntity(
  id: 'latest',
  date: DateTime(2026, 11, 18),
  weightKg: 68.4,
  waistCm: 74,
);

class _Repository extends Fake
    implements MetricsRepository, MetricsHistorySource {
  _Repository({required this.history, this.latest});

  bool historyFromCache = false;
  bool latestFromCache = false;

  List<BodyMetricEntity> history;
  BodyMetricEntity? latest;
  Object? historyError;
  Object? latestError;
  int historyCalls = 0;
  final saved = <Map<String, dynamic>>[];

  /// While set, the history read waits for it (a request that has not been
  /// answered yet); the error is checked after the wait.
  Completer<void>? historyGate;

  @override
  Future<List<BodyMetricEntity>> getWeightHistory() async {
    historyCalls++;
    final gate = historyGate;
    if (gate != null) await gate.future;
    final error = historyError;
    if (error != null) throw error;
    return history;
  }

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async {
    final error = latestError;
    if (error != null) throw error;
    return latest;
  }

  @override
  Future<MetricsRead<List<BodyMetricEntity>>>
  getWeightHistoryWithSource() async =>
      MetricsRead(await getWeightHistory(), fromCache: historyFromCache);

  @override
  Future<MetricsRead<BodyMetricEntity?>> getLatestMetricWithSource() async =>
      MetricsRead(await getLatestMetric(), fromCache: latestFromCache);

  @override
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data) async {
    saved.add({...data});
    return latest ?? _latest;
  }
}

class _Profile extends Fake implements ProfileEntity {}

class _ProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async =>
      _Profile();
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
  _Harness(this.repository, this.router);
  final _Repository repository;
  final GoRouter router;
}

Future<_Harness> _mount(
  WidgetTester tester, {
  required _Repository repository,
  ThemeData? theme,
  // Tall enough for the whole screen: the redesign adds a headline and the
  // featured block above the measurements, so a retry in the notice would
  // otherwise sit below the fold.
  Size size = const Size(390, 1400),
  double textScale = 1.0,
  bool disableAnimations = false,
  Locale locale = const Locale('es'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final storage = _Storage();
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerFactory<MetricsBloc>(
    () => MetricsBloc(
      saveMetricUseCase: SaveMetricUseCase(repository),
      metricsRepository: repository,
      updateProfileUseCase: UpdateProfileUseCase(_ProfileRepository()),
    ),
  );
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: AppRoutes.metrics,
        builder: (_, _) => const MetricsProgressPage(),
      ),
      GoRoute(
        path: AppRoutes.progressPhotos,
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('photos-destination'))),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>(
      create: (_) => AppPreferencesCubit(storage),
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme ?? AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
      ),
    ),
  );
  router.push(AppRoutes.metrics);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return _Harness(repository, router);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MetricsProgressPage)));

List<({String text, double size})> _textRuns(WidgetTester tester) {
  final runs = <({String text, double size})>[];
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    void visit(InlineSpan span, TextStyle? inherited) {
      final style = inherited?.merge(span.style) ?? span.style;
      if (span is TextSpan) {
        final text = span.text;
        final isIcon =
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

/// The weight numeral as «68,4 kg» (the figure and its unit are two spans).
String _hero(WidgetTester tester) {
  final numeral = tester.widget<ExomNumeral>(find.byType(ExomNumeral));
  return '${numeral.value} ${numeral.unit}';
}

/// Every figure of the measurement columns as «label: value unit».
List<String> _figures(WidgetTester tester) => [
  for (final columns in tester.widgetList<ExomFigureColumns>(
    find.byType(ExomFigureColumns),
  ))
    for (final item in columns.items)
      '${item.label}: ${item.value} ${item.unit}',
];

/// Painted text of the whole screen, including rich spans, in order.
String _allText(WidgetTester tester) =>
    _textRuns(tester).map((r) => r.text).join('|');

Finder _addMeasure(AppLocalizations l10n) {
  final wanted = l10n.progressAddMeasure.toLowerCase();
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data?.toLowerCase() == wanted,
  );
}

/// L6-UX4: the form only saves after a change; a sleep chip is the lightest.
Future<void> _changeSleep(WidgetTester tester) async {
  final chip = find.widgetWithText(ActionChip, '9 h');
  await tester.scrollUntilVisible(
    chip,
    300,
    scrollable: find
        .descendant(
          of: find.byType(MetricsFormPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(chip);
  await tester.pump();
}

Finder _saveButton(AppLocalizations l10n) {
  final wanted = l10n.saveMetricsButton.toLowerCase();
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data?.toLowerCase() == wanted,
  );
}

/// Rect of a semantics node in global coordinates.
Rect _globalRect(SemanticsNode node) {
  var rect = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    final transform = current.transform;
    if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
    current = current.parent;
  }
  return rect;
}

void main() {
  tearDown(sl.reset);

  group('weight summary', () {
    testWidgets('latest weight, date and the "less" delta over real weeks', (
      tester,
    ) async {
      await _mount(
        tester,
        repository: _Repository(history: _weekly, latest: _latest),
      );
      final text = _allText(tester);
      expect(_hero(tester), '68,4 kg');
      // The kicker paints upper case.
      expect(text, contains('EL 18 DE NOVIEMBRE'));
      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('a gain reads "más"', (tester) async {
      await _mount(
        tester,
        repository: _Repository(
          history: [_w(11, 4, 68), _w(11, 18, 68.4)],
          latest: _latest,
        ),
      );
      expect(find.text('0,4 kg más en 2 semanas'), findsOneWidget);
    });

    testWidgets('a span that is not whole weeks is told in days', (
      tester,
    ) async {
      await _mount(
        tester,
        repository: _Repository(
          history: [_w(11, 8, 69), _w(11, 18, 68.4)],
          latest: _latest,
        ),
      );
      expect(find.text('0,6 kg menos en 10 días'), findsOneWidget);
    });

    testWidgets(
      'the delta is the interval between the two weighings, never "ago"',
      (tester) async {
        // Last weighing is weeks before "today": the sentence must not say
        // "hace", which would read as relative to today (review defect 4).
        await _mount(
          tester,
          repository: _Repository(
            history: [_w(1, 5, 72), _w(1, 26, 71), _w(2, 2, 71.4)],
            latest: BodyMetricEntity(
              id: 'old',
              date: DateTime(2026, 2, 2),
              weightKg: 71.4,
            ),
          ),
        );
        expect(find.text('0,6 kg menos en 4 semanas'), findsOneWidget);
        expect(find.textContaining('hace'), findsNothing);
      },
    );

    testWidgets('an unchanged weight reads "Sin cambios en N"', (tester) async {
      await _mount(
        tester,
        repository: _Repository(
          history: [_w(11, 4, 68.4), _w(11, 18, 68.4)],
          latest: _latest,
        ),
      );
      expect(find.text('Sin cambios en 2 semanas'), findsOneWidget);
    });

    testWidgets('a single day reads in singular', (tester) async {
      await _mount(
        tester,
        repository: _Repository(
          history: [_w(11, 17, 68), _w(11, 18, 68.4)],
          latest: _latest,
        ),
      );
      expect(find.text('0,4 kg más en 1 día'), findsOneWidget);
    });

    testWidgets('English phrasing: plural weeks, singular day, no change', (
      tester,
    ) async {
      const en = Locale('en');
      await _mount(
        tester,
        locale: en,
        repository: _Repository(history: _weekly, latest: _latest),
      );
      expect(find.text('2.5 kg less in 7 weeks'), findsOneWidget);

      await _mount(
        tester,
        locale: en,
        repository: _Repository(
          history: [_w(11, 17, 68), _w(11, 18, 68.4)],
          latest: _latest,
        ),
      );
      expect(find.text('0.4 kg more in 1 day'), findsOneWidget);

      await _mount(
        tester,
        locale: en,
        repository: _Repository(
          history: [_w(11, 4, 68.4), _w(11, 18, 68.4)],
          latest: _latest,
        ),
      );
      expect(find.text('No change in 2 weeks'), findsOneWidget);
    });

    testWidgets('with a single weight there is no delta and no chart', (
      tester,
    ) async {
      await _mount(
        tester,
        repository: _Repository(history: [_w(11, 18, 68.4)], latest: _latest),
      );
      final l10n = _l10n(tester);
      expect(_hero(tester), '68,4 kg');
      expect(find.textContaining(' kg menos'), findsNothing);
      expect(find.textContaining(' kg más'), findsNothing);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text(l10n.progressChartEmpty), findsOneWidget);
    });

    testWidgets('the chart has a textual semantic summary', (tester) async {
      final handle = tester.ensureSemantics();
      await _mount(
        tester,
        repository: _Repository(history: _weekly, latest: _latest),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('progress-weight-chart'))),
        matchesSemantics(
          label:
              'Peso del 30 de septiembre al 18 de noviembre: de 70,9 kg a 68,4 kg',
          isImage: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('reduced motion draws the line without animation', (
      tester,
    ) async {
      await _mount(
        tester,
        repository: _Repository(history: _weekly, latest: _latest),
        disableAnimations: true,
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.duration, Duration.zero);
    });
  });

  group('latest measurements', () {
    testWidgets('rows are the newest values, newest first', (tester) async {
      await _mount(
        tester,
        repository: _Repository(history: _weekly, latest: _latest),
      );
      final rows = tester
          .widgetList<KeyedSubtree>(
            find.byWidgetPredicate(
              (w) =>
                  w is KeyedSubtree &&
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'progress-measure-',
                  ),
            ),
          )
          .map((w) => (w.key! as ValueKey<String>).value)
          .toList();
      expect(rows.take(3).toList(), [
        'progress-measure-weight_kg-2026-11-18',
        'progress-measure-waist_cm-2026-11-18',
        'progress-measure-weight_kg-2026-11-11',
      ]);
      // Columns (E9a): the label carries the date, the figure its unit.
      expect(_figures(tester).take(3).toList(), [
        'Peso · 18 nov: 68,4 kg',
        'Cintura · 18 nov: 74 cm',
        'Peso · 11 nov: 68,8 kg',
      ]);
    });

    testWidgets('the photos row opens the existing progress photos route', (
      tester,
    ) async {
      final h = await _mount(
        tester,
        repository: _Repository(history: _weekly, latest: _latest),
      );
      final row = find.byKey(const Key('progress-photos-row'));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('photos-destination'), findsOneWidget);
      expect(
        h.router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.progressPhotos,
      );
    });
  });

  group('add measure', () {
    testWidgets('opens the day form and refreshes the summary after saving', (
      tester,
    ) async {
      final repository = _Repository(history: _weekly, latest: _latest);
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(repository.historyCalls, 1);

      await tester.tap(_addMeasure(l10n));
      await tester.pumpAndSettle();
      expect(find.byType(MetricsFormPage), findsOneWidget);

      repository.history = [..._weekly, _w(11, 25, 68.1)];
      repository.latest = BodyMetricEntity(
        id: 'new',
        date: DateTime(2026, 11, 25),
        weightKg: 68.1,
      );
      await _changeSleep(tester);
      await tester.tap(_saveButton(l10n));
      await tester.pumpAndSettle();

      expect(repository.saved, hasLength(1));
      expect(find.byType(MetricsFormPage), findsNothing);
      expect(repository.historyCalls, 2);
      expect(_hero(tester), '68,1 kg');
      expect(_allText(tester), contains('EL 25 DE NOVIEMBRE'));
      // The chart keeps the last eight weights: 7 Oct (70,6) → 25 Nov (68,1).
      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
    });
  });

  // L4-I26c: the reload after saving a measure (network data, no retry on
  // screen) had no progress mark at all.
  group('reload after saving a measure (L4-I26c)', () {
    testWidgets('the mark shows while reloading, alone, and then goes', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repository = _Repository(history: _weekly, latest: _latest);
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      await tester.tap(_addMeasure(l10n));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      repository.historyGate = gate;
      await _changeSleep(tester);
      await tester.tap(_saveButton(l10n));
      // The form saves, pops itself and the summary reloads.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(MetricsFormPage), findsNothing);
      expect(repository.historyCalls, 2);
      final mark = find.byKey(const Key('progress-refresh-mark'));
      expect(mark, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(mark).height, 18);
      // The loaded content stays; there is no retry button.
      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
      expect(find.text(l10n.retry), findsNothing);
      final live = <SemanticsNode>[];
      bool visit(SemanticsNode node) {
        if (node.flagsCollection.isLiveRegion) live.add(node);
        node.visitChildren(visit);
        return true;
      }

      for (final view in tester.binding.renderViews) {
        final root = view.owner?.semanticsOwner?.rootSemanticsNode;
        if (root != null) visit(root);
      }
      // The form's «saved» snack bar is its own live region, outside the
      // page; within the page the mark is the only one.
      final saved = l10n.metricsSuccessMessage;
      final page = live.where((node) => node.label != saved).toList();
      expect(page, hasLength(1));
      expect(page.single.label, l10n.progressLoading);

      gate.complete();
      await tester.pumpAndSettle();
      expect(mark, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      handle.dispose();
    });
  });

  group('history states', () {
    testWidgets('error shows a retry and keeps "Añadir medida"', (
      tester,
    ) async {
      final repository = _Repository(history: _weekly, latest: _latest)
        ..historyError = Exception('boom');
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text(l10n.progressHistoryError), findsOneWidget);
      expect(_addMeasure(l10n), findsOneWidget);

      repository.historyError = null;
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();
      expect(find.text(l10n.progressHistoryError), findsNothing);
      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
    });

    testWidgets('offline has its own message', (tester) async {
      final repository = _Repository(history: _weekly, latest: _latest)
        ..historyError = DioException(
          requestOptions: RequestOptions(path: '/metrics/weight-history'),
          type: DioExceptionType.connectionError,
        );
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text(l10n.progressHistoryOffline), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(_addMeasure(l10n), findsOneWidget);
    });

    // L4-I1: the metrics datasource now throws on network and server errors,
    // so an empty history with no latest record is a real empty account.
    testWidgets('empty history and no latest is the real empty state', (
      tester,
    ) async {
      final repository = _Repository(history: const []);
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text('Aún no has registrado tu peso.'), findsOneWidget);
      expect(find.text('Aún no hay medidas registradas.'), findsOneWidget);
      expect(find.text(l10n.progressChartEmpty), findsOneWidget);
      expect(find.text(l10n.retry), findsNothing);
      expect(find.text(l10n.progressHistoryError), findsNothing);
      expect(_addMeasure(l10n), findsOneWidget);
      expect(find.byKey(const Key('progress-photos-row')), findsOneWidget);
    });

    testWidgets('a failed latest record is an error, not the empty state', (
      tester,
    ) async {
      final repository = _Repository(history: const [])
        ..latestError = Exception('500');
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text(l10n.progressHistoryError), findsOneWidget);
      expect(find.text(l10n.progressWeightEmpty), findsNothing);
      expect(find.text(l10n.progressMeasuresEmpty), findsNothing);

      repository
        ..latestError = null
        ..history = _weekly
        ..latest = _latest;
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();
      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
    });

    testWidgets('a failed latest record offline has the offline message', (
      tester,
    ) async {
      final repository = _Repository(history: const [])
        ..latestError = DioException(
          requestOptions: RequestOptions(path: '/metrics/latest'),
          type: DioExceptionType.receiveTimeout,
        );
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text(l10n.progressHistoryOffline), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(find.text(l10n.progressWeightEmpty), findsNothing);
    });

    // Review 3, D4: offline with only the history cached, the weights are
    // shown and nothing is claimed empty.
    testWidgets('a failed latest record keeps the weight history', (
      tester,
    ) async {
      final repository = _Repository(history: _weekly)
        ..latestError = DioException(
          requestOptions: RequestOptions(path: '/metrics/latest'),
          type: DioExceptionType.connectionError,
        );
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
      expect(find.text(l10n.progressHistoryOffline), findsNothing);
      expect(find.text(l10n.progressWeightEmpty), findsNothing);
      expect(find.text(l10n.progressMeasuresEmpty), findsNothing);
    });

    testWidgets('latest without history is real data, not the neutral text', (
      tester,
    ) async {
      await _mount(
        tester,
        repository: _Repository(history: const [], latest: _latest),
      );
      final l10n = _l10n(tester);
      expect(find.text(l10n.retry), findsNothing);
      expect(find.text(l10n.progressWeightEmpty), findsOneWidget);
    });
  });

  group('cache and unavailable latest (L4-I12)', () {
    DioException offline() => DioException(
      requestOptions: RequestOptions(path: '/metrics/latest'),
      type: DioExceptionType.connectionError,
    );

    testWidgets('history and latest from cache: banner, one retry, data', (
      tester,
    ) async {
      final repository = _Repository(history: _weekly, latest: _latest)
        ..historyFromCache = true
        ..latestFromCache = true;
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text(l10n.progressCachedBanner), findsOneWidget);
      expect(find.byIcon(ExomIcons.offline), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(find.text(l10n.progressLatestUnavailableOffline), findsNothing);
      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
      expect(_figures(tester), contains('Cintura · 18 nov: 74 cm'));

      final calls = repository.historyCalls;
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();
      expect(repository.historyCalls, calls + 1);
    });

    testWidgets('only history from cache: banner, latest rows intact', (
      tester,
    ) async {
      final repository = _Repository(history: _weekly, latest: _latest)
        ..historyFromCache = true;
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text(l10n.progressCachedBanner), findsOneWidget);
      expect(_figures(tester), contains('Cintura · 18 nov: 74 cm'));
      expect(find.text(l10n.retry), findsOneWidget);
    });

    testWidgets('latest offline: notice, one retry, weights, no empty text', (
      tester,
    ) async {
      final repository = _Repository(history: _weekly)
        ..historyFromCache = true
        ..latestError = offline();
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text(l10n.progressLatestUnavailableOffline), findsOneWidget);
      expect(find.text(l10n.progressLatestUnavailableError), findsNothing);
      expect(find.text(l10n.progressMeasuresEmpty), findsNothing);
      expect(find.text(l10n.progressHistoryOffline), findsNothing);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(
        find.byKey(const ValueKey('progress-measure-weight_kg-2026-11-11')),
        findsOneWidget,
      );
      final button = find.ancestor(
        of: find.text(l10n.retry),
        matching: find.byType(ExomSecondaryButton),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));

      final calls = repository.historyCalls;
      repository.latestError = null;
      repository.latest = _latest;
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();
      expect(repository.historyCalls, calls + 1);
      expect(find.text(l10n.progressLatestUnavailableOffline), findsNothing);
    });

    testWidgets('latest 5xx with network history: error notice, no banner', (
      tester,
    ) async {
      final repository = _Repository(history: _weekly)
        ..latestError = Exception('500');
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text(l10n.progressLatestUnavailableError), findsOneWidget);
      expect(find.text(l10n.progressCachedBanner), findsNothing);
      expect(find.text(l10n.progressMeasuresEmpty), findsNothing);
      expect(find.text(l10n.retry), findsOneWidget);
    });

    testWidgets('all from network: no banner, no notice, no retry', (
      tester,
    ) async {
      await _mount(
        tester,
        repository: _Repository(history: _weekly, latest: _latest),
      );
      final l10n = _l10n(tester);
      expect(find.text(l10n.progressCachedBanner), findsNothing);
      expect(find.byIcon(ExomIcons.offline), findsNothing);
      expect(find.text(l10n.progressLatestUnavailableOffline), findsNothing);
      expect(find.text(l10n.progressLatestUnavailableError), findsNothing);
      expect(find.text(l10n.retry), findsNothing);
    });

    testWidgets('banner plus notice never show two retry buttons', (
      tester,
    ) async {
      final repository = _Repository(history: _weekly)
        ..historyFromCache = true
        ..latestError = offline();
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.text(l10n.progressCachedBanner), findsOneWidget);
      expect(find.text(l10n.progressLatestUnavailableOffline), findsOneWidget);
      expect(find.byType(ExomSecondaryButton), findsOneWidget);
    });

    testWidgets('banner plus notice announce once (one live region)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repository = _Repository(history: _weekly)
        ..historyFromCache = true
        ..latestError = offline();
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      final banner = tester.getSemantics(find.text(l10n.progressCachedBanner));
      final notice = tester.getSemantics(
        find.text(l10n.progressLatestUnavailableOffline),
      );
      final live = [
        banner,
        notice,
      ].where((node) => node.flagsCollection.isLiveRegion).length;
      expect(live, 1);
      expect(banner.label, contains(l10n.progressCachedBanner));
      handle.dispose();
    });

    testWidgets('banner alone is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      final repository = _Repository(history: _weekly, latest: _latest)
        ..historyFromCache = true;
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      final banner = tester.getSemantics(find.text(l10n.progressCachedBanner));
      expect(banner.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final scale in const [1.3, 1.6]) {
        testWidgets('320 dp x$scale ${locale.languageCode}: no overflow', (
          tester,
        ) async {
          for (final latestFails in [false, true]) {
            final repository = _Repository(
              history: _weekly,
              latest: latestFails ? null : _latest,
            )..historyFromCache = true;
            if (latestFails) {
              repository.latestError = offline();
            } else {
              repository.latestFromCache = true;
            }
            await _mount(
              tester,
              repository: repository,
              size: const Size(320, 640),
              textScale: scale,
              locale: locale,
            );
            expect(tester.takeException(), isNull);
            await tester.scrollUntilVisible(
              find.byKey(const Key('progress-photos-row')),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            expect(tester.takeException(), isNull);
            _expectNoTextBelow13(tester);
          }
        });
      }
    }
  });

  group('banner retry is a compact text action (L4-I23)', () {
    Future<_Repository> mountBanner(
      WidgetTester tester, {
      Size size = const Size(411, 900),
      double textScale = 1.0,
      Locale locale = const Locale('es'),
    }) async {
      final repository = _Repository(history: _weekly, latest: _latest)
        ..historyFromCache = true
        ..latestFromCache = true;
      await _mount(
        tester,
        repository: repository,
        size: size,
        textScale: textScale,
        locale: locale,
      );
      return repository;
    }

    testWidgets('411 dp: not full width, 48 dp target, same line as text', (
      tester,
    ) async {
      // Tests paint with the Ahem font (one em per glyph), about twice as
      // wide as the real one: 0.5x text scale gives the real text width.
      await mountBanner(tester, textScale: 0.5);
      final l10n = _l10n(tester);
      final button = find.byType(ExomQuietButton);
      expect(button, findsOneWidget);
      expect(find.byType(ExomSecondaryButton), findsNothing);
      expect(find.text(l10n.retry), findsOneWidget);
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
      // The banner spans the screen minus its 20 dp side padding.
      expect(size.width, lessThan(411 - 40));
      final text = tester.getRect(find.text(l10n.progressCachedBanner));
      final rect = tester.getRect(button);
      expect(rect.left, greaterThanOrEqualTo(text.right));
      expect((rect.center.dy - text.center.dy).abs(), lessThan(24));
    });

    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final scale in const [1.3, 1.6]) {
        testWidgets('320 dp x$scale ${locale.languageCode}: wraps below', (
          tester,
        ) async {
          await mountBanner(
            tester,
            size: const Size(320, 640),
            textScale: scale,
            locale: locale,
          );
          final l10n = _l10n(tester);
          expect(tester.takeException(), isNull);
          final button = find.byType(ExomQuietButton);
          expect(button, findsOneWidget);
          final size = tester.getSize(button);
          expect(size.height, greaterThanOrEqualTo(48));
          expect(size.width, greaterThanOrEqualTo(48));
          final text = tester.getRect(find.text(l10n.progressCachedBanner));
          final rect = tester.getRect(button);
          expect(rect.top, greaterThanOrEqualTo(text.bottom - 1));
          expect(rect.left, lessThan(text.left));
        });
      }
    }
  });

  group('retry keeps the loaded content (L4-I23)', () {
    DioException offline() => DioException(
      requestOptions: RequestOptions(path: '/metrics/latest'),
      type: DioExceptionType.connectionError,
    );

    Future<_Repository> mountNotice(WidgetTester tester) async {
      final repository = _Repository(history: _weekly)
        ..historyFromCache = true
        ..latestError = offline();
      await _mount(tester, repository: repository, size: const Size(390, 600));
      return repository;
    }

    double pixels(WidgetTester tester) => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    testWidgets('notice retry: content and scroll stay, button disabled', (
      tester,
    ) async {
      final repository = await mountNotice(tester);
      final l10n = _l10n(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.retry),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final before = pixels(tester);
      expect(before, greaterThan(0));
      final row = find.byKey(
        const ValueKey('progress-measure-weight_kg-2026-11-11'),
      );
      expect(row, findsOneWidget);

      // What the reload will answer: the latest read is not gated, so it
      // is set before the tap.
      repository
        ..latestError = null
        ..latest = _latest
        ..historyFromCache = false
        ..history = [..._weekly, _w(11, 25, 67.9)];
      final gate = Completer<void>();
      repository.historyGate = gate;
      await tester.tap(find.text(l10n.retry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(row, findsOneWidget);
      expect(pixels(tester), before);
      final button = find.byType(ExomSecondaryButton);
      expect(button, findsOneWidget);
      expect(tester.widget<ExomSecondaryButton>(button).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)).height,
        lessThanOrEqualTo(24),
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('progress-measure-weight_kg-2026-11-25')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.retry), findsNothing);
    });

    testWidgets('banner retry: content stays, button disabled while loading', (
      tester,
    ) async {
      final repository = _Repository(history: _weekly, latest: _latest)
        ..historyFromCache = true
        ..latestFromCache = true;
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      final gate = Completer<void>();
      repository
        ..historyGate = gate
        ..historyFromCache = false
        ..latestFromCache = false;
      await tester.tap(find.text(l10n.retry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
      expect(find.text(l10n.progressCachedBanner), findsOneWidget);
      expect(find.byType(ExomQuietButton), findsOneWidget);
      expect(
        tester.widget<ExomQuietButton>(find.byType(ExomQuietButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(l10n.progressCachedBanner), findsNothing);
      expect(find.byType(ExomQuietButton), findsNothing);
      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
    });

    // L4-I26b: during a reload the notice (or the banner) and the progress
    // mark were two live regions announced together. Only the mark announces
    // while the reload is in flight.
    List<SemanticsNode> liveRegions(WidgetTester tester) {
      final live = <SemanticsNode>[];
      bool visit(SemanticsNode node) {
        if (node.flagsCollection.isLiveRegion) live.add(node);
        node.visitChildren(visit);
        return true;
      }

      for (final view in tester.binding.renderViews) {
        final root = view.owner?.semanticsOwner?.rootSemanticsNode;
        if (root != null) visit(root);
      }
      return live;
    }

    for (final (name, latestOffline) in const [
      ('banner and section notice', true),
      ('banner alone', false),
    ]) {
      testWidgets('$name: one live region while reloading', (tester) async {
        final handle = tester.ensureSemantics();
        final repository = _Repository(history: _weekly, latest: _latest)
          ..historyFromCache = true
          ..latestFromCache = !latestOffline
          ..latestError = latestOffline ? offline() : null;
        await _mount(tester, repository: repository);
        final l10n = _l10n(tester);
        expect(liveRegions(tester), hasLength(1), reason: 'before the reload');
        repository.historyGate = Completer<void>();
        await tester.ensureVisible(find.text(l10n.retry));
        await tester.pump();
        await tester.tap(find.text(l10n.retry));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final live = liveRegions(tester);
        expect(live, hasLength(1), reason: 'during the reload');
        // The one announcement is the progress mark, alone.
        expect(live.single.label, l10n.progressLoading);
        repository.historyGate!.complete();
        await tester.pumpAndSettle();
        handle.dispose();
      });
    }

    testWidgets('a failing retry shows the error screen, not old content', (
      tester,
    ) async {
      final repository = _Repository(history: _weekly, latest: _latest)
        ..historyFromCache = true
        ..latestFromCache = true;
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      final gate = Completer<void>();
      repository.historyGate = gate;
      await tester.tap(find.text(l10n.retry));
      await tester.pump();
      repository.historyError = Exception('x');
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(l10n.progressHistoryError), findsOneWidget);
      expect(
        find.byKey(const ValueKey('progress-measure-weight_kg-2026-11-11')),
        findsNothing,
      );
    });

    testWidgets('first load shows the loader, not content', (tester) async {
      final repository = _Repository(history: _weekly, latest: _latest)
        ..historyGate = Completer<void>();
      await _mount(tester, repository: repository);
      final l10n = _l10n(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)).height,
        greaterThan(24),
      );
      expect(find.text(l10n.weightSectionTitle.toUpperCase()), findsNothing);
      expect(find.text(l10n.retry), findsNothing);
      repository.historyGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('2,5 kg menos en 7 semanas'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('no text below 13 px (dark)', (tester) async {
      await _mount(
        tester,
        repository: _Repository(history: _weekly, latest: _latest),
      );
      _expectNoTextBelow13(tester);
    });

    testWidgets('no text below 13 px (light, error)', (tester) async {
      await _mount(
        tester,
        repository: _Repository(history: _weekly)
          ..historyError = Exception('x'),
        theme: AppTheme.light,
      );
      _expectNoTextBelow13(tester);
    });

    testWidgets('320 dp wide at 1.3x text lays out without overflow', (
      tester,
    ) async {
      await _mount(
        tester,
        repository: _Repository(history: _weekly, latest: _latest),
        size: const Size(320, 640),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('progress-photos-row')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      _expectNoTextBelow13(tester);
    });

    testWidgets('the add button is a 48 dp target', (tester) async {
      await _mount(
        tester,
        repository: _Repository(history: _weekly, latest: _latest),
      );
      final l10n = _l10n(tester);
      final button = find.byKey(const Key('progress-add-measure'));
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(_addMeasure(l10n), findsOneWidget);
    });
  });

  group('accessibility tree', () {
    testWidgets(
      'photos row is its own button node, measure rows are siblings',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _mount(
          tester,
          repository: _Repository(history: _weekly, latest: _latest),
          size: const Size(390, 2000),
        );
        final photos = find.byKey(const Key('progress-photos-row'));
        expect(photos, findsOneWidget);
        final node = tester.getSemantics(photos);
        final visible = tester.getRect(photos);
        final rect = _globalRect(node);
        expect(
          rect.height,
          lessThanOrEqualTo(visible.height + 2),
          reason: 'button node $rect must only cover the row $visible',
        );
        expect(rect.top, greaterThanOrEqualTo(visible.top - 2));
        var descendants = 0;
        node.visitChildren((_) {
          descendants++;
          return true;
        });
        expect(descendants, 0, reason: 'button node must not own other rows');
        final l10n = _l10n(tester);
        final measure = find.byKey(
          const ValueKey('progress-measure-waist_cm-2026-11-18'),
        );
        expect(measure, findsOneWidget);
        final measureNode = tester.getSemantics(
          find.descendant(of: measure, matching: find.textContaining('74')),
        );
        expect(measureNode.id, isNot(node.id));
        expect(measureNode.label, contains('74'));
        expect(node.label, contains(l10n.progressPhotosEntry));
        expect(node.flagsCollection.isButton, isTrue);
        handle.dispose();
      },
    );
  });

  group('weight chart axis', () {
    testWidgets('uniform round marks and room for the last point', (
      tester,
    ) async {
      await _mount(
        tester,
        repository: _Repository(
          history: [
            _w(10, 1, 82.2),
            _w(10, 8, 80.4),
            _w(10, 15, 79.1),
            _w(10, 22, 78.6),
          ],
          latest: _latest,
        ),
        size: const Size(320, 900),
        textScale: 1.3,
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final data = chart.data;
      expect(data.minY, 78);
      expect(data.maxY, 84);
      expect(data.gridData.horizontalInterval, 2);
      expect(data.titlesData.rightTitles.sideTitles.interval, 2);
      final labels = [
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(LineChart),
            matching: find.byType(Text),
          ),
        ))
          text.data,
      ];
      expect(labels, containsAll(['78', '80', '82', '84']));
      // The axis sits on the right, so the room is for the first dot
      // (radius 3.5 + stroke) at the left edge of the chart box.
      final box = tester.getRect(
        find.byKey(const Key('progress-weight-chart')),
      );
      final plot = tester.getRect(find.byType(LineChart));
      expect(plot.left - box.left, greaterThanOrEqualTo(6));
      expect(tester.takeException(), isNull);
    });
  });
}
