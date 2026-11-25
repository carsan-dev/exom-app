// L3 unit 2: training detail on design A (rule rows, pinned next action,
// per-exercise sync status, display-only weight unit).
import 'dart:async';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/features/home/presentation/widgets/home_session_photo.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';
import 'package:exom_app/features/trainings/domain/usecases/complete_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_completed_exercises_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_previous_exercise_performances_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_today_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_trainings_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/mark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/unmark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/exom_component_harness.dart'
    show expectTapTargetGuidelines;
import '../../../../core/widgets/expect_no_lime_ink.dart';

const _date = '2026-09-05';
const _execution = 'execution-1';
const _trainingId = 'training-1';

TrainingExerciseEntity _exercise(int order, String name, {int sets = 3}) =>
    TrainingExerciseEntity(
      id: 'te-$order',
      order: order,
      sets: sets,
      repsOrDuration: '8',
      targetRir: 2,
      restSeconds: 90,
      exercise: ExerciseEntity(id: 'ex-$order', name: name, muscleGroups: []),
    );

TrainingExerciseEntity _member(int order, String name, int position) =>
    TrainingExerciseEntity(
      id: 'te-$order',
      order: order,
      sets: 3,
      repsOrDuration: '10',
      restSeconds: 30,
      blockId: 'block-1',
      positionInBlock: position,
      blockName: 'Circuito core',
      blockRounds: 2,
      restBetweenRoundsSeconds: 45,
      exercise: ExerciseEntity(id: 'ex-$order', name: name, muscleGroups: []),
    );

final _training = TrainingEntity(
  id: _trainingId,
  name: 'Pierna fuerza',
  types: const ['FUERZA'],
  level: 'INTERMEDIATE',
  estimatedDurationMin: 55,
  tags: const [],
  exercises: [
    _exercise(1, 'Sentadilla búlgara', sets: 4),
    _exercise(2, 'Peso muerto rumano'),
    _exercise(3, 'Elevación de gemelos'),
    _exercise(4, 'Plancha frontal'),
    _exercise(5, 'Hip thrust'),
  ],
);

final _circuitFirst = TrainingEntity(
  id: _trainingId,
  name: 'Core',
  types: const ['FUERZA'],
  level: 'INTERMEDIATE',
  tags: const [],
  exercises: [
    _member(1, 'Crunch', 0),
    _member(2, 'Plancha', 1),
    _exercise(3, 'Remo'),
  ],
);

const _previous = [
  SetPerformance(setNumber: 2, reps: 8, weightKg: 62.5),
  SetPerformance(setNumber: 1, reps: 8, weightKg: 60),
];

class _Storage extends LocalStorage {
  _Storage({required this.unitSystem});

  final UnitSystem unitSystem;
  List<Map<String, dynamic>> actions = [];
  final Map<String, ActiveWorkoutHiveModel> drafts = {};
  List<Map<String, dynamic>> confirmed = [];

  @override
  String? get sessionStamp => 'owner:1:test';
  @override
  bool get hasQuarantinedWorkoutDrafts => false;
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => [...actions];
  @override
  List<Map<String, dynamic>> getTrainingExecutions(
    String trainingId,
    String date,
  ) => const [];
  @override
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(
    String trainingId,
    String date,
  ) => [...confirmed];
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => const [
    {
      'id': _execution,
      'training_id': _trainingId,
      'assignment_date': _date,
      'status': 'pending',
    },
  ];
  @override
  bool hasCompletedTrainingExecution(String trainingId, String date) => false;
  @override
  Map<String, dynamic>? getTrainingCompletionDraft(
    String trainingId,
    String date,
    String executionId,
  ) => null;
  @override
  Future<void> saveTrainingCompletionDraft(
    String trainingId,
    String date,
    String executionId, {
    int? rpe,
    String? notes,
  }) async {}
  @override
  List<Map<String, dynamic>> getFeedbackUploadQueue() => const [];
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) =>
      drafts[exerciseId];
  @override
  ActiveWorkoutHiveModel? recoverableLegacyWorkout(
    String trainingId,
    String exerciseId,
    String date,
  ) => null;
  @override
  ValueNotifier<Box<ActiveWorkoutHiveModel>> watchActiveWorkouts() =>
      ValueNotifier<Box<ActiveWorkoutHiveModel>>(_EmptyBox());
  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => const Locale('es');
  @override
  UnitSystem getUnitSystemPreference() => unitSystem;
}

