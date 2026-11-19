// Active exercise redesign (L3 unit 3): the page flow on top of the unchanged
// persistence (Hive draft on every transition), the sheet contract, the rest
// timer truth (persisted restEndsAt) with «+30 s» (D7), units (D5), prefill
// (D4), restore of drafts written by the pre-L3 app, exit confirmation and the
// mandatory last-set video at the same point of the flow.
import 'dart:convert';

import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/presentation/validated_session_gate.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/execution_timer.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/exom_component_harness.dart';
import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

const _trainingId = 'training-1';
const _date = '2026-11-18';
const _draftKey = 'te-1:$_date';

class _Store implements ActiveWorkoutLocalStore {
  final Map<String, ActiveWorkoutHiveModel> data = {};
  final writes = <ActiveWorkoutHiveModel>[];

  @override
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId) =>
      data[exerciseId];

  @override
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel workout) async {
    data[workout.exerciseId] = workout;
    writes.add(workout);
  }

  @override
  Future<void> removeActiveWorkout(String exerciseId) async {
    data.remove(exerciseId);
  }
}

class _Storage extends LocalStorage {
  _Storage(this.store, {this.unitSystem = UnitSystem.metric});
  final _Store store;
  final UnitSystem unitSystem;
  final settings = <String, Object?>{'last_set_video_reminder_enabled': false};

  @override
  String? get sessionStamp => 'owner:1:test';
  @override
  List<ActiveWorkoutHiveModel> getForeignActiveWorkouts(String trainingId) =>
      [];
  @override
  ActiveWorkoutLocalStore bindActiveWorkoutStore() => store;
  @override
  List<ActiveWorkoutHiveModel> getActiveWorkouts() =>
      store.data.values.toList();
  @override
  Future<void> removeActiveWorkout(String exerciseId) =>
      store.removeActiveWorkout(exerciseId);
  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = settings[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async =>
      settings[key] = value;
  @override
  bool getRestTimerSoundEnabled() => false;
  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => const Locale('es');
  @override
  UnitSystem getUnitSystemPreference() => unitSystem;
}

class _Native implements RestTimerCoordinator {
  @override
  RestTimerSession? activeSession;
  final starts = <RestTimerSession>[];
  int cancels = 0;
  int finishes = 0;

  @override
  Future<void> start(RestTimerSession session) async {
    activeSession = session;
    starts.add(session);
  }

  @override
  Future<void> finish() async {
    activeSession = null;
    finishes++;
  }

  @override
  Future<void> cancel() async {
    activeSession = null;
    cancels++;
  }
}

class _TrainingBloc extends Fake implements TrainingBloc {
  final events = <TrainingEvent>[];

  @override
  TrainingState get state => TrainingDetailLoaded(
    const TrainingEntity(
      id: _trainingId,
      name: 'Pierna fuerza',
      types: ['FUERZA'],
      level: 'INTERMEDIATE',
      tags: [],
      exercises: [_squat, _bulgarian],
    ),
    selectedDate: _date,
  );

  @override
  void add(TrainingEvent event) {
    events.add(event);
    if (event is MarkExerciseCompleted) event.completion?.complete();
  }
}

const _squat = TrainingExerciseEntity(
  id: 'te-0',
  order: 0,
  sets: 3,
  repsOrDuration: '5',
  restSeconds: 120,
  exercise: ExerciseEntity(id: 'ex-0', name: 'Sentadilla', muscleGroups: []),
);

const _bulgarian = TrainingExerciseEntity(
  id: 'te-1',
  order: 1,
  sets: 3,
  repsOrDuration: '8',
  measureType: ExerciseMeasureType.reps,
  targetValue: 8,
  targetRir: 2,
  restSeconds: 90,
  requestSetTracking: true,
  exercise: ExerciseEntity(
    id: 'ex-1',
    name: 'Sentadilla búlgara',
    muscleGroups: [],
    techniqueText: 'Pie trasero apoyado en el banco.',
  ),
);

class _Harness {
  _Harness(this.store, this.native, this.trainingBloc);
  final _Store store;
  final _Native native;
  final _TrainingBloc trainingBloc;

