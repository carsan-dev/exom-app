// L5-F2-ICONOS drawer goldens (contract CC 8): the open menu with Retos marked
// (variant B of the sketch) in dark and light at text scale 1.0 and 1.6 on the
// 390x844 surface of the L0 baseline. Inherited F2 gap: the drawer had none.
//
// Generated on Windows with the bundled fonts (loadRedesignFonts); regenerate
// on the same OS with:
//   flutter test --update-goldens test/golden/l5_f2_menu_golden_test.dart
import 'dart:math' as math;

import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
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

double _ratio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name = 'menu_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        final keys = List.generate(7, (_) => GlobalKey());
        final router = GoRouter(
          initialLocation: AppRoutes.challenges,
          routes: [
            GoRoute(
              path: '/:rest(.*)',
              builder: (context, _) => Scaffold(
                endDrawer: AppDrawer(
                  drawerItemKeys: keys,
                  displayName: 'Marta Ruiz',
                ),
                body: Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    child: const Text('open'),
                  ),
                ),
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
                child: RepaintBoundary(
                  key: const Key('golden-root'),
                  child: app!,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        expect(
          _ratio(palette.textSecondary, palette.background),
          greaterThan(4.5),
        );
        expect(
          _ratio(palette.textPrimary, palette.background),
          greaterThan(4.5),
        );
        expect(
          find.byKey(const Key('exom-index-selected-rule')),
          findsOneWidget,
        );
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(
          find.byKey(const Key('golden-root')),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
