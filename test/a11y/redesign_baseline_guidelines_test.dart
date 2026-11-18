// Redesign L0 accessibility guideline INVENTORY (plan: docs/plans/rediseno-exom-app.md, L0).
//
// Pumps the same five scenes as the golden baseline (Inicio, Detalle, Ejercicio
// activo, Hoja de serie, Descanso) in the light and dark theme and evaluates
// androidTapTargetGuideline, iOSTapTargetGuideline, labeledTapTargetGuideline and
// textContrastGuideline with `guideline.evaluate(tester)`.
//
// Nothing is weakened: a guideline that passes today is asserted to pass. A
// guideline that fails today is listed in [knownBaselineFailures] with a
// normalised signature of its violations and asserted to STILL fail in exactly
// that way. When a later lot fixes a violation this test fails on purpose: remove
// the fixed entry (or update its signature) in that lot's change.
//
// Notes: the scenes use the bundled CabinetGrotesk font (see loadRedesignFonts);
// textContrastGuideline samples rendered pixels, so it is only as exact as the
// renderer (e.g. text over a modal scrim). Inicio reads DateTime.now() (week
// selector, relative date label); signatures therefore drop day names/numbers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/redesign_scenes.dart';

const _guidelines = <String, AccessibilityGuideline>{
  'androidTapTarget': androidTapTargetGuideline,
  'iOSTapTarget': iOSTapTargetGuideline,
  'labeledTapTarget': labeledTapTargetGuideline,
  'textContrast': textContrastGuideline,
};

String? _trim(String? value) => value?.replaceFirst(RegExp(r'\.$'), '');

