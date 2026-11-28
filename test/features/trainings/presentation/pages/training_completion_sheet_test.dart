// L5-E2b «Hoja de cierre (RPE y nota)» (docs/plans/rediseno-app-l5-contrato-v2.md,
// bloque E, and plan decision L5-D22): the confirmation that asks for the RPE
// and the note before completing the session is a straight EXOM sheet
// (`showExomSheet`) instead of an `AlertDialog`. Same order and same payload as
// before: `CompleteTrainingRequested(rpe, notes)` with the trimmed note (or
// null when blank), the same completion draft read and written through
// `LocalStorage`, and nothing sent on cancel, tap outside, back, drag or a
// router location change (CC 11).
import 'dart:async';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_scale_chips.dart';
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
import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../../core/widgets/exom_component_harness.dart'
    show expectTapTargetGuidelines;
import '../../../../core/widgets/expect_no_lime_ink.dart';

const _date = '2026-09-05';
const _execution = 'execution-1';
const _trainingId = 'training-1';
const _owner = 'owner:1:test';

final _training = TrainingEntity(
  id: _trainingId,
  name: 'Pierna fuerza',
  types: const ['FUERZA'],
  level: 'INTERMEDIATE',
  tags: const [],
  exercises: const [
    TrainingExerciseEntity(
      id: 'te-1',
      order: 1,
      sets: 3,
      repsOrDuration: '8',
      restSeconds: 90,
      exercise: ExerciseEntity(
        id: 'ex-1',
        name: 'Sentadilla búlgara',
        muscleGroups: [],
      ),
    ),
  ],
);

/// One call to `saveTrainingCompletionDraft`, with the raw arguments.
typedef _DraftSave = ({int? rpe, String? notes});

/// One `completeTraining` call that reached the repository.
typedef _Completion = ({String? sessionId, int? rpe, String? notes});

class _Storage extends LocalStorage {
  String? stamp = _owner;

  /// Stored drafts, kept like `LocalStorage.saveTrainingCompletionDraft`
  /// (rpe if any, notes trimmed and only when not blank).
  final Map<String, Map<String, dynamic>> completionDrafts = {};
  final List<_DraftSave> draftSaves = [];

  /// While set, every draft write waits for it (slow disk).
  Completer<void>? saveGate;

  @override
  String? get sessionStamp => stamp;
  @override
  bool get hasQuarantinedWorkoutDrafts => false;
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => const [];
  @override
  List<Map<String, dynamic>> getTrainingExecutions(
    String trainingId,
    String date,
  ) => const [];
  @override
  List<Map<String, dynamic>> getConfirmedTrainingExecutions(
    String trainingId,
    String date,
  ) => const [];
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
  ) {
    final draft = completionDrafts[executionId];
    return draft == null ? null : Map<String, dynamic>.from(draft);
  }

  @override
  Future<void> saveTrainingCompletionDraft(
    String trainingId,
    String date,
    String executionId, {
    int? rpe,
    String? notes,
  }) async {
    final gate = saveGate;
    if (gate != null) await gate.future;
    draftSaves.add((rpe: rpe, notes: notes));
    completionDrafts[executionId] = {
      'training_id': trainingId,
      'assignment_date': date,
      'rpe': ?rpe,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
  }

  @override
  List<Map<String, dynamic>> getFeedbackUploadQueue() => const [];
  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) => null;
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
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
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
  _Repository({required this.completedIds});

  /// Exercises already completed in the session (none: one is pending).
  final Set<String> completedIds;
  final List<_Completion> completions = [];

  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      _training;
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) async =>
      TrainingDayProgress(
        sessions: {
          _execution: TrainingDayProgress(ids: completedIds),
        },
        sessionTrainings: {_execution: _trainingId},
      );
  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> exerciseIds,
    String beforeDate,
  ) async => const {};
  @override
  Future<void> completeTraining(
    String date, {
    required String trainingId,
    String? sessionId,
    int? rpe,
    String? notes,
  }) async {
    completions.add((sessionId: sessionId, rpe: rpe, notes: notes));
  }
}

