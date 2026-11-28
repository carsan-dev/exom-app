// Redesign L6 criteria S11-04 (contrast) and P14 (touch targets >= 48 dp).
//
// For the main screens (Inicio, Detalle with its footer, set sheet, Recap,
// Progreso, Retos, Dietas, Ajustes and Inicio de sesion) in the light and dark
// theme it asserts `androidTapTargetGuideline` and the contrast of every text
// `textContrastGuideline` reports. Nothing is excluded or relaxed: any
// violation fails the test.
//
// textContrastGuideline samples rendered pixels and can measure an
// anti-aliasing edge shade instead of the text (see resolved_text_contrast.dart
// and redesign_baseline_guidelines_test.dart), so, like the L0 inventory, each
// label it reports is resolved deterministically from the effective style and
// the dominant background and must reach WCAG AA (4.5, or 3.0 for large text).
import 'package:exom_app/features/auth/presentation/pages/login_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/theme/wcag_contrast.dart';
import '../features/auth/presentation/pages/auth_pages_test_support.dart';
import '../features/challenges/challenges_test_support.dart';
import '../features/diets/diets_redesign_fixture.dart';
import '../features/metrics/metrics_progress_redesign_fixture.dart';
import '../features/recap/presentation/pages/recap_detail_redesign_test.dart'
    show pumpDetail, recapDetailFilled;
import '../features/settings/presentation/pages/settings_scene.dart';
import '../golden/redesign_scenes.dart';
import 'redesign_baseline_guidelines_test.dart' show violationSignature;
import 'resolved_text_contrast.dart';

final _contrastEntry = RegExp(r'^contrast label="(.*)" min=\S+ found=(\S+) size=');

/// Asserts the P14 and S11-04 guidelines on the screen currently pumped.
Future<void> expectScreenGuidelines(WidgetTester tester, String key) async {
  final tap = await androidTapTargetGuideline.evaluate(tester);
  expect(tap.passed, isTrue, reason: '$key androidTapTarget: ${tap.reason}');

  final contrast = await textContrastGuideline.evaluate(tester);
  final signature = violationSignature(
    contrast.reason,
    textOfNode: (id) => guidelineTextOfNode(tester, id),
  );
  SceneCapture? capture;
  for (final violation in signature) {
    final match = _contrastEntry.firstMatch(violation);
    expect(match, isNotNull, reason: '$key: unexpected violation $violation');
    final label = match!.group(1)!;
    capture ??= await SceneCapture.take(tester);
    final resolved = resolvedTextContrast(tester, label, capture);
    for (final r in resolved) {
      expect(
        r.ratio,
        greaterThanOrEqualTo(r.minimum),
        reason: '$key "$label" ${hexRgb(r.text)} on ${hexRgb(r.background)}',
      );
    }
  }
}

void main() {
  tearDown(() async => sl.reset());

  for (final brightness in Brightness.values) {
    final mode = brightness.name;

    for (final scene in const [
      RedesignScene.inicio,
      RedesignScene.detalle,
      RedesignScene.detalleEnCurso,
      RedesignScene.hojaSerie,
    ]) {
      testWidgets('a11y ${scene.slug} $mode', (tester) async {
        final semantics = tester.ensureSemantics();
        final handle = await pumpRedesignScene(
          tester,
          scene,
          theme: redesignTheme(brightness),
        );
        await expectScreenGuidelines(tester, '${scene.slug}/$mode');
        await handle.dispose(tester);
        semantics.dispose();
      });
    }

    testWidgets('a11y recap_detalle $mode', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDetail(
        tester,
        extra: recapDetailFilled,
        dark: brightness == Brightness.dark,
        width: 390,
        height: 2400,
      );
      await expectScreenGuidelines(tester, 'recap_detalle/$mode');
      semantics.dispose();
    });

    testWidgets('a11y progreso $mode', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpProgressScene(tester, brightness: brightness, height: 2400);
      await expectScreenGuidelines(tester, 'progreso/$mode');
      semantics.dispose();
    });

    testWidgets('a11y retos $mode', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpChallengesPage(
        tester,
        FakeChallengesRepository(),
        height: 2400,
        mode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      );
      await expectScreenGuidelines(tester, 'retos/$mode');
      semantics.dispose();
    });

    testWidgets('a11y dietas $mode', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDietsScene(tester, brightness: brightness, height: 2400);
      await expectScreenGuidelines(tester, 'dietas/$mode');
      semantics.dispose();
    });

    testWidgets('a11y ajustes $mode', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSettingsScene(tester, brightness: brightness, height: 2400);
      await expectScreenGuidelines(tester, 'ajustes/$mode');
      semantics.dispose();
    });

    testWidgets('a11y login $mode', (tester) async {
      final semantics = tester.ensureSemantics();
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      await pumpAuthPage(
        tester,
        const LoginPage(),
        bloc: bloc,
        brightness: brightness,
        disableAnimations: true,
      );
      await expectScreenGuidelines(tester, 'login/$mode');
      semantics.dispose();
    });
  }
}
