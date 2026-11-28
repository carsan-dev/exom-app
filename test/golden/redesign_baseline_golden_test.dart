// Redesign L0 baseline goldens (plan: docs/plans/rediseno-exom-app.md, L0).
//
// IMPORTANT: goldens were generated on Windows with the flutter_test default
// font (Ahem) replaced by the bundled DMSans/BarlowCondensed and the SDK Material Icons,
// both read from disk in redesign_scenes.dart (loadRedesignFonts). If those files
// cannot be found the fallback is Ahem boxes and the goldens will not match. They
// are LAYOUT baselines for this Flutter version/OS (3.41.5, Windows): text
// rasterisation differs per OS, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden
//
// Scenes: Inicio (day with a session), Inicio descanso (day without a
// training), Detalle, Detalle en curso and Detalle hecho (L3: one exercise
// confirmed, one pending sync and one saved on the phone; every exercise
// done), Ejercicio activo, Hoja de serie, Descanso, and since L3 unit 3 Hoja
// de serie with a field error and Descanso after «+30 s», and since L3 unit 4
// the active circuit (executing, its set sheet, a round rest and ready to
// finish); light/dark and
// text scale 1.0/1.6 on a 390x844 surface at devicePixelRatio 1.0.
//
// Inicio was skipped in L0 because HomePage read DateTime.now() directly. L3
// (decision D10) added an injectable clock to HomePage; the Inicio scenes fix
// it to Wednesday 18 Nov 2026 (see redesign_scenes.dart).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign_scenes.dart';

void main() {
  const scenes = [
    RedesignScene.inicio,
    RedesignScene.inicioDescanso,
    RedesignScene.detalle,
    RedesignScene.detalleEnCurso,
    RedesignScene.detalleHecho,
    RedesignScene.ejercicioActivo,
    RedesignScene.hojaSerie,
    RedesignScene.descanso,
    RedesignScene.hojaSerieError,
    RedesignScene.descansoMas30,
    RedesignScene.circuitoActivo,
    RedesignScene.hojaCircuito,
    RedesignScene.descansoCircuito,
    RedesignScene.circuitoListo,
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