class _Harness {
  _Harness(this.storage, this.repository, this.router);
  final _Storage storage;
  final _Repository repository;
  final GoRouter router;
}

Future<_Harness> _mount(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('es'),
  bool pending = false,
  void Function(_Storage storage)? seed,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final storage = _Storage();
  seed?.call(storage);
  final repository = _Repository(
    completedIds: pending ? const {} : const {'te-1'},
  );
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<OfflineSyncService>(_Sync(storage));
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
        path: '/other',
        builder: (_, _) => const Scaffold(body: Text('other-route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>.value(
      value: preferences,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });
  return _Harness(storage, repository, router);
}

final _completeButton = find.byKey(const Key('complete-training-button'));
final _sheet = find.byKey(const Key('complete-training-confirmation'));
final _confirm = find.byKey(const Key('confirm-complete-training'));
final _cancel = find.byKey(const Key('cancel-complete-training'));
final _note = find.byKey(const Key('completion-note'));
final _selectedMarker = find.byKey(const Key('completion-rpe-selected'));
Finder _rpe(int value) => find.byKey(Key('completion-rpe-$value'));

Future<void> _open(WidgetTester tester) async {
  await tester.ensureVisible(_completeButton);
  await tester.pumpAndSettle();
  await tester.tap(_completeButton);
  await tester.pumpAndSettle();
  expect(_sheet, findsOneWidget);
}

Future<void> _tapIn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// Whether the confirm action can be tapped (enabled and not busy).
bool _confirmEnabled(WidgetTester tester) {
  final button = tester.widget<ExomPrimaryButton>(_confirm);
  return button.onPressed != null && !button.busy;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(TrainingDetailPage)));

/// The one-exercise session with the closing sheet open (no RPE chosen),
/// finished or, with [pending], with its exercise still pending (the sheet
/// then warns it will be marked as completed), for the goldens (`test/golden/l5_e2b_hoja_cierre_golden_test.dart`)
/// and the overflow sweep (`test/l10n/long_string_overflow_test.dart`).
Future<void> pumpCompletionSheet(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('es'),
  bool pending = false,
}) async {
  await _mount(
    tester,
    brightness: brightness,
    size: size,
    textScaler: textScaler,
    locale: locale,
    pending: pending,
  );
  await _open(tester);
}

