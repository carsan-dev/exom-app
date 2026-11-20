// T0.5 M1 and M2 wiring: the page transitions the app theme gives to
// `MaterialPageRoute` / `MaterialPage` (Android: EXOM push; iOS: Cupertino,
// with its back gesture) and the tab pages of the router's `ShellRoute`.
import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pageA = Key('page-a');
const _pageB = Key('page-b');
const _push = Key('push');
const _pop = Key('pop');

/// Product of every opacity applied above [finder] (FadeTransition and
/// Opacity), i.e. how opaque the page is painted.
double _effectiveOpacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final widget in tester.widgetList<Widget>(
    find.ancestor(
      of: finder,
      matching: find.byWidgetPredicate((_) => true, skipOffstage: false),
    ),
  )) {
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    if (widget is Opacity) opacity *= widget.opacity;
  }
  return opacity;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  bool reduced = false,
  VoidCallback? onPop,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      // Built after the platform override, so `ThemeData.platform` follows it.
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          key: _pageA,
          body: Center(
            child: TextButton(
              key: _push,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    key: _pageB,
                    body: Center(
                      child: TextButton(
                        key: _pop,
                        onPressed: () {
                          onPop?.call();
                          Navigator.of(context).pop();
                        },
                        child: const Text('B'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('A'),
            ),
          ),
        ),
      ),
    ),
  );
}

PageRoute<dynamic> _routeOf(WidgetTester tester, Finder finder) =>
    ModalRoute.of(tester.element(finder))! as PageRoute<dynamic>;

