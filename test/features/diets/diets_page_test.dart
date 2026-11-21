// L4 unit 1: Nutrición on the V4 system. Presentation only: the bloc, the
// repository contract and the offline queue are the real ones / read-only.
import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_completed_meals_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_meal_usecase.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/domain/usecases/get_today_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_weekly_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/mark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/unmark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
import 'package:exom_app/features/diets/presentation/pages/diets_page.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_detail_sheet.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _date = '2026-11-18';

MealEntity _meal(
  String id,
  String type,
  String name, {
  int? calories,
  double? protein,
  double? carbs,
  List<String> badges = const [],
  List<MealEntity> variants = const [],
  String? imageUrl,
}) => MealEntity(
  id: id,
  type: type,
  name: name,
  imageUrl: imageUrl,
  calories: calories,
  proteinG: protein,
  carbsG: carbs,
  nutritionalBadges: badges,
  ingredients: const [],
  variants: variants,
);

final _diet = DietEntity(
  id: 'diet-1',
  name: 'Definición',
  totalCalories: 2150,
  totalProteinG: 160,
  totalCarbsG: 220,
  totalFatG: 70,
  meals: [
    _meal(
      'm-dinner',
      'DINNER',
      'Merluza, patata y ensalada',
      calories: 550,
      protein: 40,
      carbs: 45,
    ),
    _meal(
      'm-breakfast',
      'BREAKFAST',
      'Avena, yogur griego y fruta',
      calories: 520,
      protein: 30,
      carbs: 60,
      badges: const ['Alta en fibra', 'Sin gluten'],
      variants: [_meal('m-breakfast-b', 'BREAKFAST', 'Tostada con aguacate')],
    ),
    _meal('m-lunch', 'LUNCH', 'Arroz, pollo y verduras', calories: 780),
    _meal('m-snack', 'SNACK', 'Tostada integral con pavo', calories: 300),
  ],
);

class _Repository extends Fake implements DietRepository {
  _Repository({this.diet, Set<String> completed = const {}})
    : completed = {...completed};

  final DietEntity? diet;
  final Set<String> completed;
  final marked = <String>[];
  final unmarked = <String>[];
  int historyReads = 0;
  final weeklyReads = <String>[];
  WeeklyDietEntity? week;

  @override
  Future<WeeklyDietEntity> getWeeklyDiet(String weekStart) async {
    weeklyReads.add(weekStart);
    return week ??
        WeeklyDietEntity(
          weekStart: DateTime(2026, 11, 16),
          weekEnd: DateTime(2026, 11, 22),
          days: [WeeklyDietDayEntity(date: DateTime(2026, 11, 18), diet: diet)],
        );
  }

  @override
  Future<DietEntity?> getTodayDiet({String? date}) async => diet;
  @override
  Future<Set<String>> getCompletedMealIds({String? date}) async => {
    ...completed,
  };
  @override
  Future<void> markMealCompleted(String mealId, String date) async {
    marked.add('$mealId@$date');
  }

  @override
  Future<void> unmarkMealCompleted(String mealId, String date) async {
    unmarked.add('$mealId@$date');
  }

  @override
  Future<DietHistory> getDietHistory({String? date}) async {
    historyReads++;
    return const DietHistory(entries: [], unresolvedMealIds: []);
  }
}

class _FakePdfService extends Fake implements WeeklyDietPdfService {
  int shoppingLists = 0;

  @override
  Future<Uint8List> buildShoppingList({
    required DietPeriodEntity week,
    required List<ShoppingListItem> items,
    required String locale,
    required WeeklyShoppingListPdfLabels labels,
  }) async {
    shoppingLists++;
    return Uint8List(0);
  }
}

class _FailingWeekRepository extends Fake implements DietRepository {
  @override
  Future<WeeklyDietEntity> getWeeklyDiet(String weekStart) async =>
      throw StateError('offline');
}

class _Storage extends LocalStorage {
  List<Map<String, dynamic>> actions = [];

  @override
  String? get sessionStamp => 'owner:1:test';
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => [...actions];
}

class _Sync extends OfflineSyncService {
  _Sync(LocalStorage storage) : super(ApiClient(useAuth: false), storage);
  final controller = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => controller.stream;
}

class _Harness {
  _Harness(this.repository, this.storage, this.sync);
  final _Repository repository;
  final _Storage storage;
  final _Sync sync;
}

Map<String, dynamic> _action(
  String mealId, {
  String type = 'mark_meal_completed',
  String status = 'queued',
  String date = _date,
}) => {
  'id': 'op-$mealId',
  'type': type,
  'meal_id': mealId,
  'date': date,
  'status': status,
};