class _EmptyBox extends Fake implements Box<ActiveWorkoutHiveModel> {}

class _Sync extends OfflineSyncService {
  _Sync(LocalStorage storage) : super(ApiClient(useAuth: false), storage);
  final controller = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => controller.stream;
  @override
  CompletionSyncBlocker? completionBlocker(
    String trainingId,
    String date,
    String? sessionId,
  ) => null;
}

class _Repository extends Fake implements TrainingRepository {
  _Repository(this.training, this.completed);
  final TrainingEntity training;
  final Set<String> completed;

  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      training;
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      TrainingDayProgress(
        sessions: {
          _execution: TrainingDayProgress(
            ids: completed,
            weights: {for (final id in completed) id: 62.5},
          ),
        },
        sessionTrainings: const {_execution: _trainingId},
      );
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) async => {'ex-1': _previous, 'ex-3': _previous};
}

Map<String, dynamic> _action(String exercise, String status) => {
  'id': 'op-$exercise',
  'type': 'mark_exercise_completed',
  'date': _date,
  'training_exercise_id': exercise,
  'training_session_id': _execution,
  'status': status,
};

Map<String, dynamic> _completionAction(String status) => {
  'id': 'op-complete-training',
  'type': 'complete_training',
  'date': _date,
  'training_id': _trainingId,
  'training_session_id': _execution,
  'status': status,
};

class _Harness {
  _Harness(this.storage, this.sync, this.pushed, this.router);
  final _Storage storage;
  final _Sync sync;

  /// `extra` of every build of a pushed route (a builder may run more than
  /// once per push: use [pushedRoutes] to count pushes).
  final List<Object?> pushed;
  final GoRouter router;

  int get pushedRoutes =>
      router.routerDelegate.currentConfiguration.matches.length - 1;
}