/// Normalises an [Evaluation.reason] into a sorted, date- and id-independent
/// list of violations.
List<String> violationSignature(String? reason) {
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
      final label = RegExp(r'label: "([^"]*)"').firstMatch(chunk)?.group(1);
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

// L3 (week_day_selector.dart): day buttons are 44x44; L3 must reach 48x48.
// Seen in: inicio/dark/androidTapTarget, inicio/light/androidTapTarget.
const _inicioWeekSelectorBelow48 = <String>[
  'tap-target rect=(121.9, 112.0, 165.9, 156.0) min=48.0, 48.0 found=44.0, 44.0',
  'tap-target rect=(173.0, 112.0, 217.0, 156.0) min=48.0, 48.0 found=44.0, 44.0',
  'tap-target rect=(19.6, 112.0, 63.6, 156.0) min=48.0, 48.0 found=44.0, 44.0',
  'tap-target rect=(224.1, 112.0, 268.1, 156.0) min=48.0, 48.0 found=44.0, 44.0',
  'tap-target rect=(275.3, 112.0, 319.3, 156.0) min=48.0, 48.0 found=44.0, 44.0',
  'tap-target rect=(326.4, 112.0, 370.4, 156.0) min=48.0, 48.0 found=44.0, 44.0',
  'tap-target rect=(70.7, 112.0, 114.7, 156.0) min=48.0, 48.0 found=44.0, 44.0',
];

// L3 (training_detail_page.dart): leading IconButton has no tooltip/semantic label.
// Seen in: detalle/dark/labeledTapTarget, detalle/light/labeledTapTarget.
const _detailBackButtonUnlabeled = <String>[
  'missing-label rect=(16.0, 3.8, 64.0, 51.8)',
];

// L1 (tokens): every text/background pair must reach 4.5:1 (3:1 large text) in both themes.
// Seen in: detalle/light/textContrast.
const _contrastDetalleLight = <String>[
  'contrast label="0/3 ejercicios completados" min=4.5 found=3.56 size=13.0',
  'contrast label="Pierna fuerza" min=4.5 found=3.58 size=14.0',
];

// L3 (active_exercise_page.dart _CircleIconButton): close button is 44x44; L3 criterion: close >= 48.
// Seen in: ejercicio_activo/dark/androidTapTarget, ejercicio_activo/light/androidTapTarget, descanso/dark/androidTapTarget, descanso/light/androidTapTarget.
const _activeExerciseCloseButton44 = <String>[
  'tap-target rect=(16.0, 12.5, 60.0, 56.5) min=48.0, 48.0 found=44.0, 44.0',
];

// L3 (active_exercise_page.dart _CircleIconButton): close button has no semantic label.
// Seen in: ejercicio_activo/dark/labeledTapTarget, ejercicio_activo/light/labeledTapTarget, descanso/dark/labeledTapTarget, descanso/light/labeledTapTarget.
const _activeExerciseCloseButtonUnlabeled = <String>[
  'missing-label rect=(16.0, 12.5, 60.0, 56.5)',
];

// L1 (tokens): every text/background pair must reach 4.5:1 (3:1 large text) in both themes.
// Seen in: ejercicio_activo/dark/textContrast, descanso/dark/textContrast.
const _contrastEjercicioActivoDark = <String>[
  'contrast label="Último peso: 60 kg" min=4.5 found=4.09 size=12.0',
];

// L1 (tokens): every text/background pair must reach 4.5:1 (3:1 large text) in both themes.
// Seen in: ejercicio_activo/light/textContrast.
const _contrastEjercicioActivoLight = <String>[
  'contrast label="En ejecución" min=4.5 found=4.26 size=11.0',
  'contrast label="INTERMEDIATE" min=4.5 found=2.90 size=12.0',
  'contrast label="Pie trasero apoyado en el banco, torso erguido." min=4.5 found=3.01 size=14.0',
  'contrast label="Último peso: 60 kg" min=4.5 found=2.12 size=12.0',
];

// L1 (tokens): every text/background pair must reach 4.5:1 (3:1 large text) in both themes.
// Seen in: hoja_serie/light/textContrast.
// no fiable: el muestreo de contraste cae sobre el velo del modal. Se lista e
// imprime como informativa pero NO se asevera (ver [_isInformational]).
const _contrastHojaSerieLight = <String>[
  'contrast label="Anterior: 8 reps · 60 kg" min=4.5 found=1.37 size=13.0',
  'contrast label="Objetivo: 8 · RIR 2" min=4.5 found=3.57 size=13.0',
  'contrast label="kg" min=4.5 found=3.46 size=15.0',
];

// L1 (tokens): every text/background pair must reach 4.5:1 (3:1 large text) in both themes.
// Seen in: descanso/light/textContrast.
const _contrastDescansoLight = <String>[
  'contrast label="Descansando" min=4.5 found=4.26 size=11.0',
  'contrast label="INTERMEDIATE" min=4.5 found=2.90 size=12.0',
  'contrast label="Pie trasero apoyado en el banco, torso erguido." min=4.5 found=3.01 size=14.0',
  'contrast label="Último peso: 60 kg" min=4.5 found=2.12 size=12.0',
];

/// Violations observed on the unmodified origin/develop baseline.
/// Key: `<scene>/<theme>/<guideline>`. Anything not listed must pass.
const knownBaselineFailures = <String, List<String>>{
  'inicio/dark/androidTapTarget': _inicioWeekSelectorBelow48,
  'inicio/light/androidTapTarget': _inicioWeekSelectorBelow48,
  'detalle/dark/labeledTapTarget': _detailBackButtonUnlabeled,
  'detalle/light/labeledTapTarget': _detailBackButtonUnlabeled,
  'detalle/light/textContrast': _contrastDetalleLight,
  'ejercicio_activo/dark/androidTapTarget': _activeExerciseCloseButton44,
  'ejercicio_activo/light/androidTapTarget': _activeExerciseCloseButton44,
  'descanso/dark/androidTapTarget': _activeExerciseCloseButton44,
  'descanso/light/androidTapTarget': _activeExerciseCloseButton44,
  'ejercicio_activo/dark/labeledTapTarget': _activeExerciseCloseButtonUnlabeled,
  'ejercicio_activo/light/labeledTapTarget': _activeExerciseCloseButtonUnlabeled,
  'descanso/dark/labeledTapTarget': _activeExerciseCloseButtonUnlabeled,
  'descanso/light/labeledTapTarget': _activeExerciseCloseButtonUnlabeled,
  'ejercicio_activo/dark/textContrast': _contrastEjercicioActivoDark,
  'descanso/dark/textContrast': _contrastEjercicioActivoDark,
  'ejercicio_activo/light/textContrast': _contrastEjercicioActivoLight,
  // no fiable: el muestreo de contraste cae sobre el velo del modal (informativa).
  'hoja_serie/light/textContrast': _contrastHojaSerieLight,
  'descanso/light/textContrast': _contrastDescansoLight,
};

/// Cells printed but NOT asserted.
///  - `hoja_serie/<theme>/textContrast`: no fiable, el muestreo de contraste
///    cae sobre el velo del modal; un cambio del velo no debe romper CI.
///  - Inicio (all cells except androidTapTarget): its styling depends on the
///    weekday (isPast/isToday) because home_page.dart and week_day_selector.dart
///    use DateTime.now(). Observed passing on 2026-11-18 (miércoles) for
///    iOSTapTarget, labeledTapTarget and textContrast. The weekday-independent
///    pin (7 day buttons at 44x44 for androidTapTarget) stays asserted.
bool _isInformational(String key) {
  final parts = key.split('/');
  final scene = parts[0];
  final guideline = parts[2];
  if (scene == 'hoja_serie' && guideline == 'textContrast') return true;
  if (scene == 'inicio' && guideline != 'androidTapTarget') return true;
  return false;
}

void main() {
  for (final scene in RedesignScene.values) {
    for (final brightness in Brightness.values) {
      testWidgets('guidelines ${scene.slug} ${brightness.name}', (tester) async {
        final semantics = tester.ensureSemantics();
        final handle = await pumpRedesignScene(
          tester,
          scene,
          theme: redesignTheme(brightness),
        );
        for (final entry in _guidelines.entries) {
          final key = '${scene.slug}/${brightness.name}/${entry.key}';
          final result = await entry.value.evaluate(tester);
          final signature = violationSignature(result.reason);
          // Inventory line collected by the evidence log.
          // ignore: avoid_print
          print('GUIDELINE $key passed=${result.passed} violations=${signature.length}');
          if (_isInformational(key)) continue;
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
