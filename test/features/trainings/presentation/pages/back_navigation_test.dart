// L6 S11-10a / P19a (plan `rediseno-exom-app.md` §7 row 19 and §11
// «Interrupción por navegación»): system back (Android back button and the
// predictive back gesture) and the iOS edge swipe in the middle of the set
// sheet, during the rest and before leaving go through `PopScope` and
// `_confirmExit`; no logged set nor the draft is lost.
//
// The closing sheet of the session («Terminar sesión») is covered in
// training_completion_sheet_test.dart (group «closing without sending»).
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_exercise_redesign_test.dart' show pumpActiveExercise;
import 'circuit_test_harness.dart';

final _sheetSave = find.byKey(const Key('set-sheet-save'));
final _countField = find.byKey(const Key('set-sheet-count-field'));
final _weightField = find.byKey(const Key('set-sheet-weight-field'));

/// Fixed frames instead of pumpAndSettle: the rest rule and the busy
/// primary button animate continuously by design.
Future<void> _frames(WidgetTester tester, [int count = 4]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Android predictive back: the gesture starts on the edge and is committed,
/// as the engine reports it on `flutter/backgesture`.
Future<void> _predictiveBack(WidgetTester tester) async {
  const codec = StandardMethodCodec();
  Future<void> send(String method, [Object? arguments]) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.backGesture.name,
        codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
  await send('startBackGesture', <String, Object?>{
    'touchOffset': <double>[5, 300],
    'progress': 0.0,
    'swipeEdge': 0,
  });
  await tester.pump();
  await send('updateBackGestureProgress', <String, Object?>{
    'touchOffset': <double>[120, 300],
    'progress': 0.5,
    'swipeEdge': 0,
  });
  await tester.pump();
  await send('commitBackGesture');
}

/// Whether the route of the page under [page] lets an edge swipe pop it
/// (iOS back swipe; false keeps the gesture away from `PopScope`).
bool _swipeEnabled(WidgetTester tester, Finder page) =>
    ModalRoute.of(tester.element(page))!.popGestureEnabled;

void main() {
  group('active exercise', () {
    AppLocalizations l10n(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(ActiveExercisePage)));

    ActiveExerciseState state(WidgetTester tester) =>
        BlocProvider.of<ActiveExerciseBloc>(
          tester.element(find.byKey(const Key('active-exercise-close'))),
        ).state;

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('footer-executing')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_sheetSave, findsOneWidget);
    }

    Future<void> logSet(WidgetTester tester) async {
      await openSheet(tester);
      await tester.tap(_sheetSave);
      await _frames(tester);
    }

    Future<void> skipRest(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('active-exercise-rest-skip')));
      await _frames(tester);
    }

    testWidgets('back with the set sheet open and typed values closes the '
        'sheet only: nothing is logged and the logged set stays', (
      tester,
    ) async {
      final h = await pumpActiveExercise(tester, initialWeightKg: 60);
      await logSet(tester);
      await skipRest(tester);
      final draftBefore = h.draft!;
      expect(draftBefore.completedSets, 1);

      await openSheet(tester);
      await tester.enterText(_countField, '6');
      await tester.enterText(_weightField, '70');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await _frames(tester);

      expect(_sheetSave, findsNothing);
      expect(find.byType(ActiveExercisePage), findsOneWidget);
      expect(find.text(l10n(tester).activeExerciseCloseTitle), findsNothing);
      expect(state(tester).status, ActiveExerciseStatus.executing);
      expect(state(tester).currentSet, 2);
      expect(h.draft!.completedSets, 1);
      expect(h.draft!.completedSetData, draftBefore.completedSetData);

      // The sheet opens again for the same set and still logs it.
      await openSheet(tester);
      await tester.tap(_sheetSave);
      await _frames(tester);
      expect(h.draft!.completedSets, 2);
      expect(h.draft!.completedSetData, hasLength(2));
    });

    testWidgets('the predictive back gesture with the set sheet open closes '
        'the sheet only', (tester) async {
      final h = await pumpActiveExercise(tester);
      await openSheet(tester);
      await tester.enterText(_countField, '5');
      await tester.pump();

      await _predictiveBack(tester);
      await _frames(tester);

      expect(_sheetSave, findsNothing);
      expect(find.byType(ActiveExercisePage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(h.draft?.completedSets ?? 0, 0);
    });

    testWidgets('back during the rest asks first; cancel keeps the rest and '
        'the set, confirm leaves with the set kept', (tester) async {
      final h = await pumpActiveExercise(tester, initialWeightKg: 60);
      await logSet(tester);
      final resting = state(tester);
      expect(resting.status, ActiveExerciseStatus.resting);
      final restEndsAt = resting.restEndsAt!;
      final setData = h.draft!.completedSetData;
      expect(_swipeEnabled(tester, find.byType(ActiveExercisePage)), isFalse);

      await tester.binding.handlePopRoute();
      await _frames(tester);
      final strings = l10n(tester);
      expect(find.text(strings.activeExerciseCloseTitle), findsOneWidget);
      await tester.tap(find.text(strings.cancel));
      await _frames(tester);

      expect(find.byType(ActiveExercisePage), findsOneWidget);
      expect(state(tester).status, ActiveExerciseStatus.resting);
      expect(state(tester).restEndsAt, restEndsAt);
      expect(h.draft!.restEndsAt, restEndsAt);
      expect(h.draft!.completedSets, 1);

      await _predictiveBack(tester);
      await _frames(tester);
      expect(find.text(strings.activeExerciseCloseTitle), findsOneWidget);
      await tester.tap(find.text(strings.continueButton));
      await _frames(tester);

      expect(find.byType(ActiveExercisePage), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(h.draft!.completedSets, 1);
      expect(h.draft!.completedSetData, setData);
    });

    testWidgets('back with no logged set leaves without asking and writes no '
        'set', (tester) async {
      final h = await pumpActiveExercise(tester);
      await tester.binding.handlePopRoute();
      await _frames(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(h.draft?.completedSets ?? 0, 0);
    });
  });

  group('circuit', () {
    final a = circuitExercise('a', 'Burpees', restSeconds: 30);
    final b = circuitExercise('b', 'Sentadilla con salto', restSeconds: 20);
    const footer = ValueKey('circuit-executing-footer');

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(footer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_sheetSave, findsOneWidget);
    }

    Future<void> logSet(WidgetTester tester) async {
      await openSheet(tester);
      await tester.tap(_sheetSave);
      await settleFrames(tester);
    }

    testWidgets('back with the set sheet open closes the sheet only and '
        'writes nothing', (tester) async {
      final h = await pumpCircuit(tester, exercises: [a, b]);
      await logSet(tester);
      await tester.tap(find.byKey(const Key('circuit-rest-skip')));
      await settleFrames(tester);
      final writes = h.storage.writes.length;
      final last = h.storage.lastWrite;

      await openSheet(tester);
      await tester.enterText(_countField, '9');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settleFrames(tester);

      expect(_sheetSave, findsNothing);
      expect(find.byType(ActiveCircuitPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(h.storage.writes.length, writes);
      expect(h.storage.lastWrite, last);
      expect(h.storage.removedKeys, isEmpty);
    });

    testWidgets('back during the rest asks first; cancel keeps the rest, '
        'confirm leaves with the logged round kept', (tester) async {
      final h = await pumpCircuit(tester, exercises: [a, b]);
      await logSet(tester);
      expect(find.byKey(const Key('circuit-rest-skip')), findsOneWidget);
      expect(_swipeEnabled(tester, find.byType(ActiveCircuitPage)), isFalse);
      final writes = h.storage.writes.length;
      final last = h.storage.lastWrite;
      final l10n = circuitL10n(tester);

      await tester.binding.handlePopRoute();
      await settleFrames(tester);
      expect(find.text(l10n.activeExerciseCloseTitle), findsOneWidget);
      await tester.tap(find.text(l10n.cancel));
      await settleFrames(tester);
      expect(find.byType(ActiveCircuitPage), findsOneWidget);
      expect(find.byKey(const Key('circuit-rest-skip')), findsOneWidget);
      expect(h.native.cancels, 0);

      await _predictiveBack(tester);
      await settleFrames(tester);
      expect(find.text(l10n.activeExerciseCloseTitle), findsOneWidget);
      await tester.tap(find.text(l10n.continueButton));
      await settleFrames(tester);

      expect(find.text('detail'), findsOneWidget);
      expect(h.storage.writes.length, writes);
      expect(h.storage.lastWrite, last);
      expect(h.storage.removedKeys, isEmpty);
    });
  });
}