  ActiveWorkoutHiveModel? get draft => store.data[_draftKey];
}

Future<_Harness> _pumpPage(
  WidgetTester tester, {
  TrainingExerciseEntity exercise = _bulgarian,
  double? initialWeightKg,
  List<SetPerformance>? previous,
  List<SetPerformance>? current,
  bool requiresLastSetVideo = false,
  ActiveWorkoutHiveModel? seed,
  UnitSystem unitSystem = UnitSystem.metric,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  await sl.reset();
  final store = _Store();
  if (seed != null) store.data[seed.exerciseId] = seed;
  final storage = _Storage(store, unitSystem: unitSystem);
  final native = _Native();
  final trainingBloc = _TrainingBloc();
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<RestTimerCoordinator>(native);
  sl.registerSingleton<ExecutionTimerCoordinator>(ExecutionTimerCoordinator());
  sl.registerSingleton<ValidatedSessionGate>(ValidatedSessionGate(() => null));
  addTearDown(sl.reset);
  final preferences = AppPreferencesCubit(storage);
  addTearDown(preferences.close);

  final router = GoRouter(
    initialLocation: '/ex',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
        routes: [
          GoRoute(
            path: 'ex',
            builder: (_, _) => ActiveExercisePage(
              trainingId: _trainingId,
              exerciseId: exercise.id,
              args: ActiveExercisePageArgs(
                trainingBloc: trainingBloc,
                trainingExercise: exercise,
                trainingName: 'Pierna fuerza',
                trainingTypes: const ['FUERZA'],
                accentColorHex: null,
                trainingLevel: 'INTERMEDIATE',
                initialWeightKg: initialWeightKg,
                previousPerformances: previous,
                currentPerformances: current,
                requiresLastSetVideo: requiresLastSetVideo,
                assignmentDate: _date,
              ),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await loadRedesignFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>.value(
      value: preferences,
      child: MaterialApp.router(
        theme: themeFor(brightness),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
  return _Harness(store, native, trainingBloc);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ActiveExercisePage)));

ActiveExerciseState _state(WidgetTester tester) =>
    BlocProvider.of<ActiveExerciseBloc>(
      tester.element(find.byKey(const Key('active-exercise-close'))),
    ).state;

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('footer-executing')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _saveSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('set-sheet-save')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

/// Fixed frames instead of pumpAndSettle: the rest rule and the busy
/// primary button animate continuously by design.
Future<void> _settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  testWidgets('happy path: prefilled set in two taps, saved on this phone, '
      'rest, +30 s, skip, next set', (tester) async {
    final h = await _pumpPage(
      tester,
      initialWeightKg: 62.5,
      previous: const [
        SetPerformance(setNumber: 1, reps: 8, weightKg: 60, rir: 2),
      ],
    );
    final l10n = _l10n(tester);
    expect(find.text('SENTADILLA BÚLGARA'), findsOneWidget);
    expect(find.text(l10n.activeExercisePosition(2, 2)), findsOneWidget);
    expect(find.text('SERIE 1 DE 3'), findsOneWidget);
    expect(find.text('8'), findsWidgets);
    expect(find.text('Tu peso: 62,5 kg'), findsOneWidget);
    expect(find.text('Anterior: 8 × 60 kg · RIR 2'), findsOneWidget);
    expect(find.text(l10n.activeExerciseSetNow), findsOneWidget);

    await _openSheet(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('set-sheet-count-field')))
          .controller!
          .text,
      '8',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('set-sheet-weight-field')))
          .controller!
          .text,
      '62,5',
    );
    await _saveSheet(tester);

    // Persisted at the same point as before L3, kg and int as typed.
    final draft = h.draft!;
    expect(draft.completedSets, 1);
    expect(draft.lastWeightKg, 62.5);
    expect(draft.completedSetData, [
      {'set_number': 1, 'reps': 8, 'weight_kg': 62.5, 'rir': 2},
    ]);
    final state = _state(tester);
    expect(state.status, ActiveExerciseStatus.resting);
    final end = state.restEndsAt!;
    expect(draft.restEndsAt, end);
    expect(
      find.byKey(ValueKey('footer-resting-${end.millisecondsSinceEpoch}')),
      findsOneWidget,
    );
    expect(find.text('8 × 62,5'), findsOneWidget);
    expect(
      find.text(
        l10n.activeExerciseSetSavedStatus(1, l10n.syncStatusSavedOnDevice),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.syncStatusConfirmed), findsNothing);
    expect(
      find.text(l10n.activeExerciseRestNextWithWeight(2, '8 reps', '62,5 kg')),
      findsOneWidget,
    );
    expect(h.native.starts, hasLength(1));

    await tester.tap(find.byKey(const Key('active-exercise-rest-extend')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final extended = end.add(const Duration(seconds: 30));
    expect(_state(tester).restEndsAt, extended);
    expect(h.draft!.restEndsAt, extended);
    expect(
      find.byKey(ValueKey('footer-resting-${extended.millisecondsSinceEpoch}')),
      findsOneWidget,
    );
    expect(h.native.starts, hasLength(2));
    expect(h.native.starts.last.id, h.native.starts.first.id);
    expect(h.native.cancels, 0);

    await tester.tap(find.byKey(const Key('active-exercise-rest-skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_state(tester).status, ActiveExerciseStatus.executing);
    expect(find.byKey(const ValueKey('footer-executing')), findsOneWidget);
    expect(find.text('SERIE 2 DE 3'), findsOneWidget);
    expect(h.draft!.restEndsAt, isNull);
  });

  testWidgets('metric flow persists byte-identical values to the pre-L3 path '
      '(8 reps / 62.5 kg / RIR 2)', (tester) async {
    final h = await _pumpPage(tester);
    await _openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('set-sheet-weight-field')),
      '62,5',
    );
    await _saveSheet(tester);
    final viaSheet = h.draft!;

    // The pre-L3 sheet produced CompleteSet(reps: 8, weightKg: 62.5, rir: 2)
    // («62,5» -> double.tryParse('62.5')). Same event straight into the bloc.
    final oldStore = _Store();
    final bloc = ActiveExerciseBloc(
      localStorage: oldStore,
      trainingExercise: _bulgarian,
      restTimerCoordinator: _Native(),
    );
    addTearDown(bloc.close);
    bloc.add(
      const StartExercise(
        trainingId: _trainingId,
        exerciseId: 'te-1',
        assignmentDate: _date,
      ),
    );
    await tester.pump();
    bloc.add(
      CompleteSet(
        reps: 8,
        weightKg: double.tryParse('62,5'.replaceAll(',', '.')),
        rir: 2,
      ),
    );
    await tester.pump();
    final viaOldPath = oldStore.data[_draftKey]!;
    expect(
      jsonEncode(viaSheet.completedSetData),
      jsonEncode(viaOldPath.completedSetData),
    );
    expect(viaSheet.lastWeightKg, viaOldPath.lastWeightKg);
    expect(
      viaSheet.lastWeightKg.runtimeType,
      viaOldPath.lastWeightKg.runtimeType,
    );
    expect(viaSheet.completedSets, viaOldPath.completedSets);
    expect(viaSheet.currentSet, viaOldPath.currentSet);
  });

  testWidgets('a repeated tap on «Registrar serie» opens one sheet; Cancelar '
      'logs nothing', (tester) async {
    final h = await _pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('footer-executing')));
    await tester.tap(
      find.byKey(const ValueKey('footer-executing')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('set-sheet-save')), findsOneWidget);
    await tester.tap(find.byKey(const Key('set-sheet-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_state(tester).completedSets, 0);
    expect(h.draft!.completedSets, 0);
    expect(find.byKey(const ValueKey('footer-executing')), findsOneWidget);
    // The button is usable again once the sheet is disposed.
    await tester.pump();
    await _openSheet(tester);
    expect(find.byKey(const Key('set-sheet-save')), findsOneWidget);
  });

  testWidgets('optional tracking: «Completar sin registrar» completes the set '
      'without data, as before', (tester) async {
    final h = await _pumpPage(
      tester,
      exercise: const TrainingExerciseEntity(
        id: 'te-1',
        order: 1,
        sets: 2,
        repsOrDuration: '10',
        targetValue: 10,
        measureType: ExerciseMeasureType.reps,
        restSeconds: 0,
        exercise: ExerciseEntity(id: 'ex-1', name: 'Plancha', muscleGroups: []),
      ),
    );
    await _openSheet(tester);
    await tester.tap(find.byKey(const Key('set-sheet-skip-tracking')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(h.draft!.completedSets, 1);
    expect(h.draft!.completedSetData, isEmpty);
    expect(_state(tester).status, ActiveExerciseStatus.executing);
    final l10n = _l10n(tester);
    expect(find.text(l10n.activeExerciseSetDone), findsOneWidget);
  });

  testWidgets('imperial preference: shown in lb, persisted in kg', (
    tester,
  ) async {
    final h = await _pumpPage(
      tester,
      initialWeightKg: 62.5,
      unitSystem: UnitSystem.imperial,
    );
    expect(find.text('Tu peso: 137,79 lb'), findsOneWidget);
    await _openSheet(tester);
    final weight = find.byKey(const Key('set-sheet-weight-field'));
    expect(tester.widget<TextField>(weight).controller!.text, '137,79');
    await tester.enterText(weight, '135');
    await _saveSheet(tester);
    expect(h.draft!.completedSetData.single['weight_kg'], 61.235);
    expect(h.draft!.lastWeightKg, 61.235);
    expect(find.text('8 × 135'), findsOneWidget);
  });

  testWidgets('D4: without a session weight the previous session prefills', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      previous: const [
        SetPerformance(setNumber: 1, reps: 8, weightKg: 57.5),
        SetPerformance(setNumber: 2, reps: 8, weightKg: 60),
      ],
    );
    expect(find.text('Tu peso: 57,5 kg'), findsOneWidget);
  });

  testWidgets('no previous data: neutral copy, no «same as last time»', (
    tester,
  ) async {
    await _pumpPage(tester);
    final l10n = _l10n(tester);
    expect(find.text(l10n.activeExerciseNoPrevious), findsOneWidget);
    expect(find.byKey(const Key('active-exercise-your-weight')), findsNothing);
    await _openSheet(tester);
    expect(find.byKey(const Key('set-sheet-same-as-previous')), findsNothing);
  });

  testWidgets('timed exercise: hero in seconds, timer shown, seconds logged', (
    tester,
  ) async {
    final h = await _pumpPage(
      tester,
      exercise: const TrainingExerciseEntity(
        id: 'te-1',
        order: 1,
        sets: 2,
        repsOrDuration: '45s',
        measureType: ExerciseMeasureType.seconds,
        targetValue: 45,
        restSeconds: 0,
        requestSetTracking: true,
        exercise: ExerciseEntity(id: 'ex-1', name: 'Plancha', muscleGroups: []),
      ),
    );
    expect(find.text('45'), findsWidgets);
    expect(find.text('S'), findsOneWidget);
    expect(find.byType(ExecutionTimer), findsOneWidget);
    await _openSheet(tester);
    await _saveSheet(tester);
    expect(h.draft!.completedSetData.single, {'set_number': 1, 'seconds': 45});
  });

  testWidgets(
    'restores a draft written by the pre-L3 app (RIR-only set, RIR 8) '
    'and keeps its sets unchanged',
    (tester) async {
      final legacySets = [
        {'set_number': 1, 'rir': 2},
        {'set_number': 2, 'reps': 8, 'weight_kg': 60.0, 'rir': 8},
      ];
      final h = await _pumpPage(
        tester,
        exercise: const TrainingExerciseEntity(
          id: 'te-1',
          order: 1,
          sets: 4,
          repsOrDuration: '8',
          targetValue: 8,
          targetRir: 2,
          measureType: ExerciseMeasureType.reps,
          restSeconds: 90,
          exercise: ExerciseEntity(id: 'ex-1', name: 'Remo', muscleGroups: []),
        ),
        seed: ActiveWorkoutHiveModel(
          trainingId: _trainingId,
          exerciseId: _draftKey,
          currentSet: 3,
          completedSets: 2,
          lastWeightKg: 60.0,
          completedSetData: legacySets,
        ),
      );
      expect(find.text('SERIE 3 DE 4'), findsOneWidget);
      expect(find.text('RIR 2'), findsWidgets);
      expect(find.text('8 × 60'), findsOneWidget);
      expect(find.text('Tu peso: 60 kg'), findsOneWidget);

      await _openSheet(tester);
      await _saveSheet(tester);
      final saved = h.draft!;
      expect(saved.completedSets, 3);
      expect(saved.completedSetData.take(2).toList(), legacySets);
      expect(saved.completedSetData.last, {
        'set_number': 3,
        'reps': 8,
        'weight_kg': 60.0,
        'rir': 2,
      });
    },
  );

  testWidgets('restores a rest extended beyond the prescription', (
    tester,
  ) async {
    final end = DateTime.now().add(const Duration(seconds: 100));
    await _pumpPage(
      tester,
      seed: ActiveWorkoutHiveModel(
        trainingId: _trainingId,
        exerciseId: _draftKey,
        currentSet: 2,
        completedSets: 1,
        restEndsAt: end,
        completedSetData: const [
          {'set_number': 1, 'reps': 8, 'weight_kg': 60.0, 'rir': 2},
        ],
      ),
    );
    expect(_state(tester).restEndsAt, end);
    expect(find.text('1:40'), findsOneWidget);
    // Announced once when the rest appears; the countdown node itself is not
    // a live region (no announcement every second).
    final l10n = _l10n(tester);
    expect(
      tester.takeAnnouncements().map((a) => a.message),
      contains(l10n.activeExerciseRestRemainingA11y('1:40')),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeAnnouncements(), isEmpty);
    final countdown = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r'^Descanso, quedan')),
    );
    expect(countdown.flagsCollection.isLiveRegion, isFalse);
    expect(
      find.byKey(ValueKey('footer-resting-${end.millisecondsSinceEpoch}')),
      findsOneWidget,
    );
  });

  testWidgets('the rest footer still dispatches FinishRest at zero', (
    tester,
  ) async {
    final h = await _pumpPage(
      tester,
      seed: ActiveWorkoutHiveModel(
        trainingId: _trainingId,
        exerciseId: _draftKey,
        currentSet: 2,
        completedSets: 1,
        restEndsAt: DateTime.now().add(const Duration(milliseconds: 1500)),
      ),
    );
    expect(_state(tester).status, ActiveExerciseStatus.resting);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1600)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_state(tester).status, ActiveExerciseStatus.executing);
    expect(h.native.finishes, 1);
    expect(h.draft!.restEndsAt, isNull);
  });