Future<_Harness> _mount(
  WidgetTester tester, {
  DietEntity? diet,
  Set<String> completed = const {},
  List<Map<String, dynamic>> actions = const [],
  ThemeData? theme,
  Size size = const Size(390, 1400),
  double textScale = 1.0,
  Locale locale = const Locale('es'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  // A fresh tree per mount, so repeated mounts in one test do not reuse state.
  await tester.pumpWidget(const SizedBox());
  final repository = _Repository(diet: diet, completed: completed);
  final storage = _Storage()..actions = [...actions];
  final sync = _Sync(storage);
  addTearDown(sync.controller.close);
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<OfflineSyncService>(sync);
  sl.registerSingleton<DietRepository>(repository);
  sl.registerSingleton<GetWeeklyDietUseCase>(GetWeeklyDietUseCase(repository));
  sl.registerFactory<DietBloc>(
    () => DietBloc(
      getTodayDietUseCase: GetTodayDietUseCase(repository),
      getMealUseCase: GetMealUseCase(repository),
      markMealCompletedUseCase: MarkMealCompletedUseCase(repository),
      unmarkMealCompletedUseCase: UnmarkMealCompletedUseCase(repository),
      getCompletedMealsUseCase: GetCompletedMealsUseCase(repository),
    ),
  );
  // The meal detail sheet is router-aware; the router itself stays unused.
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => const SizedBox())],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: InheritedGoRouter(goRouter: router, child: child!),
      ),
      home: const Scaffold(body: DietsPage(selectedDate: _date)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return _Harness(repository, storage, sync);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(DietsPage)));

/// Runs the accessibility tap action of the node with [label], as a screen
/// reader would.
void _semanticTap(WidgetTester tester, String label) {
  tester.semantics.performAction(
    find.semantics.byLabel(label),
    SemanticsAction.tap,
  );
}

/// The index closing the list is built lazily: scroll it into view first.
Future<void> _revealIndex(WidgetTester tester) => tester.scrollUntilVisible(
  find.byKey(const Key('diet-shopping-list-row')),
  300,
  scrollable: find.byType(Scrollable).first,
);

Finder _toggle(String mealId) => find.byKey(Key('meal-toggle-$mealId'));

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

