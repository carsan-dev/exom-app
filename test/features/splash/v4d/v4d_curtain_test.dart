// L5-D3 r5, review follow-up 2: Inicio's content may already be reported
// when the curtain is created (V4dCurtain reads it in initState). The
// opening (or the reduced fade) must start from that content at once, not
// wait for the 600 ms cap (D3-Q6, D3-Q8).
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_curtain.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_handoff.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_scene.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(V4dHandoff.reset);

  for (final reduced in const [false, true]) {
    testWidgets('${reduced ? 'reduced motion: ' : ''}content reported before '
        'the curtain is created: the opening starts at once, not at the '
        'cap', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late Duration stamp;
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => stamp = SchedulerBinding.instance.currentFrameTimeStamp,
      );
      await tester.pumpWidget(const SizedBox());
      // Splash clock: the curtain is created at 1000 ms, the gates resolved
      // at 1000 ms (cap at 1600 ms) and Inicio's content is already there.
      const ready = 1000.0;
      final origin = stamp - const Duration(milliseconds: 1000);
      const centre = Offset(206, 457);
      V4dHandoff.current.value = const V4dOpening.waiting(
        centre: centre,
        reduced: false,
      );
      V4dHandoff.inicioContent.value = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: V4dCurtain(
            origin: origin,
            startAt: ready,
            readyAt: ready,
            centre: centre,
            reduced: reduced,
            entrySkipped: false,
            slowStart: false,
            onDone: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 10));
      final opening = V4dHandoff.current.value!;
      // Started at 1000 ms (the content), seen at 1010 ms.
      expect(opening.elapsed, closeTo(10, 1));
      if (!reduced) {
        expect(tester.widget<V4dScene>(find.byType(V4dScene)).openAt, ready);
      }
    });
  }
}
