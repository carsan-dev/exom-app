// Redesign L0 accessibility guideline INVENTORY (plan: docs/plans/rediseno-exom-app.md, L0).
//
// Pumps the same scenes as the golden baseline (Inicio, Inicio descanso,
// Detalle, Detalle en curso, Detalle hecho, Ejercicio activo, Hoja de serie,
// Descanso, Hoja de serie con error, Descanso +30 s and, since L3 unit 4, the
// four active circuit scenes) in the light and dark theme and evaluates
// androidTapTargetGuideline, iOSTapTargetGuideline, labeledTapTargetGuideline and
// textContrastGuideline with `guideline.evaluate(tester)`.
//
// Nothing is weakened: a guideline that passes today is asserted to pass. A
// guideline that fails today is listed in [knownBaselineFailures] with a
// normalised signature of its violations and asserted to STILL fail in exactly
// that way. When a later lot fixes a violation this test fails on purpose: remove
// the fixed entry (or update its signature) in that lot's change.
//
// Notes: the scenes use the bundled DMSans/BarlowCondensed fonts since L1 (see loadRedesignFonts);
// textContrastGuideline samples rendered pixels: it takes the text box +4 px and
// compares the most frequent lighter and darker colours. With thin DM Sans
// strokes the antialiased edge shades can outnumber the pure text pixels, so it
// may measure an edge shade instead of the text. So textContrast is asserted
// per violation, not per exact label set: every label the sampler reports is
// resolved deterministically (see [resolvedTextContrast] in
// resolved_text_contrast.dart: text colour from the effective style, background
// from the dominant colour behind it) and must reach WCAG AA (4.5, or 3.0 for
// large text). A real low-contrast text fails; an edge-shade artefact passes on
// whichever label it lands on. If a reported label cannot be resolved the test
// fails, it is never skipped. The label is the text the guideline looked up for
// the node (see [guidelineTextOfNode]): a merging node such as «Saltar
// descanso» (ExomQuietButton) prints no label of its own in the reason, which
// on Linux CI, where the sampler flags it, resolved to "null". An exact label
// set was dropped because it is brittle: the D11 tracking change (bodyMedium
// -0.22) moved it («0/3 ejercicios completados» and «En ejecución» stopped being
// reported; «Pie trasero…» is newly reported in ejercicio_activo dark and
// descanso dark). The sampled and resolved values are printed as informational
// lines.
// Inicio: since L3 (decision D10) the scenes fix HomePage's clock to Wednesday
// 18 Nov 2026, so every Inicio cell is asserted like the other scenes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/theme/wcag_contrast.dart';
import '../golden/redesign_scenes.dart';
import 'resolved_text_contrast.dart';

const _guidelines = <String, AccessibilityGuideline>{
  'androidTapTarget': androidTapTargetGuideline,
  'iOSTapTarget': iOSTapTargetGuideline,
  'labeledTapTarget': labeledTapTargetGuideline,
  'textContrast': textContrastGuideline,
};

String? _trim(String? value) => value?.replaceFirst(RegExp(r'\.$'), '');

/// Normalises an [Evaluation.reason] into a sorted, date- and id-independent
/// list of violations. A contrast violation is labelled with [textOfNode] (the
/// text the guideline looked up for the node) when given, else with the label
/// printed in the reason.
List<String> violationSignature(
  String? reason, {
  String? Function(int id)? textOfNode,
}) {
  if (reason == null || reason.trim().isEmpty) return const [];
  final chunks = reason
      .split(RegExp(r'(?=SemanticsNode#\d+\()'))
      .where((chunk) => chunk.trim().startsWith('SemanticsNode#'));
  final signature = <String>[];
  for (final chunk in chunks) {
    final rect = RegExp(r'Rect\.fromLTRB\(([^)]*)\)').firstMatch(chunk)?.group(1);
    final tap = RegExp(
      r'expected tap target size of at least Size\(([^)]*)\), but found Size\(([^)]*)\)',
    ).firstMatch(chunk);
    final contrast = RegExp(
      r'Expected contrast ratio of at least ([\d.]+) but found ([\d.]+) for a font size of ([\d.]+)',
    ).firstMatch(chunk);
    if (tap != null) {
      signature.add('tap-target rect=($rect) min=${tap.group(1)} found=${tap.group(2)}');
    } else if (chunk.contains('expected tappable node to have semantic label')) {
      signature.add('missing-label rect=($rect)');
    } else if (contrast != null) {
      final id = int.parse(
        RegExp(r'^\s*SemanticsNode#(\d+)\(').firstMatch(chunk)!.group(1)!,
      );
      final label = textOfNode != null
          ? textOfNode(id)
          : RegExp(r'label: "([^"]*)"').firstMatch(chunk)?.group(1);
      signature.add(
        'contrast label="$label" min=${_trim(contrast.group(1))} found=${_trim(contrast.group(2))} size=${_trim(contrast.group(3))}',
      );
    } else {
      signature.add(chunk.replaceAll(RegExp(r'#\d+'), '#').trim());
    }
  }
  signature.sort();
  return signature;
}