void main() {
  tearDown(sl.reset);

  group('text size floor (13 px)', () {
    testWidgets('with meals, one completed and one with options and badges', (
      tester,
    ) async {
      await _mount(tester, diet: _diet, completed: {'m-lunch'});
      expect(find.text('Merluza, patata y ensalada'), findsOneWidget);
      _expectNoTextBelow13(tester);
    });

    testWidgets('with a meal pending to sync', (tester) async {
      await _mount(
        tester,
        diet: _diet,
        completed: {'m-lunch'},
        actions: [_action('m-lunch')],
      );
      expect(find.text(_l10n(tester).syncStatusPending), findsOneWidget);
      _expectNoTextBelow13(tester);
    });

    testWidgets('light theme', (tester) async {
      await _mount(
        tester,
        diet: _diet,
        completed: {'m-snack'},
        theme: AppTheme.light,
      );
      _expectNoTextBelow13(tester);
    });

    testWidgets('empty day', (tester) async {
      await _mount(tester);
      expect(find.text(_l10n(tester).noDietForDateMessage), findsOneWidget);
      _expectNoTextBelow13(tester);
    });
  });

  group('state without colour', () {
    testWidgets('pending sync shows clock icon + text + semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _mount(tester, diet: _diet, actions: [_action('m-lunch')]);
      final l10n = _l10n(tester);
      final row = find.ancestor(
        of: find.text(l10n.syncStatusPending),
        matching: find.byKey(const Key('meal-row-m-lunch')),
      );
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.byIcon(ExomIcons.time)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(l10n.syncStatusPending)),
        findsWidgets,
      );
      // Only that meal is flagged.
      expect(find.text(l10n.syncStatusPending), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('action on a variant flags the row of its meal', (
      tester,
    ) async {
      await _mount(tester, diet: _diet, actions: [_action('m-breakfast-b')]);
      final l10n = _l10n(tester);
      final row = find.ancestor(
        of: find.text(l10n.syncStatusPending),
        matching: find.byKey(const Key('meal-row-m-breakfast')),
      );
      expect(row, findsOneWidget);
      expect(find.text(l10n.syncStatusPending), findsOneWidget);
    });

    testWidgets('no queued action, no sync indicator', (tester) async {
      await _mount(tester, diet: _diet, completed: {'m-lunch'});
      expect(find.text(_l10n(tester).syncStatusPending), findsNothing);
    });

    testWidgets('action of another day does not flag the meal', (tester) async {
      await _mount(
        tester,
        diet: _diet,
        actions: [_action('m-lunch', date: '2026-11-17')],
      );
      expect(find.text(_l10n(tester).syncStatusPending), findsNothing);
    });

    testWidgets('queue change while mounted updates the indicator', (
      tester,
    ) async {
      final h = await _mount(tester, diet: _diet);
      expect(find.text(_l10n(tester).syncStatusPending), findsNothing);
      h.storage.actions = [_action('m-snack')];
      h.sync.controller.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.text(_l10n(tester).syncStatusPending), findsOneWidget);
    });

    testWidgets('completed meal differs from open meal by check icon', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _mount(tester, diet: _diet, completed: {'m-lunch'});
      expect(
        find.descendant(
          of: _toggle('m-lunch'),
          matching: find.byIcon(ExomIcons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _toggle('m-snack'),
          matching: find.byIcon(ExomIcons.check),
        ),
        findsNothing,
      );
      // The label names the meal (review defect 5).
      expect(
        tester.getSemantics(_toggle('m-lunch')),
        matchesSemantics(
          label: 'Desmarcar Almuerzo como completada',
          isButton: true,
          hasTapAction: true,
          hasCheckedState: true,
          isChecked: true,
        ),
      );
      expect(
        tester.getSemantics(_toggle('m-snack')),
        matchesSemantics(
          label: 'Marcar Snack como completada',
          isButton: true,
          hasTapAction: true,
          hasCheckedState: true,
          isChecked: false,
        ),
      );
      semantics.dispose();
    });
  });

  group('mark semantics action', () {
    testWidgets('a screen reader can mark and unmark through the tap action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final h = await _mount(tester, diet: _diet, completed: {'m-lunch'});
      await tester.ensureVisible(_toggle('m-snack'));
      expect(
        tester
            .getSemantics(_toggle('m-snack'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      _semanticTap(tester, 'Marcar Snack como completada');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.repository.marked, ['m-snack@$_date']);
      await tester.ensureVisible(_toggle('m-lunch'));
      _semanticTap(tester, 'Desmarcar Almuerzo como completada');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.repository.unmarked, ['m-lunch@$_date']);
      semantics.dispose();
    });
  });

  group('header', () {
    testWidgets('title in Barlow Condensed, summary and remaining macros', (
      tester,
    ) async {
      await _mount(tester, diet: _diet, completed: {'m-lunch'});
      final title = tester.widget<Text>(find.text('DEFINICIÓN'));
      expect(title.style?.fontFamily, AppTheme.displayFontFamily);
      expect(title.style?.fontSize, 44);
      expect(find.text('2150 kcal · 4 comidas'), findsOneWidget);
      // 2150 - 780 consumed, now the hero numeral (E7).
      expect(
        tester.widget<ExomNumeral>(find.byType(ExomNumeral)).value,
        '1370',
      );
    });

    testWidgets('progress agrees in number: 1/4 completada', (tester) async {
      await _mount(tester, diet: _diet, completed: {'m-lunch'});
      expect(find.text('1/4 completada'), findsOneWidget);
    });

    testWidgets('progress agrees in number: 3/4 completadas', (tester) async {
      await _mount(
        tester,
        diet: _diet,
        completed: {'m-lunch', 'm-snack', 'm-dinner'},
      );
      expect(find.text('3/4 completadas'), findsOneWidget);
    });

    testWidgets('progress in English: 3/4 completed', (tester) async {
      await _mount(
        tester,
        diet: _diet,
        completed: {'m-lunch', 'm-snack', 'm-dinner'},
        locale: const Locale('en'),
      );
      expect(find.text('3/4 completed'), findsOneWidget);
    });
  });

  group('shopping list row', () {
    // Entry «01» of the numbered index (E7); the key wraps the whole index.
    Finder row() => find
        .descendant(
          of: find.byKey(const Key('diet-shopping-list-row')),
          matching: find.byKey(const Key('exom-index-entry')),
        )
        .first;

    testWidgets('flat row: text 13+, 48 dp target, chevron, button semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _mount(tester, diet: _diet);
      final l10n = _l10n(tester);
      await _revealIndex(tester);
      await tester.ensureVisible(row());
      expect(row(), findsOneWidget);
      // The index paints its titles upper case; the spoken label keeps case.
      final title = l10n.weeklyExportShoppingList.toUpperCase();
      expect(
        find.descendant(of: row(), matching: find.text(title)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(), matching: find.byIcon(ExomIcons.next)),
        findsOneWidget,
      );
      expect(tester.getSize(row()).height, greaterThanOrEqualTo(60));
      final runs = _textRuns(tester).where((r) => r.text == title);
      expect(runs, isNotEmpty);
      expect(runs.every((r) => r.size >= 13), isTrue);
      expect(
        tester.getSemantics(row()),
        matchesSemantics(
          // Index entry 01: the position precedes the title in the label.
          label: '01\n${l10n.weeklyExportShoppingList}',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('tap starts the weekly flow for the shown date', (
      tester,
    ) async {
      final h = await _mount(tester, diet: _diet);
      // Short names: the test font is wide and the dropdown would overflow.
      h.repository.week = WeeklyDietEntity(
        weekStart: DateTime(2026, 11, 16),
        weekEnd: DateTime(2026, 11, 22),
        days: [
          WeeklyDietDayEntity(
            date: DateTime(2026, 11, 18),
            diet: DietEntity(
              id: 'd',
              name: 'D',
              meals: [
                _meal('a', 'LUNCH', 'A', variants: [_meal('b', 'LUNCH', 'B')]),
              ],
            ),
          ),
        ],
      );
      final l10n = _l10n(tester);
      await _revealIndex(tester);
      await tester.ensureVisible(row());
      await tester.tap(row());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Monday of 2026-11-18, the same week the calendar export reads.
      expect(h.repository.weeklyReads, ['2026-11-16']);
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsOneWidget);
      expect(find.text(l10n.weeklyGenerateShoppingList), findsOneWidget);
    });

    testWidgets('no alternatives: no selector, goes straight to generation', (
      tester,
    ) async {
      final h = await _mount(tester, diet: _diet);
      final pdf = _FakePdfService();
      if (sl.isRegistered<WeeklyDietPdfService>()) {
        sl.unregister<WeeklyDietPdfService>();
      }
      sl.registerSingleton<WeeklyDietPdfService>(pdf);
      h.repository.week = WeeklyDietEntity(
        weekStart: DateTime(2026, 11, 16),
        weekEnd: DateTime(2026, 11, 22),
        days: [
          WeeklyDietDayEntity(
            date: DateTime(2026, 11, 18),
            diet: DietEntity(
              id: 'd',
              name: 'D',
              meals: [_meal('a', 'LUNCH', 'A')],
            ),
          ),
        ],
      );
      final l10n = _l10n(tester);
      await _revealIndex(tester);
      await tester.ensureVisible(row());
      await tester.tap(row());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsNothing);
      expect(find.text(l10n.weeklyGenerateShoppingList), findsNothing);
      expect(pdf.shoppingLists, 1);
      expect(find.text(l10n.weeklyDietPrint), findsOneWidget);
    });

    testWidgets('week without diets shows the empty-period message', (
      tester,
    ) async {
      final h = await _mount(tester, diet: _diet);
      h.repository.week = WeeklyDietEntity(
        weekStart: DateTime(2026, 11, 16),
        weekEnd: DateTime(2026, 11, 22),
        days: [WeeklyDietDayEntity(date: DateTime(2026, 11, 18), diet: null)],
      );
      final l10n = _l10n(tester);
      await _revealIndex(tester);
      await tester.ensureVisible(row());
      await tester.tap(row());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.dietPeriodEmpty), findsOneWidget);
      expect(find.text(l10n.weeklyVariantSelectorTitle), findsNothing);
    });

    testWidgets('failure shows the export error message', (tester) async {
      await _mount(tester, diet: _diet);
      sl.unregister<GetWeeklyDietUseCase>();
      sl.registerSingleton<GetWeeklyDietUseCase>(
        GetWeeklyDietUseCase(_FailingWeekRepository()),
      );
      final l10n = _l10n(tester);
      await _revealIndex(tester);
      await tester.ensureVisible(row());
      await tester.tap(row());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.weeklyDietExportError), findsOneWidget);
    });

    testWidgets('not offered without a diet: only the history remains', (
      tester,
    ) async {
      await _mount(tester);
      expect(
        find.text(_l10n(tester).weeklyExportShoppingList.toUpperCase()),
        findsNothing,
      );
      expect(
        find.text(_l10n(tester).dietHistoryTitle.toUpperCase()),
        findsOneWidget,
      );
    });
  });

  group('existing actions', () {
    testWidgets('marking a meal sends the same command', (tester) async {
      final h = await _mount(tester, diet: _diet);
      await tester.ensureVisible(_toggle('m-snack'));
      await tester.tap(_toggle('m-snack'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.repository.marked, ['m-snack@$_date']);
      expect(h.repository.unmarked, isEmpty);
    });

    testWidgets('unmarking a completed meal sends the unmark command', (
      tester,
    ) async {
      final h = await _mount(tester, diet: _diet, completed: {'m-lunch'});
      await tester.ensureVisible(_toggle('m-lunch'));
      await tester.tap(_toggle('m-lunch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.repository.unmarked, ['m-lunch@$_date']);
      expect(h.repository.marked, isEmpty);
    });

    testWidgets('history button opens one read of the history', (tester) async {
      final h = await _mount(tester, diet: _diet);
      final l10n = _l10n(tester);
      expect(h.repository.historyReads, 0);
      await _revealIndex(tester);
      // The index paints its titles upper case.
      await tester.tap(find.text(l10n.dietHistoryTitle.toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.repository.historyReads, 1);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.dietHistoryEmpty), findsOneWidget);
    });

    testWidgets('meal rows follow breakfast, lunch, snack, dinner', (
      tester,
    ) async {
      await _mount(tester, diet: _diet);
      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(
        top('Avena, yogur griego y fruta'),
        lessThan(top('Arroz, pollo y verduras')),
      );
      expect(
        top('Arroz, pollo y verduras'),
        lessThan(top('Tostada integral con pavo')),
      );
      expect(
        top('Tostada integral con pavo'),
        lessThan(top('Merluza, patata y ensalada')),
      );
    });
  });

  // L4-I8 kept the history reachable in a pinned bar; E7 moves it to entry
  // «02» of the numbered index that closes the list. Same guarantee: at the end
  // of the list every row and both entries are fully visible and reachable.
  group('L4-I8 history stays reachable at the end of the list', () {
    for (final width in [390.0, 320.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          'index entries end the list and fit (${width}dp, x$scale)',
          (tester) async {
            await _mount(
              tester,
              diet: _diet,
              completed: {'m-lunch'},
              actions: [_action('m-lunch')],
              size: Size(width, 640),
              textScale: scale,
            );
            expect(find.byType(ExomPinnedFooter), findsNothing);
            final history = find.text(
              _l10n(tester).dietHistoryTitle.toUpperCase(),
            );
            await tester.scrollUntilVisible(
              history,
              300,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -400),
            );
            await tester.pumpAndSettle();
            final screen = tester.getRect(find.byType(Scaffold));
            for (final finder in [
              history,
              find.text(_l10n(tester).weeklyExportShoppingList.toUpperCase()),
              find.byKey(const Key('meal-row-m-dinner')),
            ]) {
              final rect = tester.getRect(finder);
              expect(
                rect.bottom,
                lessThanOrEqualTo(screen.bottom),
                reason: 'row $rect below the screen $screen',
              );
            }
            expect(
              tester.getTopLeft(history).dy,
              greaterThan(
                tester
                    .getTopLeft(
                      find.text(
                        _l10n(tester).weeklyExportShoppingList.toUpperCase(),
                      ),
                    )
                    .dy,
              ),
              reason: 'history is entry 02, under the shopping list',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('B layout: photo left, text centre, mark right', () {
    final photoDiet = DietEntity(
      id: 'diet-2',
      name: 'Definición',
      totalCalories: 2150,
      meals: [
        _meal(
          'm-breakfast',
          'BREAKFAST',
          'Avena, yogur griego y fruta',
          calories: 520,
          imageUrl: 'https://example.invalid/breakfast.jpg',
        ),
        _meal('m-lunch', 'LUNCH', 'Arroz, pollo y verduras', calories: 780),
      ],
    );
    Finder thumb(String id) => find.byKey(Key('meal-thumb-$id'));
    Finder inRow(String id, Finder matching) => find.descendant(
      of: find.byKey(Key('meal-row-$id')),
      matching: matching,
    );

    testWidgets('order is thumb < text < mark, all 64/48 dp', (tester) async {
      await _mount(tester, diet: photoDiet);
      for (final entry in {
        'm-breakfast': 'Avena, yogur griego y fruta',
        'm-lunch': 'Arroz, pollo y verduras',
      }.entries) {
        final t = tester.getRect(thumb(entry.key));
        final text = tester.getRect(inRow(entry.key, find.text(entry.value)));
        final mark = tester.getRect(_toggle(entry.key));
        expect(t.right, lessThanOrEqualTo(text.left), reason: entry.key);
        expect(text.right, lessThanOrEqualTo(mark.left), reason: entry.key);
        expect(t.size, const Size(64, 64), reason: entry.key);
        expect(mark.size, const Size(48, 48), reason: entry.key);
        expect(mark.center.dy, closeTo(t.center.dy, 0.5), reason: entry.key);
      }
    });

    testWidgets('photo uses CachedNetworkImage, no photo shows the icon box', (
      tester,
    ) async {
      await _mount(tester, diet: photoDiet);
      expect(
        find.descendant(
          of: thumb('m-breakfast'),
          matching: find.byType(CachedNetworkImage),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: thumb('m-lunch'),
          matching: find.byType(CachedNetworkImage),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: thumb('m-lunch'),
          matching: find.byIcon(ExomIcons.diet),
        ),
        findsOneWidget,
      );
    });

    DietEntity oneMeal(
      String type, {
      String? imageUrl,
      String name = 'Plato',
    }) => DietEntity(
      id: 'diet-x',
      name: 'X',
      meals: [_meal('m-x', type, name, imageUrl: imageUrl)],
    );

    testWidgets('blank or whitespace-only image url means no photo', (
      tester,
    ) async {
      for (final url in ['', '   ', ' \t ']) {
        await _mount(tester, diet: oneMeal('LUNCH', imageUrl: url));
        expect(
          find.descendant(
            of: thumb('m-x'),
            matching: find.byType(CachedNetworkImage),
          ),
          findsNothing,
          reason: 'url "$url"',
        );
        expect(
          find.descendant(
            of: thumb('m-x'),
            matching: find.byIcon(ExomIcons.diet),
          ),
          findsOneWidget,
          reason: 'url "$url"',
        );
      }
    });

    testWidgets('loading and error states show the icon box, not a gap', (
      tester,
    ) async {
      await _mount(
        tester,
        diet: oneMeal('LUNCH', imageUrl: 'https://example.invalid/a.jpg'),
      );
      final image = tester.widget<CachedNetworkImage>(
        find.descendant(
          of: thumb('m-x'),
          matching: find.byType(CachedNetworkImage),
        ),
      );
      expect(image.placeholder, isNotNull);
      expect(image.errorWidget, isNotNull);
      final url = image.imageUrl;
      final states = <String, Widget Function(BuildContext)>{
        'placeholder': (context) => image.placeholder!(context, url),
        'error': (context) => image.errorWidget!(context, url, Exception('x')),
      };
      for (final entry in states.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(body: Builder(builder: entry.value)),
          ),
        );
        expect(
          find.byIcon(ExomIcons.diet),
          findsOneWidget,
          reason: entry.key,
        );
        expect(
          find.ancestor(
            of: find.byIcon(ExomIcons.diet),
            matching: find.byWidgetPredicate(
              (w) =>
                  (w is ColoredBox && w.color == AppColors.surfaceElevated) ||
                  (w is DecoratedBox &&
                      w.decoration is BoxDecoration &&
                      (w.decoration as BoxDecoration).color ==
                          AppColors.surfaceElevated),
            ),
          ),
          findsOneWidget,
          reason: entry.key,
        );
      }
    });

    testWidgets('icon box has a 1 px rule border like the sketch', (
      tester,
    ) async {
      await _mount(tester, diet: oneMeal('LUNCH'));
      final decorated = find.descendant(
        of: thumb('m-x'),
        matching: find.byWidgetPredicate((w) {
          if (w is! DecoratedBox) return false;
          final d = w.decoration;
          if (d is! BoxDecoration) return false;
          final b = d.border;
          return b is Border &&
              b.top.width == 1 &&
              b.top.color == AppColors.borderSoft;
        }),
      );
      expect(decorated, findsOneWidget);
    });

    testWidgets('meal types map to distinct icons, unknown to the default', (
      tester,
    ) async {
      final icons = <String, IconData>{};
      for (final type in ['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER', 'OTHER']) {
        await _mount(tester, diet: oneMeal(type));
        final icon = tester.widget<Icon>(
          find.descendant(of: thumb('m-x'), matching: find.byType(Icon)),
        );
        icons[type] = icon.icon!;
      }
      expect(icons['BREAKFAST'], ExomIcons.sun);
      expect(icons['LUNCH'], ExomIcons.diet);
      expect(icons['SNACK'], ExomIcons.coffee);
      expect(icons['DINNER'], ExomIcons.sleep);
      expect(icons['OTHER'], ExomIcons.diet);
      expect(
        {
          icons['BREAKFAST'],
          icons['LUNCH'],
          icons['SNACK'],
          icons['DINNER'],
        }.length,
        4,
      );
    });

    testWidgets('completed description is struck through, open is not', (
      tester,
    ) async {
      await _mount(
        tester,
        diet: oneMeal('LUNCH', name: 'Arroz con pollo'),
        completed: {'m-x'},
      );
      TextDecoration? deco() =>
          tester.widget<Text>(find.text('Arroz con pollo')).style?.decoration;
      expect(deco(), TextDecoration.lineThrough);
      await _mount(tester, diet: oneMeal('LUNCH', name: 'Arroz con pollo'));
      expect(deco(), isNot(TextDecoration.lineThrough));
    });

    testWidgets('long description is capped at 2 lines, label stays full', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final long = List.filled(40, 'verduras').join(' ');
      await _mount(
        tester,
        diet: oneMeal('LUNCH', name: long),
        size: const Size(320, 1600),
      );
      final text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      final lineHeight = 14 * 1.35;
      expect(
        tester.getSize(find.text(long)).height,
        lessThanOrEqualTo(lineHeight * 2 + 1),
      );
      expect(
        find.semantics.byLabel(RegExp(RegExp.escape(long))),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('meal rows have no chevron, the index entries keep it', (
      tester,
    ) async {
      await _mount(tester, diet: _diet);
      await _revealIndex(tester);
      for (final id in ['m-breakfast', 'm-lunch', 'm-snack', 'm-dinner']) {
        expect(inRow(id, find.byIcon(ExomIcons.next)), findsNothing);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('diet-shopping-list-row')),
          matching: find.byIcon(ExomIcons.next),
        ),
        findsNWidgets(2), // both entries of the index
      );
    });

    testWidgets('completed meal dims the thumb to 0.45, open meal does not', (
      tester,
    ) async {
      await _mount(tester, diet: photoDiet, completed: {'m-lunch'});
      double opacity(String id) => tester
          .widget<Opacity>(
            find.descendant(of: thumb(id), matching: find.byType(Opacity)),
          )
          .opacity;
      expect(opacity('m-lunch'), closeTo(0.45, 0.001));
      expect(opacity('m-breakfast'), 1.0);
    });

    testWidgets('row tap opens the detail, mark tap only emits one event', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final h = await _mount(tester, diet: _diet);
      await tester.ensureVisible(_toggle('m-snack'));
      expect(
        tester.getSemantics(_toggle('m-snack')),
        matchesSemantics(
          label: 'Marcar Snack como completada',
          isButton: true,
          hasTapAction: true,
          hasCheckedState: true,
          isChecked: false,
        ),
      );
      await tester.tap(_toggle('m-snack'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.repository.marked, ['m-snack@$_date']);
      expect(find.byType(MealDetailSheet), findsNothing);
      await tester.tap(find.text('Arroz, pollo y verduras'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MealDetailSheet), findsOneWidget);
      expect(h.repository.marked, ['m-snack@$_date']);
      semantics.dispose();
    });

    testWidgets('photo tap also opens the detail', (tester) async {
      await _mount(tester, diet: photoDiet);
      await tester.tap(thumb('m-lunch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MealDetailSheet), findsOneWidget);
    });

    testWidgets('320 dp at 1.3x with sync line and chips does not overflow', (
      tester,
    ) async {
      await _mount(
        tester,
        diet: _diet,
        completed: {'m-breakfast'},
        actions: [_action('m-breakfast')],
        size: const Size(320, 1600),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byKey(const Key('meal-row-m-breakfast')));
      expect(row.height, greaterThan(64));
      _expectNoTextBelow13(tester);
    });
  });

  group('L4-I6 / L5-D5 figures without grouping, in both locales', () {
    // Characterisation: the contract (section 5.4) formats figures with the
    // active locale but the owner decided no thousands separator (2026-11-20),
    // so the visible result equals the old toStringAsFixed(0) in es and en.
    final bigDiet = DietEntity(
      id: 'diet-big',
      name: 'Volumen',
      totalCalories: 9000,
      totalProteinG: 1234,
      totalCarbsG: 12345.5,
      totalFatG: 68.4,
      meals: [
        _meal('m-big', 'LUNCH', 'Plato grande', protein: 1234, carbs: 12345.5),
        _meal('m-small', 'DINNER', 'Plato normal', protein: 68.4, carbs: 45),
      ],
    );

    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('remaining macros and meal rows, ${locale.languageCode}', (
        tester,
      ) async {
        await _mount(tester, diet: bigDiet, locale: locale);
        // Remaining macros, now figure columns (E7): value and unit as given.
        final columns = tester.widget<ExomFigureColumns>(
          find.byType(ExomFigureColumns),
        );
        expect(columns.items.map((i) => '${i.value} ${i.unit}').toList(), [
          '1234 g',
          '12346 g',
          '68 g',
        ]);
        // Meal rows: no separator at or above 1000, normal figures as before.
        expect(find.text('P 1234 g · C 12346 g'), findsOneWidget);
        expect(find.text('P 68 g · C 45 g'), findsOneWidget);
        expect(find.textContaining('1.234'), findsNothing);
        expect(find.textContaining('1,234'), findsNothing);
      });
    }
  });

  group('E7 · Nutrición (L5)', () {
    ThemeData themeOf(Brightness b) =>
        b == Brightness.dark ? AppTheme.dark : AppTheme.light;
    ExomThemePalette paletteOf(Brightness b) =>
        themeOf(b).extension<ExomThemePalette>()!;

    testWidgets(
      'two-line headline «Tu comida. / Sin improvisar.» in es and en',
      (tester) async {
        await _mount(tester, diet: _diet);
        var headline = tester.widget<ExomTwoLineHeadline>(
          find.byType(ExomTwoLineHeadline),
        );
        expect(headline.first, 'Tu comida.');
        expect(headline.second, 'Sin improvisar.');
        await _mount(tester, diet: _diet, locale: const Locale('en'));
        headline = tester.widget<ExomTwoLineHeadline>(
          find.byType(ExomTwoLineHeadline),
        );
        expect(headline.first, 'Your meals.');
        expect(headline.second, 'No improvising.');
      },
    );

    testWidgets('what is left is a hero figure with its day total beside it', (
      tester,
    ) async {
      await _mount(tester, diet: _diet, completed: {'m-lunch'});
      final numeral = tester.widget<ExomNumeral>(find.byType(ExomNumeral));
      // 2150 - 780 consumed; no thousands separator (L5-D33).
      expect(numeral.value, '1370');
      expect(numeral.unit, 'kcal');
      expect(numeral.size, ExomNumeralSize.hero96);
      expect(numeral.isData, isTrue);
      expect(find.text('TE QUEDAN'), findsOneWidget);
      expect(find.text('de 2150 kcal'), findsOneWidget);
    });

    testWidgets('remaining protein, carbs and fat go in figure columns', (
      tester,
    ) async {
      await _mount(tester, diet: _diet, completed: {'m-dinner'});
      final columns = tester.widget<ExomFigureColumns>(
        find.byType(ExomFigureColumns),
      );
      expect(columns.numbered, isFalse);
      // 160 - 40, 220 - 45, 70 - 0.
      expect(columns.items.map((i) => '${i.value}${i.unit}').toList(), [
        '120g',
        '175g',
        '70g',
      ]);
    });

    testWidgets('progress is a segmented rule, one segment per meal', (
      tester,
    ) async {
      await _mount(tester, diet: _diet, completed: {'m-lunch'});
      final rule = tester.widget<ExomProgressRule>(
        find.byType(ExomProgressRule),
      );
      expect(rule.segments, 4);
      expect(rule.value, 0.25);
      expect(find.text('1/4 completada'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets(
        'done mark is an outline in the data colour, ${brightness.name}',
        (tester) async {
          await _mount(
            tester,
            diet: _diet,
            completed: {'m-lunch'},
            theme: themeOf(brightness),
          );
          final data = paletteOf(brightness).data;
          final done = tester.widget<Icon>(
            find.descendant(
              of: _toggle('m-lunch'),
              matching: find.byIcon(ExomIcons.check),
            ),
          );
          expect(done.color, data);
          final box = tester.widget<Container>(
            find.descendant(
              of: _toggle('m-lunch'),
              matching: find.byType(Container),
            ),
          );
          final decoration = box.decoration! as BoxDecoration;
          expect(decoration.color, isNull, reason: 'outline, not filled');
          expect((decoration.border! as Border).top.color, data);
          final open = tester.widget<Container>(
            find.descendant(
              of: _toggle('m-snack'),
              matching: find.byType(Container),
            ),
          );
          expect(
            ((open.decoration! as BoxDecoration).border! as Border).top.color,
            paletteOf(brightness).textPrimary,
          );
        },
      );
    }

    testWidgets(
      'a done meal says «Hecha» in the data colour; open and queued do not',
      (tester) async {
        await _mount(
          tester,
          diet: _diet,
          completed: {'m-lunch', 'm-snack'},
          actions: [_action('m-snack')],
        );
        Finder inRow(String id) => find.descendant(
          of: find.byKey(Key('meal-row-$id')),
          matching: find.text('Hecha'),
        );
        expect(inRow('m-lunch'), findsOneWidget);
        expect(
          tester.widget<Text>(inRow('m-lunch')).style?.color,
          AppTheme.dark.extension<ExomThemePalette>()!.data,
        );
        expect(inRow('m-dinner'), findsNothing);
        // A queued change shows its sync state instead (never both).
        expect(inRow('m-snack'), findsNothing);
        expect(find.text(_l10n(tester).syncStatusPending), findsOneWidget);
      },
    );

    testWidgets('index lists the shopping list and the history, numbered', (
      tester,
    ) async {
      await _mount(tester, diet: _diet);
      await _revealIndex(tester);
      final index = tester.widget<ExomIndexList>(find.byType(ExomIndexList));
      expect(index.items.map((i) => i.title).toList(), [
        'Lista de la compra',
        'Histórico de dietas',
      ]);
      expect(find.byKey(const Key('diet-shopping-list-row')), findsOneWidget);
      expect(find.byType(ExomPinnedFooter), findsNothing);
    });

    testWidgets('empty day: «Sin plan. / Por ahora.» and the history entry', (
      tester,
    ) async {
      final h = await _mount(tester);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline),
      );
      expect(headline.first, 'Sin plan.');
      expect(headline.second, 'Por ahora.');
      expect(find.text(_l10n(tester).noDietForDateMessage), findsOneWidget);
      expect(
        find.text(_l10n(tester).contactCoachForPlanMessage),
        findsOneWidget,
      );
      final index = tester.widget<ExomIndexList>(find.byType(ExomIndexList));
      expect(index.items.map((i) => i.title).toList(), ['Histórico de dietas']);
      expect(h.repository.historyReads, 0);
    });
  });
}