Future<_Harness> _mount(
  WidgetTester tester, {
  TrainingEntity? training,
  Set<String> completed = const {},
  List<Map<String, dynamic>> actions = const [],
  UnitSystem unitSystem = UnitSystem.metric,
  ThemeData? theme,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  TextScaler? textScaler,
  void Function(_Storage storage)? seed,
  Locale locale = const Locale('es'),
  ValueListenable<ThemeMode>? themeMode,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final storage = _Storage(unitSystem: unitSystem)..actions = [...actions];
  seed?.call(storage);
  final sync = _Sync(storage);
  final repository = _Repository(training ?? _training, completed);
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<OfflineSyncService>(sync);
  sl.registerFactory<TrainingBloc>(
    () => TrainingBloc(
      getTodayTrainingUseCase: GetTodayTrainingUseCase(repository),
      getTrainingsUseCase: GetTrainingsUseCase(repository),
      getTrainingUseCase: GetTrainingUseCase(repository),
      markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(repository),
      unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(
        repository,
      ),
      completeTrainingUseCase: CompleteTrainingUseCase(repository),
      getCompletedExercisesUseCase: GetCompletedExercisesUseCase(repository),
      getPreviousExercisePerformancesUseCase:
          GetPreviousExercisePerformancesUseCase(repository),
    ),
  );
  final preferences = AppPreferencesCubit(storage);
  addTearDown(preferences.close);
  final pushed = <Object?>[];
  final router = GoRouter(
    initialLocation: '/detail',
    routes: [
      GoRoute(
        path: '/detail',
        builder: (_, _) => const TrainingDetailPage(
          trainingId: _trainingId,
          selectedDate: _date,
          selectedExecutionId: _execution,
        ),
      ),
      GoRoute(
        path: '/trainings/:training/exercises/:exercise',
        builder: (_, state) {
          pushed.add(state.extra);
          return const Scaffold(body: Text('active-exercise-route'));
        },
      ),
      GoRoute(
        path: '/trainings/:training/circuits/:block',
        builder: (_, state) {
          pushed.add(state.extra);
          return const Scaffold(body: Text('active-circuit-route'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  final fixedMode = ValueNotifier(ThemeMode.light);
  addTearDown(fixedMode.dispose);
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>.value(
      value: preferences,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode ?? fixedMode,
        builder: (context, mode, _) => MaterialApp.router(
          routerConfig: router,
          // With [themeMode] the app follows it between both themes;
          // otherwise [theme] (dark by default) is the only theme.
          theme: themeMode == null ? theme ?? AppTheme.dark : AppTheme.light,
          darkTheme: themeMode == null ? null : AppTheme.dark,
          themeMode: mode,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: textScaler ?? TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return _Harness(storage, sync, pushed, router);
}

/// The detail of [training] (by default five exercises) for the overflow
/// sweep of `test/l10n/long_string_overflow_test.dart` (CC 3).
Future<void> pumpTrainingDetail(
  WidgetTester tester, {
  TrainingEntity? training,
  Set<String> completed = const {},
  required double width,
  required Locale locale,
  required TextScaler textScaler,
  Brightness brightness = Brightness.dark,
}) async {
  await _mount(
    tester,
    training: training,
    completed: completed,
    size: Size(width, 640),
    textScaler: textScaler,
    locale: locale,
    theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
  );
}

/// (value, label) of each figure of the header columns.
List<(String, String)> _figures(WidgetTester tester) => [
  for (final item
      in tester.widget<ExomFigureColumns>(find.byType(ExomFigureColumns)).items)
    (item.value, item.label),
];

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(TrainingDetailPage)));

Color? _background(WidgetTester tester, Finder button) => tester
    .widget<ElevatedButton>(button)
    .style
    ?.backgroundColor
    ?.resolve(const <WidgetState>{});

/// The row check mark (24 dp). The base told it apart from the 18 dp check by
/// using Icons.check_rounded; both are now ExomIcons.check, so the size does it.
final Finder _rowCheck = find.byWidgetPredicate(
  (Widget w) => w is Icon && w.icon == ExomIcons.check && w.size == 24,
);

void main() {
  tearDown(sl.reset);

  final completeButton = find.byKey(const Key('complete-training-button'));
  final nextButton = find.byKey(const Key('training-next-button'));

  testWidgets('back button carries the localized back label', (tester) async {
    await _mount(tester);
    final context = tester.element(find.byType(TrainingDetailPage));
    expect(
      find.byTooltip(MaterialLocalizations.of(context).backButtonTooltip),
      findsOneWidget,
    );
  });

  testWidgets('while work remains: lime next action, completion secondary', (
    tester,
  ) async {
    await _mount(tester, completed: {'te-1'});
    final l10n = _l10n(tester);
    expect(nextButton, findsOneWidget);
    expect(
      find.text(
        l10n.trainingDetailNextAction('Peso muerto rumano').toUpperCase(),
      ),
      findsOneWidget,
    );
    expect(completeButton, findsOneWidget);
    expect(_background(tester, completeButton), Colors.transparent);
    expect(
      tester.widget<ElevatedButton>(completeButton).onPressed,
      isNotNull,
    );
    expect(find.text(l10n.completeTrainingConfirmAction), findsOneWidget);
  });

  testWidgets('next opens the first unfinished exercise with its route args', (
    tester,
  ) async {
    final harness = await _mount(tester, completed: {'te-1', 'te-2'});
    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    expect(find.text('active-exercise-route'), findsOneWidget);
    final args = harness.pushed.last! as ActiveExercisePageArgs;
    expect(args.trainingExercise.id, 'te-3');
    expect(args.sessionId, _execution);
    expect(args.assignmentDate, _date);
    expect(args.trainingName, 'Pierna fuerza');
    expect(args.initialWeightKg, isNull);
    expect(args.previousPerformances, _previous);
    expect(args.currentPerformances, isNull);
  });

  testWidgets('next passes today weight of a started exercise', (
    tester,
  ) async {
    final harness = await _mount(
      tester,
      training: TrainingEntity(
        id: _trainingId,
        name: 'Pierna fuerza',
        types: const ['FUERZA'],
        level: 'INTERMEDIATE',
        tags: const [],
        exercises: [_exercise(1, 'Sentadilla búlgara', sets: 4)],
      ),
    );
    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    final args = harness.pushed.last! as ActiveExercisePageArgs;
    expect(args.trainingExercise.id, 'te-1');
    expect(args.previousPerformances, _previous);
  });

  testWidgets('next opens a circuit exactly as its row does', (tester) async {
    final harness = await _mount(tester, training: _circuitFirst);
    expect(
      find.text(
        _l10n(tester).trainingDetailNextAction('Circuito core').toUpperCase(),
      ),
      findsOneWidget,
    );
    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    expect(find.text('active-circuit-route'), findsOneWidget);
    final args = harness.pushed.last! as ActiveCircuitPageArgs;
    expect(args.blockId, 'block-1');
    expect(args.sessionId, _execution);
    expect(args.exercises.map((e) => e.id), ['te-1', 'te-2']);
    expect(args.rounds, 2);
    expect(args.restBetweenRoundsSeconds, 45);
  });

  testWidgets('a double tap on next pushes one route', (tester) async {
    final harness = await _mount(tester);
    await tester.tap(nextButton);
    await tester.tap(nextButton, warnIfMissed: false);
    await tester.pump();
    await tester.tap(nextButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(harness.pushedRoutes, 1);
  });

  testWidgets('all done: completion is the only lime action and keeps its flow', (
    tester,
  ) async {
    await _mount(
      tester,
      completed: {for (var i = 1; i <= 5; i++) 'te-$i'},
    );
    expect(nextButton, findsNothing);
    expect(find.byType(ExomPrimaryButton), findsNothing);
    expect(_background(tester, completeButton), AppColors.primary);
    await tester.tap(completeButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-training-confirmation')), findsOneWidget);
    for (var value = 1; value <= 10; value++) {
      expect(find.byKey(Key('completion-rpe-$value')), findsOneWidget);
    }
    expect(find.byKey(const Key('completion-note')), findsOneWidget);
    expect(find.byKey(const Key('confirm-complete-training')), findsOneWidget);
    expect(
      tester
          .widget<ExomPrimaryButton>(
            find.byKey(const Key('confirm-complete-training')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('completion-rpe-8')));
    await tester.pump();
    expect(find.byKey(const Key('completion-rpe-selected')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-complete-training')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-training-confirmation')), findsNothing);
  });

  testWidgets('a draft set with only RIR is not counted as done in the row', (
    tester,
  ) async {
    await _mount(
      tester,
      completed: const {},
      size: const Size(390, 1600),
      seed: (storage) => storage.drafts['te-5:$_date:$_execution'] =
          ActiveWorkoutHiveModel(
            trainingId: _trainingId,
            exerciseId: 'te-5:$_date:$_execution',
            currentSet: 3,
            completedSets: 2,
            lastWeightKg: 40,
            completedSetData: const [
              {'set_number': 1, 'rir': 2},
              {'set_number': 2, 'reps': 8, 'weight_kg': 40.0},
            ],
          ),
    );
    final l10n = _l10n(tester);
    expect(
      find.text('${l10n.trainingDetailSetsProgress(1, 3)} · 40 kg'),
      findsOneWidget,
    );
  });

  testWidgets('rows show each exercise sync state from the queue', (
    tester,
  ) async {
    final harness = await _mount(
      tester,
      completed: {'te-1', 'te-2', 'te-3', 'te-4'},
      size: const Size(390, 1600),
      actions: [
        _action('te-2', 'queued'),
        _action('te-3', 'uploading'),
        _action('te-4', 'failed'),
      ],
      seed: (storage) => storage.drafts['te-5:$_date:$_execution'] =
          ActiveWorkoutHiveModel(
            trainingId: _trainingId,
            exerciseId: 'te-5:$_date:$_execution',
            currentSet: 2,
            completedSets: 1,
            lastWeightKg: 40,
          ),
    );
    final l10n = _l10n(tester);
    expect(find.text(l10n.syncStatusConfirmed), findsOneWidget);
    expect(find.text(l10n.syncStatusPending), findsOneWidget);
    expect(find.text(l10n.syncStatusSending), findsOneWidget);
    expect(find.text(l10n.syncStatusFailed), findsOneWidget);
    expect(find.text(l10n.syncStatusSavedOnDevice), findsOneWidget);
    expect(
      find.text('${l10n.trainingDetailSetsProgress(1, 3)} · 40 kg'),
      findsOneWidget,
    );

    // The queue acknowledges te-2: the mounted detail refreshes on changes.
    harness.storage.actions = [
      _action('te-3', 'uploading'),
      _action('te-4', 'failed'),
    ];
    harness.sync.controller.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.syncStatusPending), findsNothing);
    expect(find.text(l10n.syncStatusConfirmed), findsNWidgets(2));
  });

  testWidgets('footer: all done and open says Terminar sesión, closed says completed', (
    tester,
  ) async {
    final all = {for (var i = 1; i <= 5; i++) 'te-$i'};
    await _mount(tester, completed: all, size: const Size(390, 1600));
    final l10n = _l10n(tester);
    expect(
      find.descendant(
        of: completeButton,
        matching: find.text(l10n.completeTrainingSheetTitle),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.workoutCompletedMessage), findsNothing);
    expect(tester.widget<ElevatedButton>(completeButton).onPressed, isNotNull);

    await _mount(
      tester,
      completed: all,
      size: const Size(390, 1600),
      seed: (storage) => storage.confirmed = const [
        {'id': _execution, 'status': 'completed'},
      ],
    );
    expect(
      find.descendant(
        of: completeButton,
        matching: find.text(l10n.workoutCompletedMessage),
      ),
      findsOneWidget,
    );
    expect(tester.widget<ElevatedButton>(completeButton).onPressed, isNull);
  });

  testWidgets('rows completed by "Completar todo" follow complete_training', (
    tester,
  ) async {
    final all = {for (var i = 1; i <= 5; i++) 'te-$i'};
    final harness = await _mount(
      tester,
      completed: all,
      size: const Size(390, 1600),
      actions: [_completionAction('queued')],
    );
    final l10n = _l10n(tester);
    expect(find.text(l10n.syncStatusConfirmed), findsNothing);
    expect(find.text(l10n.syncStatusPending), findsNWidgets(5));

    Future<void> queue(List<Map<String, dynamic>> actions) async {
      harness.storage.actions = actions;
      harness.sync.controller.add(null);
      await tester.pump();
      await tester.pump();
    }

    await queue([_completionAction('uploading')]);
    expect(find.text(l10n.syncStatusConfirmed), findsNothing);
    expect(find.text(l10n.syncStatusSending), findsNWidgets(5));

    // A mark action of te-1 still decides that row.
    await queue([_action('te-1', 'queued'), _completionAction('failed')]);
    expect(find.text(l10n.syncStatusConfirmed), findsNothing);
    expect(find.text(l10n.syncStatusPending), findsOneWidget);
    expect(find.text(l10n.syncStatusFailed), findsNWidgets(4));

    await queue(const []);
    expect(find.text(l10n.syncStatusConfirmed), findsNWidgets(5));
  });

  for (final (locale, label) in const [
    (Locale('es'), 'Intermedio'),
    (Locale('en'), 'Intermediate'),
  ]) {
    testWidgets('the level is localized, not the raw enum (${locale.languageCode})', (
      tester,
    ) async {
      // L3 review B-F6: «INTERMEDIATE» used to be shown as sent by the API.
      await _mount(tester, locale: locale);
      expect(find.textContaining(label), findsOneWidget);
      expect(find.textContaining('INTERMEDIATE'), findsNothing);

      // L5-E2a: the header with its figures can push the row below the
      // fold with the test font; bring it on stage first.
      await tester.scrollUntilVisible(
        find.text('Peso muerto rumano'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peso muerto rumano'));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(find.textContaining('INTERMEDIATE'), findsNothing);
    });
  }

  testWidgets('an unknown level falls back to its raw text', (tester) async {
    await _mount(
      tester,
      training: TrainingEntity(
        id: _trainingId,
        name: 'Pierna fuerza',
        types: const ['FUERZA'],
        level: 'ELITE',
        tags: const [],
        exercises: [_exercise(1, 'Sentadilla búlgara')],
      ),
    );
    expect(find.textContaining('ELITE'), findsOneWidget);
  });

  testWidgets('weights follow the unit preference for display only', (
    tester,
  ) async {
    // L5-E2a: a tall surface keeps both rows with a previous set on stage
    // under the session progress block.
    const tall = Size(390, 1600);
    await _mount(tester, completed: {'te-1'}, size: tall);
    final l10n = _l10n(tester);
    expect(
      find.text(l10n.trainingDetailPrevious('8 × 60 kg')),
      findsNWidgets(2),
    );
    expect(
      find.text(l10n.trainingDetailToday('62,5 kg')),
      findsOneWidget,
    );

    await _mount(
      tester,
      completed: {'te-1'},
      unitSystem: UnitSystem.imperial,
      size: tall,
    );
    expect(
      find.text(l10n.trainingDetailPrevious('8 × 132,28 lb')),
      findsNWidgets(2),
    );
    expect(
      find.text(l10n.trainingDetailToday('137,79 lb')),
      findsOneWidget,
    );
  });

  testWidgets('a completed row is done without lime: check and muted name', (
    tester,
  ) async {
    await _mount(tester, completed: {'te-1'});
    expect(_rowCheck, findsOneWidget);
    final name = tester.widget<Text>(find.text('Sentadilla búlgara'));
    final palette = AppTheme.dark.extension<ExomThemePalette>()!;
    expect(name.style?.color, palette.textSecondary);
    expect(name.style?.color, isNot(AppColors.primary));
  });

  for (final brightness in Brightness.values) {
    testWidgets('320 dp at 1.6x: no overflow, list scrolls, actions reachable '
        '(${brightness.name})', (tester) async {
      await _mount(
        tester,
        training: TrainingEntity(
          id: _trainingId,
          name: 'Entrenamiento de fuerza con nombre extraordinariamente largo',
          types: const ['FUERZA', 'HIPERTROFIA'],
          level: 'INTERMEDIATE',
          estimatedDurationMin: 55,
          tags: const ['pierna', 'gimnasio'],
          exercises: [
            _exercise(1, 'Sentadilla búlgara con mancuernas y pausa isométrica'),
            _exercise(2, 'Peso muerto rumano'),
            _exercise(3, 'Elevación de gemelos en máquina sentado'),
          ],
        ),
        completed: {'te-1'},
        actions: [_action('te-1', 'queued')],
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(nextButton.hitTestable(), findsOneWidget);
      expect(completeButton.hitTestable(), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      // Drag until the row is hit-testable, not merely built inside the
      // cache extent: with the shorter localized level (L3 review B-F6) the
      // old finder stopped dragging while the row was not yet hit-testable.
      await tester.dragUntilVisible(
        find.text('Elevación de gemelos en máquina sentado').hitTestable(),
        scrollable,
        const Offset(0, -200),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text('Elevación de gemelos en máquina sentado').hitTestable(),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  }

  testWidgets('a long exercise name wraps instead of being ellipsised', (
    tester,
  ) async {
    const longName = 'Sentadilla búlgara con mancuernas y pausa isométrica';
    await _mount(
      tester,
      training: TrainingEntity(
        id: _trainingId,
        name: 'Pierna',
        types: const ['FUERZA'],
        level: 'INTERMEDIATE',
        tags: const [],
        exercises: [_exercise(1, longName)],
      ),
      size: const Size(320, 640),
    );
    await tester.ensureVisible(find.text(longName, skipOffstage: false));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text(longName));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.getSize(find.text(longName)).height, greaterThan(30));
  });

  testWidgets('L3b P5c: at 320x568 and 2.0x the pinned actions are bounded '
      'and the list stays reachable', (tester) async {
    await _mount(
      tester,
      training: TrainingEntity(
        id: _trainingId,
        name: 'Entrenamiento de fuerza con nombre extraordinariamente largo',
        types: const ['FUERZA', 'HIPERTROFIA'],
        level: 'INTERMEDIATE',
        estimatedDurationMin: 55,
        tags: const ['pierna', 'gimnasio'],
        exercises: [
          _exercise(1, 'Sentadilla búlgara con mancuernas y pausa isométrica'),
          _exercise(2, 'Peso muerto rumano'),
          _exercise(3, 'Elevación de gemelos en máquina sentado'),
        ],
      ),
      completed: {'te-1'},
      actions: [_action('te-1', 'queued')],
      size: const Size(320, 568),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);

    // The first pinned button starts below 60 % of the screen: the footer
    // (12 dp of padding above it) takes at most 40 %.
    final next = find.byKey(const Key('training-next-button'));
    expect(tester.getRect(next).top, greaterThanOrEqualTo(568 * 0.6));

    final scrollable = find.byType(Scrollable).first;
    await tester.dragUntilVisible(
      find.text('Elevación de gemelos en máquina sentado').hitTestable(),
      scrollable,
      const Offset(0, -200),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.text('Elevación de gemelos en máquina sentado').hitTestable(),
      findsOneWidget,
    );
  });

  group('header total of sets (shared planned-sets rule, as Inicio)', () {
    TrainingExerciseEntity circuitMember(int order, int position) =>
        TrainingExerciseEntity(
          id: 'te-$order',
          order: order,
          sets: 1,
          repsOrDuration: '10',
          restSeconds: 30,
          blockId: 'block-1',
          positionInBlock: position,
          blockName: 'Circuito',
          blockRounds: 3,
          restBetweenRoundsSeconds: 45,
          exercise: ExerciseEntity(
            id: 'ex-$order',
            name: 'Ejercicio $order',
            muscleGroups: const [],
          ),
        );

    TrainingEntity session(List<TrainingExerciseEntity> exercises) =>
        TrainingEntity(
          id: _trainingId,
          name: 'Mixto',
          types: const ['FUERZA'],
          level: 'INTERMEDIATE',
          tags: const [],
          exercises: exercises,
        );

    testWidgets('a circuit counts sets x rounds, like Inicio', (tester) async {
      await _mount(
        tester,
        training: session([
          for (var i = 0; i < 4; i++) circuitMember(i + 1, i),
          _exercise(5, 'Remo'),
          _exercise(6, 'Press'),
        ]),
      );
      // L5-E2a: the totals moved from the fact line to the numbered figures.
      expect(_figures(tester), [
        ('6', 'ejercicios'),
        ('18', 'series'),
      ]);
    });

    testWidgets('without circuits the total is the plain sum', (tester) async {
      await _mount(
        tester,
        training: session([_exercise(1, 'Remo'), _exercise(2, 'Press')]),
      );
      expect(_figures(tester), [
        ('2', 'ejercicios'),
        ('6', 'series'),
      ]);
    });
  });
  // L5-E2a «Detalle del entreno (piel)»: photo on top, title and date,
  // progress as a figure, numbered rows with a thumbnail (sketch
  // e-migradas.html, frames f-det and f-det-mitad). A tall surface keeps every
  // row on stage: the test font (Ahem) is wider than the bundled faces and
  // stacks the figure columns.
  group('L5-E2a skin', () {
    const tall = Size(390, 1600);

    TrainingExerciseEntity photoExercise(int order, String name, int sets) =>
        TrainingExerciseEntity(
          id: 'te-$order',
          order: order,
          sets: sets,
          repsOrDuration: '8',
          restSeconds: 90,
          exercise: ExerciseEntity(
            id: 'ex-$order',
            name: name,
            muscleGroups: const [],
            thumbnailUrl: order == 1 ? null : 'https://example.test/$order.jpg',
          ),
        );

    final withPhotos = TrainingEntity(
      id: _trainingId,
      name: 'Pierna fuerza',
      types: const ['FUERZA'],
      level: 'INTERMEDIATE',
      estimatedDurationMin: 55,
      tags: const [],
      exercises: [
        photoExercise(1, 'Sentadilla búlgara', 4),
        photoExercise(2, 'Peso muerto rumano', 3),
        photoExercise(3, 'Elevación de gemelos', 3),
      ],
    );

    testWidgets('before starting: photo, date, numbered figures and rows', (
      tester,
    ) async {
      await _mount(tester, training: withPhotos, size: tall);
      final l10n = _l10n(tester);
      // The session photo is the first usable exercise thumbnail.
      expect(
        tester.widget<HomeSessionPhoto>(find.byType(HomeSessionPhoto)).url,
        'https://example.test/2.jpg',
      );
      final date = toBeginningOfSentenceCase(
        DateFormat.MMMMEEEEd('es').format(DateTime(2026, 9, 5)),
      );
      expect(find.text(date), findsOneWidget);
      expect(_figures(tester), [
        ('3', 'ejercicios'),
        ('10', 'series'),
        ('55', l10n.trainingsFigureMinutesApprox),
      ]);
      expect(find.byType(ExomFeatureBlock), findsNothing);
      expect(find.text(l10n.exercises.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.trainingDetailExercisesDone(0, 3)), findsOneWidget);
      // Three numbered figures plus one index per row.
      expect(find.byType(ExomIndexNumber), findsNWidgets(6));
      for (final id in const ['te-1', 'te-2', 'te-3']) {
        expect(find.byKey(Key('training-exercise-thumb-$id')), findsOneWidget);
      }
      expect(find.byType(GlassCard), findsNothing);
    });

    testWidgets('in progress: the progress is a figure in a featured block', (
      tester,
    ) async {
      await _mount(tester, completed: {'te-1'}, size: tall);
      final l10n = _l10n(tester);
      expect(find.byType(ExomFeatureBlock), findsOneWidget);
      expect(find.byType(ExomFigureColumns), findsNothing);
      final numeral = tester.widget<ExomNumeral>(find.byType(ExomNumeral));
      expect(numeral.value, '1');
      expect(numeral.unit, '/5');
      expect(
        find.text(l10n.trainingDetailSetsDoneOf(4, 16).toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(l10n.trainingDetailSetsDoneLabel), findsOneWidget);
      final rule = tester.widget<ExomProgressRule>(
        find.byType(ExomProgressRule),
      );
      expect(rule.segments, 5);
      expect(rule.value, closeTo(0.2, 1e-9));
      expect(find.text(l10n.trainingDetailExercisesDone(1, 5)), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('a done row marks «hecha» in the data colour, never as a '
          'system state (D19, ${brightness.name})', (tester) async {
        final theme = brightness == Brightness.dark
            ? AppTheme.dark
            : AppTheme.light;
        await _mount(tester, completed: {'te-1'}, theme: theme, size: tall);
        final palette = theme.extension<ExomThemePalette>()!;
        expect(tester.widget<Icon>(_rowCheck).color, palette.data);
      });
    }

    // CC 4: every golden scene of the batch (detalle, detalle_en_curso,
    // detalle_hecho) in both themes: no lime ink in light, contrast and
    // tap-target guidelines.
    const scenes = {
      'detalle': <String>{},
      'detalle_en_curso': {'te-1', 'te-2'},
      'detalle_hecho': {'te-1', 'te-2', 'te-3', 'te-4', 'te-5'},
    };
    for (final brightness in Brightness.values) {
      for (final scene in scenes.entries) {
        testWidgets('${scene.key} (${brightness.name}): no lime ink, contrast '
            'and tap targets', (tester) async {
          await _mount(
            tester,
            completed: scene.value,
            theme: brightness == Brightness.dark
                ? AppTheme.dark
                : AppTheme.light,
            size: tall,
          );
          expect(tester.takeException(), isNull);
          if (brightness == Brightness.light) expectNoLimeInk(tester);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectTapTargetGuidelines(tester);
        });
      }
    }

    // O1 (emulator pass): the API stores `order` 0-based and, with circuits,
    // multiplied by 1000. The index is the position of each top-level row
    // (exercise or circuit) as painted, never the raw `order`.
    testWidgets('rows are numbered by position, not by the raw order', (
      tester,
    ) async {
      TrainingExerciseEntity member(int order, String name, int position) =>
          TrainingExerciseEntity(
            id: 'te-$order',
            order: order,
            sets: 3,
            repsOrDuration: '10',
            restSeconds: 30,
            blockId: 'block-1',
            positionInBlock: position,
            blockName: 'Circuito final',
            blockRounds: 3,
            restBetweenRoundsSeconds: 45,
            exercise: ExerciseEntity(
              id: 'ex-$order',
              name: name,
              muscleGroups: const [],
            ),
          );
      await _mount(
        tester,
        size: tall,
        training: TrainingEntity(
          id: _trainingId,
          name: 'Mixto',
          types: const ['FUERZA'],
          level: 'INTERMEDIATE',
          tags: const [],
          exercises: [
            _exercise(0, 'Press de banca'),
            _exercise(1000, 'Remo'),
            _exercise(2000, 'Zancadas'),
            member(3000, 'Burpees', 0),
            member(4000, 'Comba', 1),
          ],
        ),
      );
      final rowIndexes = find.byWidgetPredicate(
        (widget) => widget is ExomIndexNumber,
      ).evaluate().where(
        (element) =>
            element.findAncestorWidgetOfExactType<ExomFigureColumns>() == null,
      ).map((element) => (element.widget as ExomIndexNumber).n);
      expect(rowIndexes.toList(), [1, 2, 3, 4]);
      for (final label in const ['01', '02', '03', '04']) {
        expect(find.text(label), findsWidgets);
      }
      for (final raw in const ['00', '1000', '2000', '3000', '4000']) {
        expect(find.text(raw), findsNothing);
      }
      // The order of the rows themselves is unchanged.
      final press = tester.getTopLeft(find.text('Press de banca')).dy;
      final remo = tester.getTopLeft(find.text('Remo')).dy;
      final zancadas = tester.getTopLeft(find.text('Zancadas')).dy;
      final circuit = tester.getTopLeft(find.text('Circuito final')).dy;
      expect(press < remo && remo < zancadas && zancadas < circuit, isTrue);
    });

    // O3 (emulator pass): switching the theme with the exercise sheet open
    // must repaint the sheet in the new theme, not keep the colour captured
    // when it was opened.
    testWidgets('the exercise sheet follows a theme change while open', (
      tester,
    ) async {
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      await _mount(tester, size: tall, themeMode: mode);
      await tester.tap(find.text('Sentadilla búlgara'));
      await tester.pumpAndSettle();
      final sheetMaterial = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Material),
          )
          .first;
      expect(
        tester.widget<Material>(sheetMaterial).color,
        AppTheme.light.extension<ExomThemePalette>()!.surface,
      );

      mode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        tester.widget<Material>(sheetMaterial).color,
        AppTheme.dark.extension<ExomThemePalette>()!.surface,
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });
}
