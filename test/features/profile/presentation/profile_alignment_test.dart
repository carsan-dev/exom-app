// Alignment of Perfil (L5-B4): the numbered index starts right on the bottom
// rule of the figure columns and shares it, and the «Datos corporales» band
// starts right on the bottom rule of the index (round r4), as the band of the
// active exercise and «Historial» in Entrenar do. Owner decision of the alignment
// round r3: it departs from the sketch (`.x-cols` followed by `.x-ixs.mt32`),
// whose empty strip between two rules read as an empty section. Measured on
// the real layout (alignment_probe.dart).
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../trainings/presentation/pages/alignment_probe.dart';
import 'profile_scene.dart';

const _width = 390.0;

void main() {
  for (final (label, metrics) in [
    ('with data', sceneMetrics),
    ('without data', SceneMetricsRepository.new),
  ]) {
    testWidgets('$label: the index shares the bottom rule of the figure '
        'columns, no empty strip and no double rule', (tester) async {
      await pumpProfileScene(
        tester,
        metrics: metrics(),
        brightness: Brightness.light,
      );
      final index = find.byType(ExomIndexList);
      await revealInProfile(tester, index);
      final list = find.byType(ListView).first;
      final indexTop = tester.getRect(index).top;
      final rules = probeFullWidthRules(tester, list, _width);
      final above = rules.where((r) => r.y < indexTop - 0.5).last;
      expect(
        indexTop - above.y,
        1,
        reason: 'the index must start on the columns rule (shared)',
      );
      expect(
        rules.where((r) => (r.y - indexTop).abs() < 0.5),
        isEmpty,
        reason: 'no second rule on top of the index',
      );
      final problems = probeRuleProblems(tester, list, _width);
      expect(
        problems.where(
          (p) => p.contains('rule y=${above.y.toStringAsFixed(1)} '),
        ),
        isEmpty,
      );
    });

    testWidgets('$label: the «Datos corporales» band shares the bottom rule '
        'of the index, no empty strip and no double rule', (tester) async {
      await pumpProfileScene(
        tester,
        metrics: metrics(),
        brightness: Brightness.light,
      );
      final band = find.byKey(const Key('profile-body-data'));
      await revealInProfile(tester, band);
      final list = find.byType(ListView).first;
      final indexBottom = tester.getRect(find.byType(ExomIndexList)).bottom;
      final bandTop = tester.getRect(band).top;
      final rules = probeFullWidthRules(tester, list, _width);
      expect(
        bandTop - indexBottom,
        0,
        reason: 'the band must start on the index bottom rule (shared)',
      );
      expect(
        rules.where((r) => (r.y - bandTop).abs() < 0.5),
        isEmpty,
        reason: 'no second rule on top of the band',
      );
      expect(
        probeRuleProblems(tester, list, _width).where(
          (p) => p.contains('rule y=${(indexBottom - 1).toStringAsFixed(1)} '),
        ),
        isEmpty,
      );
    });
  }
}