void main() {
  group('M1 push and back on Android (PageTransitionsTheme)', () {
    testWidgets('MaterialPageRoute: 240 ms in, 200 ms back, 24 dp + fade, '
        'previous page at 60 %', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pumpApp(tester);
        await tester.tap(find.byKey(_push));
        await tester.pump();

        final route = _routeOf(tester, find.byKey(_pageB, skipOffstage: false));
        expect(route.transitionDuration, const Duration(milliseconds: 240));
        expect(
          route.reverseTransitionDuration,
          const Duration(milliseconds: 200),
        );

        // The first frame is laid out offstage (heroes); 1 ms later the page
        // starts 24 dp to the right and almost transparent.
        await tester.pump(const Duration(milliseconds: 1));
        expect(tester.getTopLeft(find.byKey(_pageB)).dx, closeTo(24, 1));
        expect(_effectiveOpacity(tester, find.byKey(_pageB)), lessThan(0.05));

        await tester.pump(const Duration(milliseconds: 120));
        final midDx = tester
            .getTopLeft(find.byKey(_pageB, skipOffstage: false))
            .dx;
        expect(midDx, greaterThan(0));
        expect(midDx, lessThan(24));
        final midOpacity = _effectiveOpacity(
          tester,
          find.byKey(_pageB, skipOffstage: false),
        );
        expect(midOpacity, greaterThan(0));
        expect(midOpacity, lessThan(1));
        // L5-D35: at 121 ms the entry follows Curves.easeOutCubic (offset,
        // fade, and the dimming of the covered page).
        final t = route.animation!.value;
        expect(t, closeTo(121 / 240, 1e-3));
        final eased = Curves.easeOutCubic.transform(t);
        expect(midDx, closeTo(24 * (1 - eased), 0.05));
        expect(midOpacity, closeTo(eased, 1e-3));
        expect(
          _effectiveOpacity(tester, find.byKey(_pageA, skipOffstage: false)),
          closeTo(1 - 0.4 * eased, 1e-3),
        );

        await tester.pump(const Duration(milliseconds: 120));
        expect(
          tester.getTopLeft(find.byKey(_pageB, skipOffstage: false)).dx,
          0,
        );
        expect(
          _effectiveOpacity(tester, find.byKey(_pageB, skipOffstage: false)),
          1,
        );
        // The previous page is dimmed to 60 %.
        expect(
          _effectiveOpacity(tester, find.byKey(_pageA, skipOffstage: false)),
          closeTo(0.6, 1e-6),
        );

        // Back: 200 ms, inverse.
        await tester.tap(find.byKey(_pop));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final backDx = tester
            .getTopLeft(find.byKey(_pageB, skipOffstage: false))
            .dx;
        expect(backDx, greaterThan(0));
        expect(backDx, lessThan(24));
        await tester.pump(const Duration(milliseconds: 100));
        expect(_effectiveOpacity(tester, find.byKey(_pageB)), closeTo(0, 1e-6));
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.byKey(_pageB, skipOffstage: false), findsNothing);
        expect(_effectiveOpacity(tester, find.byKey(_pageA)), 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('reduced motion: 100 ms fade, no offset, no dimming', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pumpApp(tester, reduced: true);
        await tester.tap(find.byKey(_push));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(tester.getTopLeft(find.byKey(_pageB)).dx, 0);
        expect(_effectiveOpacity(tester, find.byKey(_pageB)), lessThan(0.05));

        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.getTopLeft(find.byKey(_pageB, skipOffstage: false)).dx,
          0,
        );
        final half = _effectiveOpacity(
          tester,
          find.byKey(_pageB, skipOffstage: false),
        );
        expect(half, greaterThan(0));
        expect(half, lessThan(1));

        await tester.pump(const Duration(milliseconds: 50));
        expect(
          _effectiveOpacity(tester, find.byKey(_pageB, skipOffstage: false)),
          1,
        );
        expect(
          _effectiveOpacity(tester, find.byKey(_pageA, skipOffstage: false)),
          1,
        );
        await tester.pumpAndSettle();

        // Back: fully faded out after 100 ms.
        await tester.tap(find.byKey(_pop));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          _effectiveOpacity(tester, find.byKey(_pageB, skipOffstage: false)),
          closeTo(0, 1e-6),
        );
        expect(
          tester.getTopLeft(find.byKey(_pageB, skipOffstage: false)).dx,
          0,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(_pageB, skipOffstage: false), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a tap during the push acts at once (interruptible)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var pops = 0;
        await _pumpApp(tester, onPop: () => pops++);
        await tester.tap(find.byKey(_push));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(find.byKey(_pop));
        expect(pops, 1);
        await tester.pumpAndSettle();
        expect(find.byKey(_pageB, skipOffstage: false), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('M1 interrupted push', () {
    for (final reduced in [false, true]) {
      testWidgets('back at 60 ms reverses from where the page is, without a '
          'jump (reduced: $reduced)', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await _pumpApp(tester, reduced: reduced);
          await tester.tap(find.byKey(_push));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          final page = find.byKey(_pageB, skipOffstage: false);
          final dxBefore = tester.getTopLeft(page).dx;
          final opacityBefore = _effectiveOpacity(tester, page);
          expect(opacityBefore, inExclusiveRange(0, 1));

          await tester.tap(find.byKey(_pop), warnIfMissed: false);
          await tester.pump();
          final dxAfter = tester.getTopLeft(page).dx;
          final opacityAfter = _effectiveOpacity(tester, page);
          debugPrint(
            'PUSH interrupt (reduced: $reduced): dx $dxBefore -> $dxAfter, '
            'opacity $opacityBefore -> $opacityAfter',
          );
          expect((dxAfter - dxBefore).abs(), lessThan(1.5));
          expect((opacityAfter - opacityBefore).abs(), lessThan(0.1));

          await tester.pumpAndSettle();
          expect(page, findsNothing);
          expect(_effectiveOpacity(tester, find.byKey(_pageA)), 1);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  });

  group('M1 on iOS keeps Cupertino (R3)', () {
    testWidgets('MaterialPageRoute keeps the Cupertino transition and the '
        'back swipe', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await _pumpApp(tester);
        await tester.tap(find.byKey(_push));
        await tester.pump();
        expect(
          find.ancestor(
            of: find.byKey(_pageB, skipOffstage: false),
            matching: find.byType(CupertinoPageTransition, skipOffstage: false),
          ),
          findsOneWidget,
        );
        await tester.pumpAndSettle();

        // Edge swipe back.
        final gesture = await tester.startGesture(const Offset(5, 400));
        await gesture.moveBy(const Offset(300, 0));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(_pageB, skipOffstage: false), findsNothing);
        expect(find.byKey(_pageA), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('M2 router wiring (app_router.dart)', () {
    final source = File(
      'lib/core/navigation/app_router.dart',
    ).readAsStringSync();
    final shellStart = source.indexOf('ShellRoute(');
    final shellEnd = source.indexOf('// Training detail', shellStart);
    final shell = source.substring(shellStart, shellEnd);

    test('the five shell tabs use the M2 crossfade page, keyed by route', () {
      expect(shell, isNot(contains('NoTransitionPage')));
      expect('ExomTabPage('.allMatches(shell).length, 5);
      expect('key: state.pageKey'.allMatches(shell).length, 5);
    });

    test('login keeps its 600 ms fade; forgot password uses the M1 page', () {
      // Owner decision 2026-11-20: login keeps the splash fade until D3;
      // forgot password is a push from login and gets M1 via _platformPage.
      expect('CustomTransitionPage('.allMatches(source).length, 1);
      expect(source, contains('Duration(milliseconds: 600)'));
      expect(source, isNot(contains('Duration(milliseconds: 320)')));
      final start = source.indexOf('path: AppRoutes.forgotPassword');
      final end = source.indexOf('path: AppRoutes.accountLocked', start);
      final forgot = source.substring(start, end);
      expect(forgot, contains('_platformPage('));
      expect(forgot, contains('key: state.pageKey'));
      expect(
        forgot,
        contains('ForgotPasswordPage(initialEmail: initialEmail)'),
      );
    });
  });
}
