// L4 unit 1: Nutrición on the V4 system. Presentation only: the bloc, the
// repository contract and the offline queue are the real ones / read-only.
import 'dart:async';
import 'dart:typed_data';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
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
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

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
}) => MealEntity(
  id: id,
  type: type,
  name: name,
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
        child: child!,
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
        find.descendant(of: row, matching: find.byIcon(Icons.schedule)),
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
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _toggle('m-snack'),
          matching: find.byIcon(Icons.check),
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
      // 2150 - 780 consumed.
      expect(find.text('1370 kcal', findRichText: true), findsOneWidget);
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
    Finder row() => find.byKey(const Key('diet-shopping-list-row'));

    testWidgets('flat row: text 13+, 48 dp target, chevron, button semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _mount(tester, diet: _diet);
      final l10n = _l10n(tester);
      await tester.ensureVisible(row());
      expect(row(), findsOneWidget);
      expect(
        find.descendant(
          of: row(),
          matching: find.text(l10n.weeklyExportShoppingList),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(), matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
      expect(tester.getSize(row()).height, greaterThanOrEqualTo(48));
      final runs = _textRuns(
        tester,
      ).where((r) => r.text == l10n.weeklyExportShoppingList);
      expect(runs, isNotEmpty);
      expect(runs.every((r) => r.size >= 13), isTrue);
      expect(
        tester.getSemantics(row()),
        matchesSemantics(
          label: l10n.weeklyExportShoppingList,
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
      await tester.ensureVisible(row());
      await tester.tap(row());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.weeklyDietExportError), findsOneWidget);
    });

    testWidgets('not shown without a diet', (tester) async {
      await _mount(tester);
      expect(row(), findsNothing);
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
      await tester.tap(find.text(l10n.dietHistoryTitle));
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
}