  testWidgets('a tick of the outgoing footer after «+30 s» does not end the '
      'extended rest', (tester) async {
    final h = await _pumpPage(
      tester,
      seed: ActiveWorkoutHiveModel(
        trainingId: _trainingId,
        exerciseId: _draftKey,
        currentSet: 2,
        completedSets: 1,
        restEndsAt: DateTime.now().add(const Duration(milliseconds: 1500)),
      ),
    );
    final oldEnd = _state(tester).restEndsAt!;
    await tester.tap(find.byKey(const Key('active-exercise-rest-extend')));
    await tester.pump();
    // The old footer is still cross-fading out (220 ms) with its ticker.
    expect(
      find.byKey(ValueKey('footer-resting-${oldEnd.millisecondsSinceEpoch}')),
      findsOneWidget,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1600)),
    );
    // Fires the old ticker (past its end) before the switcher removes it.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_state(tester).status, ActiveExerciseStatus.resting);
    expect(_state(tester).restEndsAt, oldEnd.add(const Duration(seconds: 30)));
    expect(h.draft!.restEndsAt, oldEnd.add(const Duration(seconds: 30)));
    expect(h.native.finishes, 0);
  });

  testWidgets('leaving with logged sets asks first and abandons as before', (
    tester,
  ) async {
    final h = await _pumpPage(tester);
    await _openSheet(tester);
    await _saveSheet(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.byKey(const Key('active-exercise-close')));
    await _settleFrames(tester);
    expect(find.text(l10n.activeExerciseCloseTitle), findsOneWidget);
    await tester.tap(find.text(l10n.cancel));
    await _settleFrames(tester);
    expect(find.byType(ActiveExercisePage), findsOneWidget);
    expect(h.native.cancels, 0);

    await tester.tap(find.byKey(const Key('active-exercise-close')));
    await _settleFrames(tester);
    await tester.tap(find.text(l10n.continueButton));
    await _settleFrames(tester);
    expect(find.text('home'), findsOneWidget);
    // AbandonExercise: native rest cancelled, sets kept for later.
    expect(h.native.cancels, 1);
    expect(h.draft!.completedSets, 1);
  });

  testWidgets('the close button is 48x48 and labelled', (tester) async {
    await _pumpPage(tester);
    final l10n = _l10n(tester);
    final close = find.byKey(const Key('active-exercise-close'));
    final size = tester.getSize(close);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.byTooltip(l10n.activeExerciseCloseA11y), findsOneWidget);
  });

  testWidgets('last set with mandatory video: prepared after the sheet, at '
      'the same point, and the set is kept while the video is pending', (
    tester,
  ) async {
    final h = await _pumpPage(
      tester,
      requiresLastSetVideo: true,
      exercise: const TrainingExerciseEntity(
        id: 'te-1',
        order: 1,
        sets: 1,
        repsOrDuration: '8',
        targetValue: 8,
        measureType: ExerciseMeasureType.reps,
        restSeconds: 0,
        exercise: ExerciseEntity(id: 'ex-1', name: 'Remo', muscleGroups: []),
      ),
    );
    final l10n = _l10n(tester);
    // Bootstrap prompts for the video of the last set; dismiss it.
    await _settleFrames(tester);
    expect(find.text(l10n.recordNow), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await _settleFrames(tester);

    await _openSheet(tester);
    await _saveSheet(tester);
    await _settleFrames(tester);
    // The video source sheet opens after the set sheet is gone; no set yet.
    expect(find.byKey(const Key('set-sheet-save')), findsNothing);
    expect(find.text(l10n.recordNow), findsOneWidget);
    expect(h.draft!.completedSets, 0);
    await tester.tapAt(const Offset(10, 10));
    await _settleFrames(tester);
    expect(h.draft!.completedSets, 0);
    expect(h.trainingBloc.events, isEmpty);

    // Next tap reuses the pending set: the set sheet does not open again.
    await tester.tap(find.byKey(const ValueKey('footer-executing')));
    await _settleFrames(tester);
    expect(find.byKey(const Key('set-sheet-save')), findsNothing);
    expect(find.text(l10n.recordNow), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320 dp at 1.6x: executing, sheet and rest without overflow '
        '(${brightness.name})', (tester) async {
      await _pumpPage(
        tester,
        width: 320,
        height: 640,
        textScale: 1.6,
        brightness: brightness,
        initialWeightKg: 62.5,
        previous: const [
          SetPerformance(setNumber: 1, reps: 8, weightKg: 60, rir: 2),
        ],
      );
      expect(tester.takeException(), isNull);
      await expectTapTargetGuidelines(tester);
      expect(
        find.byKey(const ValueKey('footer-executing')).hitTestable(),
        findsOneWidget,
      );
      await _openSheet(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('set-sheet-save')).hitTestable(),
        findsOneWidget,
      );
      await _saveSheet(tester);
      expect(tester.takeException(), isNull);
      expect(_state(tester).isResting, isTrue);
      expect(
        find.byKey(const Key('active-exercise-rest-skip')).hitTestable(),
        findsOneWidget,
      );
      await expectTapTargetGuidelines(tester);
    });
  }

  testWidgets('«Ver técnica» opens a sheet with the texts', (tester) async {
    await _pumpPage(tester);
    await tester.tap(find.byKey(const Key('active-exercise-technique')));
    await tester.pumpAndSettle();
    expect(find.text('Pie trasero apoyado en el banco.'), findsOneWidget);
  });
}
