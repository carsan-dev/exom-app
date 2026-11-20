// L5-A3 «Entrenar: lista e historial» (docs/plans/rediseno-app-l5-contrato-v2.md,
// L5-A3 and §3.0): rich rows with a date, the «Continuar sesión» footer only
// with a continuable local session, flat empty / error / loading states, the
// D19 colours and the common criteria CC 3 and CC 4 on the main, today and
// empty scenes; after review, the footer's shared busy state (I1) and the
// sketch elements built from data the page already has (L5-D36). The local
// pending sessions are only read; their origin, order, identity and actions
// are covered by trainings_page_test.dart and
// pending_training_executions_test.dart.
import 'dart:async';

import 'package:exom_app/core/models/training_execution_discard.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_arrival.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_moment_pill.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/home/presentation/widgets/home_session_photo.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/trainings_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/exom_component_harness.dart';
import '../../../../core/widgets/exom_text_component_matrix.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import 'trainings_redesign_fixture.dart';

const _footerKey = Key('pending-footer-continue');
const _todayKey = Key('training-today-training-legs');
const _sceneExecution = '8f3c2a71-5d94-4be0-a6c1-0e7b92d4f358';
const _sceneRoute =
    '/trainings/training-legs?date=2026-10-13&execution=$_sceneExecution';

/// Local discard service double: an eligible inspection and a discard that
/// waits on [result] (the real one waits for the sync and queue locks).
class _DiscardSync extends Fake implements OfflineSyncService {
  final result = Completer<TrainingExecutionDiscardResult>();
  final requests = <TrainingExecutionDiscardRequest>[];

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  TrainingExecutionDiscardResult inspectTrainingExecutionDiscard(
    TrainingExecutionDiscardRequest request,
  ) => const TrainingExecutionDiscardResult(
    TrainingExecutionDiscardReason.eligible,
  );

  @override
  Future<TrainingExecutionDiscardResult> discardTrainingExecution(
    TrainingExecutionDiscardRequest request,
  ) {
    requests.add(request);
    return result.future;
  }
}

/// Taps «Descartar» on the scene's pending session and confirms the dialog;
/// the discard then waits on the service.
Future<void> _confirmDiscard(WidgetTester tester) async {
  final discard = find.byKey(const Key('pending-discard-$_sceneExecution'));
  await tester.ensureVisible(discard);
  await tester.pumpAndSettle();
  await tester.tap(discard);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pending-discard-confirm')));
  await tester.pumpAndSettle();
}

ExomPrimaryButton _footer(WidgetTester tester) =>
    tester.widget<ExomPrimaryButton>(find.byKey(_footerKey));

/// Opacity of the M3 arrival fade of the day/history content.
double _arrivalOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(ExomArrival),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

TrainingEntity _trainingWith({
  String id = 'training-legs',
  String name = 'Pierna · Fuerza',
  List<String?> thumbnails = const [],
}) => TrainingEntity(
  id: id,
  name: name,
  types: kSceneTraining.types,
  level: kSceneTraining.level,
  estimatedDurationMin: kSceneTraining.estimatedDurationMin,
  tags: const [],
  exercises: [
    for (final (i, item) in kSceneTraining.exercises.indexed)
      TrainingExerciseEntity(
        id: item.id,
        order: item.order,
        sets: item.sets,
        repsOrDuration: item.repsOrDuration,
        restSeconds: item.restSeconds,
        exercise: ExerciseEntity(
          id: item.exercise.id,
          name: item.exercise.name,
          muscleGroups: const [],
          thumbnailUrl: i < thumbnails.length ? thumbnails[i] : null,
        ),
      ),
  ],
);

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(TrainingsPage)));

/// Colour of the first painted span of the Text that shows exactly [text].
Color? _inkOf(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find
        .descendant(of: find.text(text).first, matching: find.byType(RichText))
        .first,
  );
  final span = paragraph.text as TextSpan;
  return span.style?.color ?? span.children?.first.style?.color;
}

