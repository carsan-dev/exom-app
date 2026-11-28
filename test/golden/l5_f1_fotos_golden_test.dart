// L5-F1 «Fotos de progreso» goldens (docs/plans/rediseno-app-l5-contrato-v2.md,
// CC 8 and section 5.3): the frames of f-resto.html, F1 · f1-lista (main
// scene), f1-origen (source sheet), f1-visor (viewer), f1-vacio and
// f1-carga-error (loading and load error), in dark and light at text scale
// 1.0 and 1.6 on the 390x844 surface of the L0 baseline, without animation.
// Network photos never load in tests: the tiles show the flat `raised`
// placeholder.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_f1_fotos_golden_test.dart
@Tags(['golden'])
library;

import 'package:exom_app/features/progress_photos/domain/repositories/progress_photo_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../core/widgets/expect_no_lime_ink.dart';
import '../features/progress_photos/progress_photos_page_test.dart'
    show FakeRepository;
import '../features/progress_photos/progress_photos_redesign_scene.dart';

typedef _Scene = ({
  ProgressPhotoRepository Function() repository,
  Future<void> Function(WidgetTester tester)? open,
});

Future<void> _openSource(WidgetTester tester) async {
  final action = find.byTooltip('Añadir Espalda').first;
  await tester.ensureVisible(action);
  await tester.pump();
  await tester.tap(action);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // Let the ink of the tapped link fade out.
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _openViewer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ampliar Frontal').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

final Map<String, _Scene> _scenes = {
  'fotos': (repository: listRepository, open: null),
  'fotos_origen': (repository: listRepository, open: _openSource),
  'fotos_visor': (repository: listRepository, open: _openViewer),
  'fotos_vacio': (repository: FakeRepository.new, open: null),
  'fotos_carga': (repository: loadingRepository, open: null),
  'fotos_error': (repository: ErrorRepository.new, open: null),
};

void main() {
  for (final MapEntry(key: name, value: scene) in _scenes.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in const [1.0, 1.6]) {
        final suffix = '${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
        testWidgets('golden ${name}_$suffix', (tester) async {
          await pumpPhotosScene(
            tester,
            repository: scene.repository() as FakeRepository,
            brightness: brightness,
            textScale: scale,
          );
          await scene.open?.call(tester);
          expectNoOverflow(tester);
          await expectTapTargetGuidelines(tester);
          expectNoLimeInk(tester);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/${name}_$suffix.png'),
          );
        });
      }
    }
  }
}
