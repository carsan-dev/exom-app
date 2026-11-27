// L5-F3 «Tutorial» goldens (contract CC 8; f-resto.html frames f3-aviso,
// f3-paso-nav, f3-paso-hdr and f3-paso-menu): the quick-tour prompt (with the
// «No volver a mostrar» row, as the shell shows it) and the tour bubble at
// step 02 (bottom bar), 06 (header) and 08 (inside the real drawer, last
// step), in dark and light at text scale 1.0 and 1.6 on the 390x844 surface of
// the L0 baseline, Spanish.
//
// Generated on Windows with the bundled fonts (loadRedesignFonts); regenerate
// on the same OS with:
//   flutter test --update-goldens test/golden/l5_f3_tutorial_golden_test.dart
@Tags(['golden'])
library;

import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/tutorial_overlay.dart';
import 'package:exom_app/core/widgets/tutorial_prompt_dialog.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/exom_component_harness.dart';
import '../core/widgets/expect_no_lime_ink.dart';
import 'redesign_scenes.dart' show loadRedesignFonts;

class _Auth extends Fake implements AuthBloc {
  @override
  AuthState get state => AuthInitial();

  @override
  Stream<AuthState> get stream => const Stream<AuthState>.empty();

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() async {}
}

String _scaleName(double scale) => scale == 1.0 ? '1_0x' : '1_6x';

/// The shell as the tour sees it: a Scaffold with the real drawer, and the
/// overlay above it in a Stack (as `MainShell` mounts it).
Future<void> _pumpShell(
  WidgetTester tester, {
  required Brightness brightness,
  required double scale,
  required Widget Function(GlobalKey<ScaffoldState>, List<GlobalKey>) top,
}) async {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final keys = List.generate(7, (_) => GlobalKey());
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: '/:rest(.*)',
        builder: (context, _) => Stack(
          children: [
            Scaffold(
              key: scaffoldKey,
              endDrawer: AppDrawer(
                drawerItemKeys: keys,
                displayName: 'Marta Ruiz',
              ),
              body: const SizedBox.expand(),
            ),
            top(scaffoldKey, keys),
          ],
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await loadRedesignFonts();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: _Auth(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: themeFor(brightness),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: const Key('golden-root'), child: app!),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectGolden(
  WidgetTester tester,
  Brightness brightness,
  String name,
) async {
  expectNoOverflow(tester);
  if (brightness == Brightness.light) expectNoLimeInk(tester);
  await expectLater(
    find.byKey(const Key('golden-root')),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final suffix = '${brightness.name}_${_scaleName(scale)}';

      testWidgets('golden tutorial_aviso_$suffix', (tester) async {
        await _pumpShell(
          tester,
          brightness: brightness,
          scale: scale,
          top: (_, _) => TutorialPromptDialog(
            redesigned: true,
            icon: null,
            onStart: () {},
            onSkip: () {},
            onDontShowAgainChanged: (_) {},
          ),
        );
        await expectTapTargetGuidelines(tester);
        await _expectGolden(tester, brightness, 'tutorial_aviso_$suffix');
      });

      // Steps 02 (bottom bar), 06 (header) and 08 (drawer, last).
      for (final (step, frame) in const [(2, 'nav'), (6, 'hdr'), (8, 'menu')]) {
        testWidgets('golden tutorial_paso_${frame}_$suffix', (tester) async {
          await _pumpShell(
            tester,
            brightness: brightness,
            scale: scale,
            top: (scaffoldKey, keys) => TutorialOverlay(
              onNavigate: (_) {},
              onOpenDrawer: () => scaffoldKey.currentState?.openEndDrawer(),
              onCloseDrawer: () {},
              onComplete: () {},
              drawerItemKeys: keys,
            ),
          );
          for (var i = 1; i < step; i++) {
            await tester.tap(find.byType(ExomPrimaryButton));
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pumpAndSettle();
          }
          await _expectGolden(
            tester,
            brightness,
            'tutorial_paso_${frame}_$suffix',
          );
        });
      }
    }
  }
}
