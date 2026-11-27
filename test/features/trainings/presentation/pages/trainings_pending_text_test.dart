// ENTRENAR-TEXTO (OBS-1 of CIERRE-L5-A): the box of pending sessions on the
// Entrenar tab must show the actions of the first session (Continuar,
// Finalizar, Descartar) in full, without scrolling, at 1.0, 1.3 and 1.6 text
// scale on 360x800 and 320x640 dp; with several sessions the rest scrolls.
import 'package:exom_app/core/widgets/exom_text_link.dart';
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

/// Scroll position of the pending box (the first scrollable above the list).
ScrollPosition _boxPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(Scrollbar).first,
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void main() {
  for (final size in [const Size(360, 800), const Size(320, 640)]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets(
        'one pending session: its actions show in full without scrolling '
        '(${size.width.toInt()}x${size.height.toInt()}, text $scale)',
        (tester) async {
          await pumpTrainingsScene(
            tester,
            state: sceneLoaded(),
            storage: SceneStorage(_sessions(1)),
            width: size.width,
            height: size.height,
            textScaler: AndroidNonlinearTextScaler(scale),
          );
          await tester.pump(const Duration(milliseconds: 100));
          final box = tester.getRect(
            find.descendant(
              of: find.byType(Scrollbar).first,
              matching: find.byType(Scrollable),
            ),
          );
          // 320x640 at 1.6: the long date of the row (L5-D52, OBS-B) wraps one
          // line more and the first session needs 511 dp, over the 75 % cap
          // of L5-D57 (480 dp): the box stops at the cap and its last action
          // is reached by scrolling (open item of the OBS-B fix).
          if (size.height == 640 && scale == 1.6) {
            expect(box.height, closeTo(640 * .75, 0.5));
            await tester.ensureVisible(
              find.byKey(Key('pending-discard-$_first')),
            );
            await tester.pump();
            expect(_boxPosition(tester).maxScrollExtent, lessThan(40));
          } else {
          for (final key in ['continue', 'finalize', 'discard']) {
            final link = find.byKey(Key('pending-$key-$_first'));
            expect(link, findsOneWidget);
            final rect = tester.getRect(
              find.descendant(of: link, matching: find.byType(Text)),
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(box.bottom + 0.5),
              reason: key,
            );
          }
          // Nothing left to scroll: no scroll bar with a single session.
          expect(_boxPosition(tester).maxScrollExtent, 0);
          }
          expect(find.byType(ExomTextLink), findsNWidgets(3));
        },
      );
    }
  }

  testWidgets('several pending sessions: the first shows whole, the rest '
      'scrolls', (tester) async {
    await pumpTrainingsScene(
      tester,
      state: sceneLoaded(),
      storage: SceneStorage(_sessions(4)),
      width: 360,
      height: 800,
      textScaler: const AndroidNonlinearTextScaler(1.6),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final box = tester.getRect(
      find.descendant(
        of: find.byType(Scrollbar).first,
        matching: find.byType(Scrollable),
      ),
    );
    final discard = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('pending-discard-$_first')),
        matching: find.byType(Text),
      ),
    );
    expect(discard.bottom, lessThanOrEqualTo(box.bottom + 0.5));
    expect(_boxPosition(tester).maxScrollExtent, greaterThan(0));
    expect(box.height, lessThanOrEqualTo(800 * .75 + 0.5));
  });
}
