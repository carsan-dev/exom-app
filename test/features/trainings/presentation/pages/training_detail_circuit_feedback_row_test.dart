// The «Enviar vídeos» button of a circuit row keeps its label on one line
// when the row also shows the «marcar como pendiente» mark.
import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'training_detail_redesign_test.dart'
    show pumpDenseTrainingDetail, pumpTrainingDetail;

void main() {
  setUpAll(() async => initializeDateFormatting('es'));
  tearDown(() async => sl.reset());

  testWidgets('label is one line at 390 dp, 1.0x, in the row with the mark', (
    tester,
  ) async {
    // The dense session has a done block, which shows the mark.
    await pumpDenseTrainingDetail(tester, brightness: Brightness.light);
    final labels = find.descendant(
      of: find.byKey(const ValueKey('circuit-feedback-button')),
      matching: find.byType(Text),
    );
    expect(labels, findsWidgets);
    final heights = [
      for (var i = 0; i < labels.evaluate().length; i++)
        tester.getSize(labels.at(i)).height,
    ];
    // 14 px text: one line is under 24 px, two lines are over 28 px.
    for (final height in heights) {
      expect(height, lessThan(24));
    }
  });

  testWidgets('no overflow at 320 dp, 1.3x', (tester) async {
    await pumpTrainingDetail(
      tester,
      completed: const {'te-1'},
      width: 320,
      locale: const Locale('es'),
      textScaler: const TextScaler.linear(1.3),
    );
    expect(tester.takeException(), isNull);
  });
}
