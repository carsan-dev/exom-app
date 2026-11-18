// Redesign L0 baseline goldens (plan: docs/plans/rediseno-exom-app.md, L0).
//
// IMPORTANT: goldens were generated on Windows with the flutter_test default
// font (Ahem) replaced by the bundled CabinetGrotesk and the SDK Material Icons,
// both read from disk in redesign_scenes.dart (loadRedesignFonts). If those files
// cannot be found the fallback is Ahem boxes and the goldens will not match. They
// are LAYOUT baselines for this Flutter version/OS (3.41.5, Windows): text
// rasterisation differs per OS, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden
//
// Scenes: Detalle, Ejercicio activo, Hoja de serie, Descanso; light/dark and
// text scale 1.0/1.6 on a 390x844 surface at devicePixelRatio 1.0.
//
// Skipped scene: Inicio. HomePage (header "Hoy/hace N dias", WeekDaySelector
// today/past styling and day letters) reads DateTime.now() directly with no
// injectable clock, so its pixels change every day. Pinning it would need a
// test-only hook in lib/, which L0 forbids. Inicio is still covered by the
// accessibility inventory (test/a11y), which does not compare pixels.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign_scenes.dart';

void main() {
  const scenes = [
    RedesignScene.detalle,
    RedesignScene.ejercicioActivo,
    RedesignScene.hojaSerie,
    RedesignScene.descanso,
  ];
  for (final scene in scenes) {
    for (final brightness in Brightness.values) {
      for (final scale in const [1.0, 1.6]) {
        final name =
            '${scene.slug}_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
        testWidgets('golden $name', (tester) async {
          final handle = await pumpRedesignScene(
            tester,
            scene,
            theme: redesignTheme(brightness),
            textScale: scale,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
          await handle.dispose(tester);
        });
      }
    }
  }
}
