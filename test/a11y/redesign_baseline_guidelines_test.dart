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
// resolved deterministically (see [_resolvedTextContrast]: text colour from the
// effective style, background from the dominant colour behind it) and must reach
// WCAG AA (4.5, or 3.0 for large text). A real low-contrast text fails; an
// edge-shade artefact passes on whichever label it lands on. If a reported
// label cannot be resolved the test fails, it is never skipped. An exact label
// set was dropped because it is brittle: the D11 tracking change (bodyMedium
// -0.22) moved it («0/3 ejercicios completados» and «En ejecución» stopped being
// reported; «Pie trasero…» is newly reported in ejercicio_activo dark and
// descanso dark). The sampled and resolved values are printed as informational
// lines.
// Inicio: since L3 (decision D10) the scenes fix HomePage's clock to Wednesday
// 18 Nov 2026, so every Inicio cell is asserted like the other scenes.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/theme/wcag_contrast.dart';
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

/// RGBA capture of the whole scene at 1 logical px per pixel, taken the way
/// textContrastGuideline takes it (render view layer -> toImage).
class _SceneCapture {
  _SceneCapture(this.bytes, this.width, this.height);
  final ByteData bytes;
  final int width;
  final int height;

  static Future<_SceneCapture> take(WidgetTester tester) async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    late int width;
    late int height;
    final bytes = await tester.binding.runAsync<ByteData?>(() async {
      final image = await layer.toImage(
        view.paintBounds,
        pixelRatio: 1 / view.flutterView.devicePixelRatio,
      );
      width = image.width;
      height = image.height;
      final data = await image.toByteData();
      image.dispose();
      return data;
    });
    return _SceneCapture(bytes!, width, height);
  }

  /// ARGB32 -> pixel count inside [rect] (global logical coordinates).
  Map<int, int> histogram(Rect rect) {
    final counts = <int, int>{};
    final left = rect.left.floor().clamp(0, width);
    final top = rect.top.floor().clamp(0, height);
    final right = rect.right.ceil().clamp(0, width);
    final bottom = rect.bottom.ceil().clamp(0, height);
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final o = (y * width + x) * 4;
        final argb = bytes.getUint8(o + 3) << 24 |
            bytes.getUint8(o) << 16 |
            bytes.getUint8(o + 1) << 8 |
            bytes.getUint8(o + 2);
        counts[argb] = (counts[argb] ?? 0) + 1;
      }
    }
    return counts;
  }
}

typedef _Resolved = ({
  Color text,
  Color background,
  double ratio,
  double minimum,
});

/// Resolves the real contrast of every visible `Text(label)`: the text colour
/// comes from the effective style (DefaultTextStyle merged with the widget
/// style); the background is the most frequent colour inside the text's paint
/// bounds (uncropped) in [capture]. The text colour must itself appear among
/// those pixels, which guards against resolving the wrong widget.
List<_Resolved> _resolvedTextContrast(
  WidgetTester tester,
  String label,
  _SceneCapture capture,
) {
  final elements = find.text(label).hitTestable().evaluate().toList();
  expect(elements, isNotEmpty, reason: 'no visible Text "$label"');
  final resolved = <_Resolved>[];
  for (final element in elements) {
    final widget = element.widget;
    expect(widget, isA<Text>(), reason: '"$label" is not a Text widget');
    final style =
        DefaultTextStyle.of(element).style.merge((widget as Text).style);
    expect(
      style.foreground,
      isNull,
      reason: '"$label" paints with a foreground Paint',
    );
    final text = style.color;
    expect(text, isNotNull, reason: '"$label" has no resolved text colour');
    expect(text!.a, 1.0, reason: '"$label" text colour is translucent');
    final box = element.renderObject! as RenderBox;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      box.paintBounds,
    );
    final counts = capture.histogram(rect);
    expect(
      counts[text.toARGB32()] ?? 0,
      greaterThan(0),
      reason:
          'text colour ${hexRgb(text)} of "$label" not found in its paint bounds',
    );
    final background = Color(
      counts.entries.reduce((a, b) => b.value > a.value ? b : a).key,
    );
    expect(
      background,
      isNot(text),
      reason: '"$label": the text colour dominates its own box',
    );
    resolved.add((
      text: text,
      background: background,
      ratio: contrastRatio(text, background),
      minimum: wcagAaMinimum(style.fontSize!, style.fontWeight),
    ));
  }
  return resolved;
}

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
        _SceneCapture? capture;
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
              capture ??= await _SceneCapture.take(tester);
              final resolved = _resolvedTextContrast(tester, label, capture);
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