/// Violations observed on the unmodified origin/develop baseline.
/// L1 (V4 tokens) removed every textContrast pin of L0 (Detalle claro,
/// Ejercicio activo claro/oscuro, Descanso claro/oscuro): those cells must now
/// pass, so a contrast regression fails this test.
/// L3 (Inicio) removed the two `inicio/*/androidTapTarget` pins: the week
/// strip slots now measure at least 48x48.
/// L3 (Detalle) removed the two `detalle/*/labeledTapTarget` pins: the back
/// button now carries the localized back tooltip as its label. The detail
/// scenes «en curso» and «hecho» added in L3 must pass every guideline.
/// L3 (Ejercicio activo) removed the eight `ejercicio_activo/*` and
/// `descanso/*` close-button pins (44x44 and unlabeled): the close button is
/// now a 48x48 IconButton whose tooltip «Cerrar ejercicio» is its label. The
/// scenes «hoja_serie_error» and «descanso_mas_30» added then must pass
/// every guideline.
/// L3 (Circuito activo) added «circuito_activo», «hoja_circuito»,
/// «descanso_circuito» and «circuito_listo»: they must pass every guideline.
/// Key: `<scene>/<theme>/<guideline>`. Anything not listed must pass.
const knownBaselineFailures = <String, List<String>>{};

// Labels the sampler reported as artefacts on 2026-11-18 (documentation only,
// NOT asserted): hoja_serie «Objetivo: 8 · RIR 2», «kg», «Anterior: 8 reps ·
// 60 kg»; ejercicio_activo and descanso «Pie trasero…» and «Último peso: 60 kg».
// True pairs there are all >= 4.5 (see the resolved values printed by the test).

final _contrastEntry = RegExp(r'^contrast label="(.*)" min=\S+ found=(\S+) size=');

/// Cells printed but NOT asserted. Empty since L3: the Inicio cells were
/// informational while HomePage read DateTime.now(); with the fixed scene
/// clock (decision D10) they are asserted like every other scene.
bool _isInformational(String key) => false;

void main() {
  for (final scene in RedesignScene.values) {
    for (final brightness in Brightness.values) {
      testWidgets('guidelines ${scene.slug} ${brightness.name}', (tester) async {
        final semantics = tester.ensureSemantics();
        SceneCapture? capture;
        final handle = await pumpRedesignScene(
          tester,
          scene,
          theme: redesignTheme(brightness),
        );
        for (final entry in _guidelines.entries) {
          final key = '${scene.slug}/${brightness.name}/${entry.key}';
          final result = await entry.value.evaluate(tester);
          final signature = violationSignature(
            result.reason,
            textOfNode: (id) => guidelineTextOfNode(tester, id),
          );
          // Inventory line collected by the evidence log.
          // ignore: avoid_print
          print('GUIDELINE $key passed=${result.passed} violations=${signature.length}');
          for (final violation in signature) {
            // ignore: avoid_print
            print('VIOLATION $key $violation');
          }
          if (_isInformational(key)) continue;
          if (entry.key == 'textContrast') {
            for (final violation in signature) {
              final match = _contrastEntry.firstMatch(violation);
              expect(
                match,
                isNotNull,
                reason: '$key: unexpected violation $violation',
              );
              final label = match!.group(1)!;
              capture ??= await SceneCapture.take(tester);
              final resolved = resolvedTextContrast(tester, label, capture);
              for (final r in resolved) {
                // Informational: the sampled value may be an edge-shade artefact.
                // ignore: avoid_print
                print(
                  'CONTRAST $key "$label" sampled=${match.group(2)} '
                  'resolved=${r.ratio.toStringAsFixed(2)} '
                  '${hexRgb(r.text)} on ${hexRgb(r.background)} min=${r.minimum}',
                );
                expect(
                  r.ratio,
                  greaterThanOrEqualTo(r.minimum),
                  reason:
                      '$key "$label" ${hexRgb(r.text)} on ${hexRgb(r.background)}',
                );
              }
            }
            continue;
          }
          final expected = knownBaselineFailures[key];
          if (expected == null) {
            expect(result.passed, isTrue, reason: '$key regressed: ${result.reason}');
          } else {
            expect(result.passed, isFalse, reason: '$key now passes: remove it from knownBaselineFailures');
            expect(signature, expected, reason: '$key fails differently than the baseline');
          }
        }
        await handle.dispose(tester);
        semantics.dispose();
      });
    }
  }
}