void main() {
  group('opens as a straight sheet', () {
    testWidgets('is an EXOM sheet, not an AlertDialog, with the same keys', (
      tester,
    ) async {
      await _mount(tester);
      await _open(tester);
      final l10n = _l10n(tester);

      expect(find.byType(AlertDialog), findsNothing);
      final panel = find.byKey(const Key('exom-sheet-panel'));
      expect(panel, findsOneWidget);
      expect(find.byKey(const Key('exom-sheet-handle')), findsOneWidget);
      expect(find.descendant(of: panel, matching: _sheet), findsOneWidget);
      for (var value = 1; value <= 10; value++) {
        expect(
          find.descendant(of: panel, matching: _rpe(value)),
          findsOneWidget,
        );
      }
      expect(find.byType(ExomScaleChips), findsOneWidget);
      expect(find.descendant(of: panel, matching: _note), findsOneWidget);
      expect(find.descendant(of: panel, matching: _confirm), findsOneWidget);
      expect(find.descendant(of: panel, matching: _cancel), findsOneWidget);

      // Sketch `f-fin-hoja` (copy approved in L5-D43): the session name as
      // kicker, «Terminar sesión», the RPE question and its explanation, the
      // note label, and «Terminar sesión» disabled until an RPE is chosen.
      Finder inSheet(String text) =>
          find.descendant(of: panel, matching: find.text(text));
      expect(inSheet(_training.name.toUpperCase()), findsOneWidget);
      // Title and action (both painted upper case).
      expect(inSheet('TERMINAR SESIÓN'), findsNWidgets(2));
      expect(inSheet('¿Cuánto te ha costado? (RPE)'), findsOneWidget);
      expect(inSheet(l10n.completeTrainingRpeExplanation), findsOneWidget);
      expect(inSheet(l10n.addQuickNoteOptional), findsOneWidget);
      expect(inSheet(l10n.cancel), findsOneWidget);
      expect(_selectedMarker, findsNothing);
      expect(tester.widget<ExomPrimaryButton>(_confirm).onPressed, isNull);
    });

    // Owner decision (2026-11-25): confirming marks every pending exercise as
    // completed (the bloc sets `completedExerciseIds` to all of them and the
    // API does the same), so the sheet says so, only when one is pending.
    testWidgets('with pending exercises it warns they will be completed', (
      tester,
    ) async {
      await _mount(tester, pending: true);
      await _open(tester);
      final l10n = _l10n(tester);
      final notice = find.byKey(const Key('completion-pending-notice'));
      expect(
        find.descendant(
          of: find.byKey(const Key('exom-sheet-panel')),
          matching: notice,
        ),
        findsOneWidget,
      );
      expect(tester.widget<Text>(notice).data, l10n.completeTrainingConfirmMessage);
    });

    testWidgets('without pending exercises there is no warning', (
      tester,
    ) async {
      await _mount(tester);
      await _open(tester);
      final l10n = _l10n(tester);
      expect(find.byKey(const Key('completion-pending-notice')), findsNothing);
      expect(find.text(l10n.completeTrainingConfirmMessage), findsNothing);
    });

    testWidgets('a double tap on «Completar todo» opens one sheet', (
      tester,
    ) async {
      await _mount(tester);
      await tester.ensureVisible(_completeButton);
      await tester.pumpAndSettle();
      await tester.tap(_completeButton);
      await tester.tap(_completeButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(find.byKey(const Key('exom-sheet-panel')), findsOneWidget);
    });
  });

  group('same payload as before', () {
    // (description, seeded draft, quick note typed on the page, taps, note
    // typed in the sheet or null to leave it, expected rpe, expected notes).
    final cases =
        <
          (
            String,
            Map<String, dynamic>?,
            String?,
            List<int>,
            String?,
            int,
            String?,
          )
        >[
          ('note trimmed', null, null, [7], '  Piernas cargadas  ', 7, 'Piernas cargadas'),
          ('blank note is null', null, null, [10], '   ', 10, null),
          ('untouched note is null', null, null, [1], null, 1, null),
          ('draft rpe and note', {'rpe': 4, 'notes': 'del borrador'}, null, [], null, 4, 'del borrador'),
          ('page quick note prefills', null, 'nota de la página', [6], null, 6, 'nota de la página'),
          ('draft note wins over page note', {'notes': 'borrador'}, 'página', [2], null, 2, 'borrador'),
          ('draft rpe only keeps page note', {'rpe': 2}, 'página', [], null, 2, 'página'),
          ('tap again deselects, then another value', null, null, [8, 8, 3], null, 3, null),
          ('multiline note', null, null, [5], 'línea 1\nlínea 2 ', 5, 'línea 1\nlínea 2'),
        ];
    for (final (name, draft, pageNote, taps, typed, rpe, notes) in cases) {
      testWidgets(name, (tester) async {
        final harness = await _mount(
          tester,
          seed: (storage) {
            if (draft != null) {
              storage.completionDrafts[_execution] = {
                'training_id': _trainingId,
                'assignment_date': _date,
                ...draft,
              };
            }
          },
        );
        if (pageNote != null) {
          final field = find.byType(TextField).last;
          await tester.ensureVisible(field);
          await tester.enterText(field, pageNote);
          await tester.pump();
        }
        await _open(tester);
        for (final value in taps) {
          await _tapIn(tester, _rpe(value));
        }
        if (typed != null) {
          await tester.ensureVisible(_note);
          await tester.enterText(_note, typed);
          await tester.pump();
        }
        expect(_selectedMarker, findsOneWidget);
        await _tapIn(tester, _confirm);
        await tester.pumpAndSettle();

        expect(_sheet, findsNothing);
        expect(harness.repository.completions, [
          (sessionId: _execution, rpe: rpe, notes: notes),
        ]);
        // The draft written before completing holds the same values.
        expect(harness.storage.completionDrafts[_execution]?['rpe'], rpe);
        expect(harness.storage.completionDrafts[_execution]?['notes'], notes);
      });
    }

    testWidgets('without an RPE nothing can be sent', (tester) async {
      final harness = await _mount(tester);
      await _open(tester);
      await tester.enterText(_note, 'solo nota');
      await tester.pump();
      expect(_confirmEnabled(tester), isFalse);
      await tester.tap(_confirm, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      // Deselecting the only value disables it again.
      await _tapIn(tester, _rpe(9));
      expect(_confirmEnabled(tester), isTrue);
      await _tapIn(tester, _rpe(9));
      expect(_selectedMarker, findsNothing);
      expect(_confirmEnabled(tester), isFalse);
      expect(harness.repository.completions, isEmpty);
    });
  });

  group('draft', () {
    testWidgets('every change is written with the raw values', (tester) async {
      final harness = await _mount(tester);
      await _open(tester);
      await _tapIn(tester, _rpe(5));
      await tester.enterText(_note, ' hola ');
      await tester.pumpAndSettle();
      expect(harness.storage.draftSaves.last, (rpe: 5, notes: ' hola '));
      await _tapIn(tester, _rpe(5));
      await tester.pumpAndSettle();
      expect(harness.storage.draftSaves.last, (rpe: null, notes: ' hola '));
      expect(harness.repository.completions, isEmpty);
    });

    testWidgets('cancel keeps the draft and reopening restores it', (
      tester,
    ) async {
      final harness = await _mount(tester);
      await _open(tester);
      await _tapIn(tester, _rpe(6));
      await tester.enterText(_note, 'guardada');
      await tester.pump();
      await _tapIn(tester, _cancel);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(harness.repository.completions, isEmpty);
      expect(harness.storage.completionDrafts[_execution], {
        'training_id': _trainingId,
        'assignment_date': _date,
        'rpe': 6,
        'notes': 'guardada',
      });

      await _open(tester);
      expect(_selectedMarker, findsOneWidget);
      expect(tester.widget<ExomScaleChips>(find.byType(ExomScaleChips)).selected, 6);
      expect(tester.widget<TextField>(_note).controller?.text, 'guardada');
    });

    testWidgets('a draft that cannot be saved keeps the sheet open', (
      tester,
    ) async {
      final harness = await _mount(tester);
      await _open(tester);
      await _tapIn(tester, _rpe(8));
      await tester.pumpAndSettle();
      harness.storage.stamp = 'another-owner:2:test';
      await _tapIn(tester, _confirm);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(_confirmEnabled(tester), isTrue);
      await _tapIn(tester, _cancel);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(harness.repository.completions, isEmpty);
    });
  });

  group('closing without sending', () {
    testWidgets('cancel', (tester) async {
      final harness = await _mount(tester);
      await _open(tester);
      await _tapIn(tester, _rpe(7));
      await _tapIn(tester, _cancel);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(find.byType(TrainingDetailPage), findsOneWidget);
      expect(harness.repository.completions, isEmpty);
    });

    testWidgets('tap outside', (tester) async {
      final harness = await _mount(tester);
      await _open(tester);
      await _tapIn(tester, _rpe(7));
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(find.byType(TrainingDetailPage), findsOneWidget);
      expect(harness.repository.completions, isEmpty);
      expect(harness.storage.completionDrafts[_execution]?['rpe'], 7);
    });

    testWidgets('system back', (tester) async {
      final harness = await _mount(tester);
      await _open(tester);
      await _tapIn(tester, _rpe(7));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(find.byType(TrainingDetailPage), findsOneWidget);
      expect(harness.repository.completions, isEmpty);
    });

    testWidgets('dragging the sheet down', (tester) async {
      final harness = await _mount(tester);
      await _open(tester);
      await _tapIn(tester, _rpe(7));
      await tester.fling(
        find.byKey(const Key('exom-sheet-handle')),
        const Offset(0, 500),
        2000,
      );
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(harness.repository.completions, isEmpty);
    });

    testWidgets('a router location change closes it without a result (CC 11)', (
      tester,
    ) async {
      final harness = await _mount(tester);
      await _open(tester);
      await _tapIn(tester, _rpe(8));
      await tester.pumpAndSettle();
      unawaited(harness.router.push('/other'));
      await tester.pumpAndSettle();
      expect(find.text('other-route'), findsOneWidget);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(TrainingDetailPage), findsOneWidget);
      expect(_sheet, findsNothing);
      expect(harness.repository.completions, isEmpty);
      // The draft survives and the sheet opens again with it.
      await _open(tester);
      expect(tester.widget<ExomScaleChips>(find.byType(ExomScaleChips)).selected, 8);
    });

    testWidgets('a router change while confirming sends nothing', (
      tester,
    ) async {
      final harness = await _mount(tester);
      await _open(tester);
      await _tapIn(tester, _rpe(8));
      await tester.pumpAndSettle();
      final gate = harness.storage.saveGate = Completer<void>();
      await _tapIn(tester, _confirm);
      unawaited(harness.router.push('/other'));
      // Release the write halfway through the exit, while the sheet is still
      // mounted but no longer the current route: it must not pop the route
      // pushed on top (a `context.mounted` check alone would).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_sheet, findsOneWidget);
      gate.complete();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('other-route'), findsOneWidget);
      expect(harness.router.state.matchedLocation, '/other');
      expect(harness.repository.completions, isEmpty);
    });

    testWidgets('a write that ends under another route frees the actions', (
      tester,
    ) async {
      // Something opened above the sheet in the same navigator: the sheet stays
      // open but is not the current route, so it is not popped; its actions
      // must not stay busy.
      final harness = await _mount(tester);
      await _open(tester);
      await _tapIn(tester, _rpe(8));
      await tester.pumpAndSettle();
      final gate = harness.storage.saveGate = Completer<void>();
      await _tapIn(tester, _confirm);
      final navigator = Navigator.of(tester.element(_sheet));
      unawaited(navigator.push(PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, _, _) => const SizedBox(key: Key('over-sheet')),
      )));
      // The busy action animates, so step the clock instead of settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('over-sheet')), findsOneWidget);
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_sheet, findsOneWidget);
      expect(_confirmEnabled(tester), isTrue);
      expect(tester.widget<ExomQuietButton>(_cancel).onPressed, isNotNull);
      expect(harness.repository.completions, isEmpty);
      // The sheet still works: confirming now sends once.
      await _tapIn(tester, _confirm);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(harness.repository.completions, [
        (sessionId: _execution, rpe: 8, notes: null),
      ]);
    });
  });

  testWidgets('a double tap on «Terminar sesión» sends once', (tester) async {
    final harness = await _mount(tester);
    await _open(tester);
    await _tapIn(tester, _rpe(9));
    await tester.pumpAndSettle();
    final gate = harness.storage.saveGate = Completer<void>();
    await tester.tap(_confirm);
    await tester.pump();
    await tester.tap(_confirm, warnIfMissed: false);
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(harness.repository.completions, [
      (sessionId: _execution, rpe: 9, notes: null),
    ]);
  });

  group('CC 4', () {
    for (final brightness in Brightness.values) {
      testWidgets('contrast, tap targets and lime ink, ${brightness.name}', (
        tester,
      ) async {
        await _mount(tester, brightness: brightness);
        await _open(tester);
        for (final selected in [false, true]) {
          if (selected) await _tapIn(tester, _rpe(4));
          await tester.pumpAndSettle();
          // Without an RPE «Terminar sesión» is inactive (WCAG 1.4.3 exempts
          // it); the shared button paints it 4.25:1 in the dark theme
          // (L5-C4-D1, as in C5a).
          if (selected || brightness == Brightness.light) {
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }
          await expectTapTargetGuidelines(tester);
          if (brightness == Brightness.light) {
            expectNoLimeInk(
              tester,
              root: find.byKey(const Key('exom-sheet-panel')),
              brightness: brightness,
            );
          }
        }
      });
    }
  });

  testWidgets('at 2.0x every part of the sheet is reachable by scrolling', (
    tester,
  ) async {
    final harness = await _mount(
      tester,
      size: const Size(360, 640),
      textScaler: const TextScaler.linear(2.0),
    );
    await _open(tester);
    expect(tester.takeException(), isNull);
    for (final finder in [_rpe(1), _rpe(10), _note, _confirm, _cancel]) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder.hitTestable(), findsOneWidget);
    }
    await _tapIn(tester, _rpe(10));
    await _tapIn(tester, _confirm);
    await tester.pumpAndSettle();
    expect(harness.repository.completions.single.rpe, 10);
    expect(tester.takeException(), isNull);
  });

  // S11-09 (matriz L6): a rapid double tap on the detail's «Terminar sesión»
  // (opens the closing sheet) and on the sheet's «Terminar sesión» sends a
  // single completion and never stacks a second sheet, whether both taps
  // land in the same frame or ~50 ms apart. A deliberate tap after the
  // 640 ms window still works.
  group('S11-09 double tap', () {
    final panel = find.byKey(const Key('exom-sheet-panel'));

    Future<void> doubleTap(
      WidgetTester tester,
      Finder finder,
      Duration? gap,
    ) async {
      await tester.tap(finder);
      if (gap != null) await tester.pump(gap);
      await tester.tap(finder, warnIfMissed: false);
    }

    for (final (label, gap) in [
      ('same frame', null),
      ('50 ms apart', const Duration(milliseconds: 50)),
    ]) {
      testWidgets('footer «Terminar sesión», $label: one sheet', (
        tester,
      ) async {
        final harness = await _mount(tester);
        await tester.ensureVisible(_completeButton);
        await tester.pumpAndSettle();
        await doubleTap(tester, _completeButton, gap);
        await tester.pumpAndSettle();
        expect(_sheet, findsOneWidget);
        expect(panel, findsOneWidget);
        expect(harness.repository.completions, isEmpty);
      });

      testWidgets('sheet «Terminar sesión», $label: one completion', (
        tester,
      ) async {
        final harness = await _mount(tester);
        await _open(tester);
        await _tapIn(tester, _rpe(7));
        await tester.pumpAndSettle();
        await doubleTap(tester, _confirm, gap);
        await tester.pumpAndSettle();
        expect(_sheet, findsNothing);
        expect(panel, findsNothing);
        expect(harness.repository.completions, [
          (sessionId: _execution, rpe: 7, notes: null),
        ]);
      });
    }

    testWidgets('after the 640 ms window a deliberate tap opens it again', (
      tester,
    ) async {
      final harness = await _mount(tester);
      await tester.ensureVisible(_completeButton);
      await tester.pumpAndSettle();
      await doubleTap(tester, _completeButton, null);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      await tester.tap(_cancel);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);

      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(_completeButton);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(panel, findsOneWidget);
      await _tapIn(tester, _rpe(5));
      await tester.pumpAndSettle();
      await tester.tap(_confirm);
      await tester.pumpAndSettle();
      expect(harness.repository.completions, [
        (sessionId: _execution, rpe: 5, notes: null),
      ]);
    });
  });
}