/// Scrollable of the day/history list (not the pending block or the footer).
Finder get _mainList => find
    .descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  group('rows', () {
    testWidgets('history and the pending session are rich rows with a date '
        '(today is the featured session block, L5-D36)', (tester) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        storage: SceneStorage(scenePending()),
      );
      final rows = tester.widgetList<ExomRichRow>(find.byType(ExomRichRow));
      // 1 pending + 3 history; the only training of the day is the featured
      // block (photo, title, figures), covered in «today session».
      expect(rows, hasLength(4));
      expect(find.byKey(_todayKey), findsOneWidget);
      for (final row in rows) {
        expect(row.leading, isA<ExomRowDate>(), reason: row.title);
      }
      final history = rows.firstWhere((row) => row.title == 'Torso · Empuje');
      expect((history.leading as ExomRowDate).day, '12');
      expect(history.facts, contains('51 min'));
      expect(history.onTap, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the technical session ID never shows on the page (D14-6)', (
      tester,
    ) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        storage: SceneStorage(scenePending()),
      );
      expect(find.textContaining('8f3c2a71'), findsNothing);
      expect(
        find.byKey(
          const Key('pending-continue-8f3c2a71-5d94-4be0-a6c1-0e7b92d4f358'),
        ),
        findsOneWidget,
      );
    });

    for (final brightness in Brightness.values) {
      testWidgets('D19: done history row in the data colour with a check, '
          'pending in amber (${brightness.name})', (tester) async {
        await pumpTrainingsScene(
          tester,
          state: sceneLoaded(),
          brightness: brightness,
        );
        final l10n = _l10n(tester);
        final context = tester.element(find.byType(TrainingsPage));
        final palette = context.exomPalette;
        // The sketch's «Hecha» (new key); `completed` keeps its other uses.
        final done = find.text(l10n.trainingsHistoryDone);
        expect(done, findsNWidgets(2));
        expect(find.text(l10n.completed), findsNothing);
        expect(_inkOf(tester, l10n.trainingsHistoryDone), palette.data);
        final check = tester.widget<Icon>(
          find.descendant(
            of: find.ancestor(of: done.first, matching: find.byType(Row)).first,
            matching: find.byIcon(Icons.check),
          ),
        );
        expect(check.color, palette.data);
        final pending = tester.widget<ExomSyncStatus>(
          find.byType(ExomSyncStatus),
        );
        expect(pending.state, ExomSyncState.pendiente);
        expect(pending.label, l10n.pending);
      });
    }
  });

  group('«Continuar sesión» footer', () {
    testWidgets('continues the first continuable local session', (
      tester,
    ) async {
      final storage = SceneStorage([
        {
          'id': 'sync-1',
          'training_id': 'sync',
          'training_name': 'Recovery',
          'assignment_date': '2026-10-01',
          'status': 'pending-sync',
        },
        ...scenePending(),
        {
          'id': 'later',
          'training_id': 'other',
          'training_name': 'Mobility',
          'assignment_date': '2026-10-02',
          'status': 'pending-finalize',
        },
      ]);
      await pumpTrainingsScene(tester, state: sceneLoaded(), storage: storage);
      final l10n = _l10n(tester);
      expect(find.byType(ExomPinnedFooter), findsOneWidget);
      // The primary button paints its label in upper case.
      expect(
        find.text(l10n.trainingsContinueSessionButton.toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_footerKey));
      await tester.pumpAndSettle();
      expect(openedRoutes, [
        '/trainings/training-legs?date=2026-10-13'
            '&execution=8f3c2a71-5d94-4be0-a6c1-0e7b92d4f358',
      ]);
    });

    testWidgets('a stale session generation does not navigate', (tester) async {
      final storage = SceneStorage(scenePending());
      await pumpTrainingsScene(tester, state: sceneLoaded(), storage: storage);
      storage.stamp = 'owner-B:2';
      await tester.tap(find.byKey(_footerKey));
      await tester.pumpAndSettle();
      expect(openedRoutes, isEmpty);
    });

    testWidgets('absent without a continuable session', (tester) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        storage: SceneStorage([
          {
            'id': 'sync-1',
            'training_id': 'sync',
            'training_name': 'Recovery',
            'assignment_date': '2026-10-01',
            'status': 'pending-sync',
          },
          {
            'id': 'conflict-1',
            'training_id': 'sync',
            'training_name': 'Recovery',
            'assignment_date': '2026-10-02',
            'status': 'conflict',
          },
        ]),
      );
      expect(find.byKey(_footerKey), findsNothing);
      expect(find.byType(ExomPinnedFooter), findsNothing);
    });

    testWidgets('absent with no local session', (tester) async {
      await pumpTrainingsScene(tester, state: sceneLoaded());
      expect(find.byKey(_footerKey), findsNothing);
      expect(find.byType(ExomPinnedFooter), findsNothing);
    });
  });

  group('states', () {
    testWidgets('no plan is a flat empty state', (tester) async {
      await pumpTrainingsScene(
        tester,
        state: const TrainingNoContent(selectedDate: kSceneDate),
      );
      final l10n = _l10n(tester);
      final empty = tester.widget<ExomEmptyState>(find.byType(ExomEmptyState));
      expect(
        (empty.first, empty.second),
        (l10n.trainingsNoPlanFirst, l10n.trainingsNoPlanSecond),
      );
      expect(empty.body, l10n.noTrainingsAssignedSubtitle);
      // The sketch's two lines under the headline: the cause in strong text
      // (the previous «No tienes entrenamientos asignados») and the detail.
      expect(find.text(l10n.noTrainingsAssigned), findsOneWidget);
      expect(find.text(l10n.noTrainingsAssignedSubtitle), findsOneWidget);
      final lead = tester.widget<Text>(find.text(l10n.noTrainingsAssigned));
      expect(lead.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('no training that day is a flat empty state', (tester) async {
      await pumpTrainingsScene(tester, state: sceneLoaded(today: const []));
      final l10n = _l10n(tester);
      final empty = tester.widget<ExomEmptyState>(find.byType(ExomEmptyState));
      expect(
        (empty.first, empty.second),
        (l10n.trainingsRestDayFirst, l10n.trainingsRestDaySecond),
      );
      // Sketch: «No hay entrenamiento asignado …» and «Disfruta tu día de
      // descanso» (the previous rest card's second line).
      expect(empty.body, l10n.enjoyRestDay);
      expect(find.text(l10n.noTrainingAssignedForDate), findsOneWidget);
      expect(find.text(l10n.enjoyRestDay), findsOneWidget);
    });

    testWidgets('no training today says «today» and keeps «enjoy your rest '
        'day»', (tester) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(today: const []),
        selectedDate: null,
      );
      final l10n = _l10n(tester);
      expect(find.text(l10n.noTrainingAssignedToday), findsOneWidget);
      expect(find.text(l10n.enjoyRestDay), findsOneWidget);
    });

    testWidgets('history error is an inline message whose link retries', (
      tester,
    ) async {
      final bloc = await pumpTrainingsScene(
        tester,
        state: sceneLoaded(history: const [], historyFailed: true),
      );
      final l10n = _l10n(tester);
      final message = tester.widget<ExomInlineMessage>(
        find.byType(ExomInlineMessage),
      );
      expect(message.kind, ExomMessageKind.error);
      expect(message.title, l10n.errorServer);
      bloc.events.clear();
      await tester.ensureVisible(find.text(l10n.retryButton));
      await tester.tap(find.text(l10n.retryButton));
      await tester.pump();
      final retry = bloc.events.single as TrainingsLoadRequested;
      expect((retry.date, retry.historyDate), (kSceneDate, kSceneDate));
    });

    testWidgets('empty month is an inline note', (tester) async {
      await pumpTrainingsScene(tester, state: sceneLoaded(history: const []));
      final l10n = _l10n(tester);
      final message = tester.widget<ExomInlineMessage>(
        find.byType(ExomInlineMessage),
      );
      expect(message.kind, ExomMessageKind.info);
      expect(message.title, l10n.noActivitiesThisMonth);
    });

    testWidgets('first load and month change show flat skeletons', (
      tester,
    ) async {
      await pumpTrainingsScene(tester, state: const TrainingLoading());
      expect(find.byType(ExomSkeleton), findsWidgets);
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(history: const [], isHistoryLoading: true),
      );
      expect(find.byType(ExomSkeleton), findsNWidgets(3));
    });

    testWidgets('month arrows are labelled 48 dp targets', (tester) async {
      final bloc = await pumpTrainingsScene(tester, state: sceneLoaded());
      final l10n = _l10n(tester);
      final previous = find.byTooltip(l10n.trainingsHistoryPreviousMonth);
      final next = find.byTooltip(l10n.trainingsHistoryNextMonth);
      expect(tester.getSize(previous).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(next).height, greaterThanOrEqualTo(48));
      bloc.events.clear();
      await tester.ensureVisible(previous);
      await tester.tap(previous);
      await tester.pump();
      final event = bloc.events.single as TrainingsLoadRequested;
      expect((event.date, event.historyDate), (kSceneDate, '2026-09-01'));
    });
  });

  // I1 (review DEVOLVER): the footer must respect the pending list's busy
  // state (a confirmed discard waits for the sync and queue locks) and open a
  // session at most once per navigation. Continue / finalise / discard keep
  // their calls and arguments.
  group('I1 · footer and pending list share the busy state', () {
    testWidgets('while a confirmed discard runs the footer is disabled and '
        'opens nothing; once the session is gone the footer goes too', (
      tester,
    ) async {
      final storage = SceneStorage(scenePending());
      final sync = _DiscardSync();
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        storage: storage,
        sync: sync,
      );
      expect(_footer(tester).onPressed, isNotNull);
      await _confirmDiscard(tester);
      final request = sync.requests.single;
      expect(
        (
          request.ownerId,
          request.sessionStamp,
          request.executionId,
          request.trainingId,
          request.date,
        ),
        (
          'owner-A',
          'owner-A:1',
          _sceneExecution,
          'training-legs',
          '2026-10-13',
        ),
      );
      expect(_footer(tester).onPressed, isNull, reason: 'visibly disabled');
      await tester.tap(find.byKey(_footerKey), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(openedRoutes, isEmpty);

      // The discard ends with the session removed and no sync change event:
      // the footer is recomputed from the list.
      storage.pending.clear();
      sync.result.complete(
        const TrainingExecutionDiscardResult(
          TrainingExecutionDiscardReason.discarded,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_footerKey), findsNothing);
      expect(openedRoutes, isEmpty);
      expect(sync.requests, hasLength(1));
    });

    testWidgets('a refused discard gives the footer back', (tester) async {
      final sync = _DiscardSync();
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        storage: SceneStorage(scenePending()),
        sync: sync,
      );
      await _confirmDiscard(tester);
      expect(_footer(tester).onPressed, isNull);
      sync.result.complete(
        const TrainingExecutionDiscardResult(
          TrainingExecutionDiscardReason.storageFailure,
        ),
      );
      await tester.pumpAndSettle();
      expect(_footer(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(_footerKey));
      await tester.pumpAndSettle();
      expect(openedRoutes, [_sceneRoute]);
    });

    testWidgets('a double tap on the footer opens the session once', (
      tester,
    ) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        storage: SceneStorage(scenePending()),
      );
      await tester.tap(find.byKey(_footerKey));
      await tester.tap(find.byKey(_footerKey));
      await tester.pumpAndSettle();
      expect(openedRoutes, [_sceneRoute]);
    });

    testWidgets('row «Continuar» and the footer together open the session '
        'once', (tester) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        storage: SceneStorage(scenePending()),
      );
      final row = find.byKey(const Key('pending-continue-$_sceneExecution'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.tap(find.byKey(_footerKey));
      await tester.pumpAndSettle();
      expect(openedRoutes, [_sceneRoute]);
    });

    testWidgets('after the opened session closes the footer works again', (
      tester,
    ) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        storage: SceneStorage(scenePending()),
      );
      await tester.tap(find.byKey(_footerKey));
      await tester.pumpAndSettle();
      expect(openedRoutes, [_sceneRoute]);
      GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_footerKey));
      await tester.pumpAndSettle();
      expect(openedRoutes, [_sceneRoute, _sceneRoute]);
    });

    // Second review: go_router only completes a push when it is popped. A
    // notification tap on a `/trainings` route (main.dart uses `router.go`)
    // replaces the detail while this page stays mounted, so the guard must not
    // wait for that future.
    testWidgets('after leaving the opened session with go() the footer and '
        'the rows work again', (tester) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        storage: SceneStorage(scenePending()),
      );
      final page = tester.element(find.byType(TrainingsPage));
      void goToTrainings() => GoRouter.of(
        tester.element(find.byType(Scaffold).last),
      ).go('/trainings');

      await tester.tap(find.byKey(_footerKey));
      await tester.pumpAndSettle();
      expect(openedRoutes, [_sceneRoute]);
      goToTrainings();
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(TrainingsPage)),
        same(page),
        reason: 'the same page stays mounted',
      );

      await tester.tap(find.byKey(_footerKey));
      await tester.pumpAndSettle();
      expect(openedRoutes, [_sceneRoute, _sceneRoute]);
      goToTrainings();
      await tester.pumpAndSettle();

      final row = find.byKey(const Key('pending-continue-$_sceneExecution'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(openedRoutes, [_sceneRoute, _sceneRoute, _sceneRoute]);
    });

    testWidgets('a failed navigation releases the footer', (tester) async {
      // No router above the page: `context.push` throws.
      await sl.reset();
      sl.registerSingleton<LocalStorage>(SceneStorage(scenePending()));
      sl.registerFactory<TrainingBloc>(() => SeededTrainingBloc(sceneLoaded()));
      addTearDown(sl.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: themeFor(Brightness.dark),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TrainingsPage(selectedDate: kSceneDate)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // The failed push surfaces as an error of the tap's future.
      final failures = <Object>[];
      Future<void> tapFooter() async {
        await runZonedGuarded(
          () => tester.tap(find.byKey(_footerKey)),
          (error, _) => failures.add(error),
        );
        await tester.pump();
      }

      await tapFooter();
      expect(failures, hasLength(1));
      // Not ignored as «already opening»: the second tap tries again.
      await tapFooter();
      expect(failures, hasLength(2));
    });
  });

  group('today session (L5-D36)', () {
    testWidgets('the day\'s training is the featured block: title on the '
        'shared hero, numbered figures and types; a tap opens it', (
      tester,
    ) async {
      final bloc = await pumpTrainingsScene(tester, state: sceneLoaded());
      final l10n = _l10n(tester);
      expect(
        find.descendant(
          of: find.byKey(_todayKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Hero && widget.tag == 'training-training-legs-title',
          ),
        ),
        findsOneWidget,
      );
      final figures = tester.widget<ExomFigureColumns>(
        find.byType(ExomFigureColumns),
      );
      expect(figures.numbered, isTrue);
      expect(figures.items, [
        ExomFigure(value: '6', label: l10n.exercises.toLowerCase()),
        ExomFigure(value: '24', label: l10n.sets.toLowerCase()),
        ExomFigure(value: '55', label: l10n.trainingsFigureMinutesApprox),
      ]);
      // Minutes and exercises moved to the figures; the types stay.
      expect(
        find.descendant(
          of: find.byKey(_todayKey),
          matching: find.text('Fuerza'),
        ),
        findsOneWidget,
      );
      bloc.events.clear();
      await tester.tap(find.byKey(_todayKey));
      await tester.pumpAndSettle();
      expect(openedRoutes, ['/trainings/training-legs?date=$kSceneDate']);
      GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();
      final reload = bloc.events.single as TrainingsLoadRequested;
      expect((reload.date, reload.historyDate), (kSceneDate, kSceneDate));
    });

    testWidgets('the other trainings of the day stay rich rows', (
      tester,
    ) async {
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(
          today: [
            kSceneTraining,
            _trainingWith(id: 'training-mob', name: 'Movilidad'),
          ],
        ),
      );
      expect(find.byKey(_todayKey), findsOneWidget);
      expect(find.byType(ExomFigureColumns), findsOneWidget);
      final other = tester
          .widgetList<ExomRichRow>(find.byType(ExomRichRow))
          .singleWhere((row) => row.title == 'Movilidad');
      expect(other.leading, isA<ExomRowDate>());
      expect(other.onTap, isNotNull);
    });

    testWidgets('photo of the first exercise with an http thumbnail; «Hoy» '
        'pill only today', (tester) async {
      final withPhoto = sceneLoaded(
        today: [
          _trainingWith(
            thumbnails: const [null, 'file:///x.jpg', 'https://cdn.test/a.jpg'],
          ),
        ],
      );
      await pumpTrainingsScene(tester, state: withPhoto, selectedDate: null);
      final l10n = _l10n(tester);
      expect(
        tester.widget<HomeSessionPhoto>(find.byType(HomeSessionPhoto)).url,
        'https://cdn.test/a.jpg',
      );
      expect(
        tester.widget<ExomMomentPill>(find.byType(ExomMomentPill)).label,
        l10n.todayLabel,
      );

      await pumpTrainingsScene(tester, state: withPhoto);
      expect(find.byType(HomeSessionPhoto), findsOneWidget);
      expect(find.byType(ExomMomentPill), findsNothing);

      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        selectedDate: null,
      );
      expect(find.byType(HomeSessionPhoto), findsNothing);
      expect(find.byType(ExomMomentPill), findsNothing);
    });

    testWidgets('«Hoy sabes / qué hacer.» only on today with a training', (
      tester,
    ) async {
      bool headline(WidgetTester tester) {
        final l10n = _l10n(tester);
        return tester
            .widgetList<ExomTwoLineHeadline>(find.byType(ExomTwoLineHeadline))
            .any(
              (widget) =>
                  widget.first == l10n.trainingsTodayHeadlineFirst &&
                  widget.second == l10n.trainingsTodayHeadlineSecond,
            );
      }

      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        selectedDate: null,
      );
      expect(headline(tester), isTrue);
      await pumpTrainingsScene(tester, state: sceneLoaded());
      expect(headline(tester), isFalse);
      await pumpTrainingsScene(
        tester,
        state: sceneLoaded(today: const []),
        selectedDate: null,
      );
      expect(headline(tester), isFalse);
    });
  });

  group('kicker', () {
    for (final (locale, text) in const [
      (Locale('es'), 'Entrenamiento 14/10'),
      (Locale('en'), 'Training 10/14'),
    ]) {
      testWidgets('the day kicker formats the date in '
          '${locale.languageCode}', (tester) async {
        await pumpTrainingsScene(tester, state: sceneLoaded(), locale: locale);
        expect(
          find.byWidgetPredicate((w) => w is ExomKicker && w.text == text),
          findsOneWidget,
        );
      });
    }
  });

  testWidgets('at 1.6 x the pending box shows its scroll bar and reaches '
      '«Descartar»', (tester) async {
    await pumpTrainingsScene(
      tester,
      state: sceneLoaded(),
      storage: SceneStorage(scenePending()),
      textScale: 1.6,
    );
    final bar = tester.widget<Scrollbar>(
      find.ancestor(
        of: find.byType(PendingTrainingExecutions),
        matching: find.byType(Scrollbar),
      ),
    );
    expect(bar.thumbVisibility, isTrue);
    final discard = find.byKey(const Key('pending-discard-$_sceneExecution'));
    await tester.ensureVisible(discard);
    await tester.pumpAndSettle();
    expect(tester.hitTestOnBinding(tester.getCenter(discard)).path, isNotEmpty);
    await tester.tap(discard);
    await tester.pumpAndSettle();
    // Without a discard service the inspection refuses: a result, no dialog.
    expect(find.byKey(const Key('pending-discard-result')), findsOneWidget);
  });

  group('arrival (M3)', () {
    // The bloc delivers a state in a microtask: `idle` lets it reach the
    // page before the frame that is measured.
    testWidgets('first load: the content fades in and rises', (tester) async {
      final bloc = await pumpTrainingsScene(
        tester,
        state: const TrainingLoading(),
        disableAnimations: false,
      );
      bloc.seed(sceneLoaded());
      await tester.idle();
      await tester.pump();
      expect(_arrivalOpacity(tester), lessThan(1));
      final start = tester.getTopLeft(find.byKey(_todayKey)).dy;
      await tester.pump(const Duration(milliseconds: 400));
      expect(_arrivalOpacity(tester), 1);
      expect(tester.getTopLeft(find.byKey(_todayKey)).dy, lessThan(start));
    });

    testWidgets('reduced motion: 120 ms fade, no rise', (tester) async {
      final bloc = await pumpTrainingsScene(
        tester,
        state: const TrainingLoading(),
      );
      bloc.seed(sceneLoaded());
      await tester.idle();
      await tester.pump();
      final start = tester.getTopLeft(find.byKey(_todayKey)).dy;
      await tester.pump(const Duration(milliseconds: 120));
      expect(_arrivalOpacity(tester), 1);
      expect(tester.getTopLeft(find.byKey(_todayKey)).dy, start);
    });

    testWidgets('a refresh changes the content in place', (tester) async {
      final bloc = await pumpTrainingsScene(
        tester,
        state: sceneLoaded(),
        disableAnimations: false,
      );
      await tester.pump(const Duration(milliseconds: 400));
      bloc.seed(const TrainingLoading());
      await tester.idle();
      await tester.pump();
      bloc.seed(sceneLoaded(history: const []));
      await tester.idle();
      await tester.pump();
      expect(_arrivalOpacity(tester), 1);
    });
  });

  // CC 3: main scene (one pending session and history), today (headline,
  // photo slot and figures of L5-D36) and empty scene, es/en.
  final scenes = <String, (TrainingState, List<Map<String, dynamic>>, String?)>{
    'main': (sceneLoaded(), scenePending(), kSceneDate),
    'today': (sceneLoaded(), scenePending(), null),
    'empty': (
      sceneLoaded(today: const [], history: const []),
      const [],
      kSceneDate,
    ),
  };
  for (final MapEntry(key: name, value: (state, pending, selectedDate))
      in scenes.entries) {
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final (width, scale) in const [
        (320.0, 1.3),
        (320.0, 1.6),
        (360.0, 1.6),
      ]) {
        testWidgets('CC3 $name ${locale.languageCode} ${width.toInt()} dp '
            'at $scale x: no overflow', (tester) async {
          await pumpTrainingsScene(
            tester,
            state: state,
            storage: SceneStorage([...pending]),
            selectedDate: selectedDate,
            width: width,
            height: 640,
            textScale: scale,
            locale: locale,
          );
          expectNoOverflow(tester);
          expectNoEllipsis(tester);
          await tester.drag(_mainList, const Offset(0, -3000));
          await tester.pump();
          expectNoOverflow(tester);
          expectNoEllipsis(tester);
        });
      }
      testWidgets('CC3 $name ${locale.languageCode} 2.0 x: all content '
          'reachable by scrolling', (tester) async {
        await pumpTrainingsScene(
          tester,
          state: state,
          storage: SceneStorage([...pending]),
          selectedDate: selectedDate,
          width: 320,
          height: 640,
          textScale: 2.0,
          locale: locale,
        );
        expectNoOverflow(tester);
        for (final scrollable in find.byType(Scrollable).evaluate().toList()) {
          final position =
              (scrollable as StatefulElement).state as ScrollableState;
          await tester.drag(
            find.byWidget(scrollable.widget),
            const Offset(0, -5000),
          );
          // Lets a bouncing list settle back onto its end.
          await tester.pumpAndSettle();
          expect(
            position.position.pixels,
            moreOrLessEquals(position.position.maxScrollExtent, epsilon: 1e-6),
          );
          expectNoOverflow(tester);
        }
        expectNoEllipsis(tester);
      });
    }
  }

  // CC 4: both themes, no lime ink in light, contrast and 48 dp targets in the
  // scenes that have a golden (main), today and the empty scene.
  for (final MapEntry(key: name, value: (state, pending, selectedDate))
      in scenes.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('CC4 $name ${brightness.name}: contrast, targets and no lime '
          'ink', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpTrainingsScene(
          tester,
          state: state,
          storage: SceneStorage([...pending]),
          selectedDate: selectedDate,
          brightness: brightness,
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectTapTargetGuidelines(tester);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        handle.dispose();
      });
    }
  }
}
