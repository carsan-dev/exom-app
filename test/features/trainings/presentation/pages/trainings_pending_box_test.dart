// Entrenar, box of pending sessions (OBS-A and OBS-B of VERIF-FINAL-L5):
// the box height cap follows a text scale change made while the tab is open,
// and the notice and the row dates follow the count and the active locale.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import 'trainings_redesign_fixture.dart';

const _first = '8f3c2a71-5d94-4be0-a6c1-0e7b92d4f358';

List<Map<String, dynamic>> _sessions(int count) => [
  for (var i = 0; i < count; i++)
    {
      ...scenePending().single,
      'id': i == 0 ? _first : 'second-session-$i',
      'assignment_date': '2026-10-${13 - i}',
    },
];

Finder get _boxScrollable => find.descendant(
  of: find.byType(Scrollbar).first,
  matching: find.byType(Scrollable),
);

void main() {
  testWidgets('OBS-A: text scale changed while open re-measures the box', (
    tester,
  ) async {
    final scale = ValueNotifier<TextScaler>(const AndroidNonlinearTextScaler(1.0));
    addTearDown(scale.dispose);
    await pumpTrainingsScene(
      tester,
      state: sceneLoaded(),
      storage: SceneStorage(_sessions(1)),
      width: 360,
      height: 800,
      textScalerNotifier: scale,
    );
    await tester.pump(const Duration(milliseconds: 100));

    scale.value = const AndroidNonlinearTextScaler(1.6);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final box = tester.getRect(_boxScrollable);
    for (final key in ['continue', 'finalize', 'discard']) {
      final rect = tester.getRect(
        find.descendant(
          of: find.byKey(Key('pending-$key-$_first')),
          matching: find.byType(Text),
        ),
      );
      expect(rect.bottom, lessThanOrEqualTo(box.bottom + 0.5), reason: key);
    }
    expect(
      tester.state<ScrollableState>(_boxScrollable.first).position.maxScrollExtent,
      0,
    );
  });

  testWidgets('OBS-B es: two sessions read in plural with long dates', (
    tester,
  ) async {
    await pumpTrainingsScene(
      tester,
      state: sceneLoaded(),
      storage: SceneStorage(_sessions(2)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Tienes 2 entrenamientos pendientes de finalizar'),
      findsOneWidget,
    );
    expect(find.textContaining('13 de octubre de 2026'), findsOneWidget);
    expect(find.textContaining('12 de octubre de 2026'), findsOneWidget);
    expect(find.textContaining('2026-10-13'), findsNothing);
  });

  testWidgets('OBS-B es: one session keeps the singular', (tester) async {
    await pumpTrainingsScene(
      tester,
      state: sceneLoaded(),
      storage: SceneStorage(_sessions(1)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Tienes un entrenamiento pendiente de finalizar'),
      findsOneWidget,
    );
  });

  testWidgets('OBS-B en: two sessions read in plural with long dates', (
    tester,
  ) async {
    await pumpTrainingsScene(
      tester,
      state: sceneLoaded(),
      storage: SceneStorage(_sessions(2)),
      locale: const Locale('en'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('You have 2 workouts pending completion'),
      findsOneWidget,
    );
    expect(find.textContaining('October 13, 2026'), findsOneWidget);
    expect(find.textContaining('2026-10-13'), findsNothing);
  });
}
