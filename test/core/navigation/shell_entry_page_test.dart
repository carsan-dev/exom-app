// L5-D3 · Inicio under the splash (contract L5-D3, «Arquitectura»): the main
// ShellRoute page appears at once only when it is created during the V4d
// hand-off; otherwise it keeps the app's push transition. Inicio's entrance
// and the header landing never rebuild Inicio when the opening ends.
import 'dart:async';

import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_handoff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

double _visibleOpacity(WidgetTester tester, Finder target) {
  var opacity = 1.0;
  for (final fade in tester.widgetList<FadeTransition>(
    find.ancestor(of: target, matching: find.byType(FadeTransition)),
  )) {
    opacity *= fade.opacity.value;
  }
  return opacity;
}

/// [appLogin]: `/b` is the app's login page ([loginRoutePage], its 600 ms
/// fade) instead of a plain `builder` route.
Future<GoRouter> _mount(WidgetTester tester, {bool appLogin = false}) async {
  final router = GoRouter(
    initialLocation: '/a',
    routes: [
      GoRoute(
        path: '/a',
        builder: (_, _) => const Scaffold(body: Text('splash')),
      ),
      if (appLogin)
        GoRoute(
          path: '/b',
          pageBuilder: (_, state) => loginRoutePage(
            key: state.pageKey,
            child: const Scaffold(body: Text('login')),
          ),
        )
      else
        GoRoute(
          path: '/b',
          builder: (_, _) => const Scaffold(body: Text('login')),
        ),
      ShellRoute(
        pageBuilder: (context, state, child) => ShellEntryPage<void>(
          key: state.pageKey,
          child: V4dHomeEntrance(child: child),
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.dark),
  );
  return router;
}

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  tearDown(V4dHandoff.reset);

  testWidgets('created during the hand-off: Inicio is fully shown at once', (
    tester,
  ) async {
    final router = await _mount(tester);
    V4dHandoff.current.value = const V4dOpening(
      elapsed: 0,
      centre: Offset(200, 300),
      reduced: false,
    );
    router.go('/');
    await tester.pump();
    expect(find.text('home'), findsOneWidget);
    expect(_visibleOpacity(tester, find.text('home')), 1);
  });

  testWidgets('outside the hand-off it keeps the push transition', (
    tester,
  ) async {
    final router = await _mount(tester);
    router.go('/');
    await tester.pump();
    // First frame offstage (hero measurement), then mid-transition.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('home'), findsOneWidget);
    expect(_visibleOpacity(tester, find.text('home')), lessThan(1));
    await tester.pumpAndSettle();
    expect(_visibleOpacity(tester, find.text('home')), 1);
  });

  // r5, review follow-up 3: only the entry during the hand-off is instant.
  // Once in, a shell created during the hand-off leaves (popped, or replaced
  // by another route, as on logout) exactly like one created outside it.
  for (final (exit, enter, leave)
      in <(String, void Function(GoRouter), void Function(GoRouter))>[
        ('popped', (router) => router.push('/'), (router) => router.pop()),
        (
          'back to the route below',
          (router) => router.push('/'),
          (router) => router.go('/a'),
        ),
        (
          'replaced by a new route (logout)',
          (router) => router.go('/'),
          (router) => router.go('/b'),
        ),
      ]) {
    testWidgets('created during the hand-off, $exit: same exit as outside '
        'the hand-off', (tester) async {
      Future<List<String>> trace({required bool handOff}) async {
        final router = await _mount(tester);
        if (handOff) {
          V4dHandoff.current.value = const V4dOpening(
            elapsed: 0,
            centre: Offset(200, 300),
            reduced: false,
          );
        }
        enter(router);
        await tester.pumpAndSettle();
        V4dHandoff.reset();
        await tester.pumpAndSettle();
        expect(_visibleOpacity(tester, find.text('home')), 1);
        leave(router);
        final frames = <String>[];
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final home = find.text('home');
          frames.add(
            home.evaluate().isEmpty
                ? 'gone'
                : '${_visibleOpacity(tester, home).toStringAsFixed(3)} '
                      '${tester.getRect(home)}',
          );
        }
        await tester.pumpWidget(const SizedBox());
        return frames;
      }

      final normal = await trace(handOff: false);
      final handedOff = await trace(handOff: true);
      // The exit is animated at all (otherwise the comparison proves little).
      expect(normal.toSet().length, greaterThan(2), reason: '$normal');
      expect(handedOff, normal);
    });
  }

  // r6, D3r5-E1 (emulator: after a start with hand-off, logging out showed
  // the login almost without its fade). Logout replaces the shell with the
  // app's login page: frame by frame, the login's fade and the shell under it
  // are the same whether the shell was created during the hand-off or not.
  testWidgets('created during the hand-off, logout to the app login: the '
      'login fades in as outside the hand-off', (tester) async {
    Future<List<String>> trace({required bool handOff}) async {
      final router = await _mount(tester, appLogin: true);
      if (handOff) {
        V4dHandoff.current.value = const V4dOpening(
          elapsed: 0,
          centre: Offset(200, 300),
          reduced: false,
        );
      }
      router.go('/');
      await tester.pumpAndSettle();
      V4dHandoff.reset();
      await tester.pumpAndSettle();
      router.go('/b');
      final frames = <String>[];
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final login = find.text('login');
        final home = find.text('home');
        frames.add(
          '${login.evaluate().isEmpty ? '-' : _visibleOpacity(tester, login).toStringAsFixed(3)} '
          '${home.evaluate().isEmpty ? 'gone' : '${_visibleOpacity(tester, home).toStringAsFixed(3)} ${tester.getRect(home)}'}',
        );
      }
      await tester.pumpWidget(const SizedBox());
      return frames;
    }

    final normal = await trace(handOff: false);
    final handedOff = await trace(handOff: true);
    // The 600 ms fade is there at all: many intermediate frames.
    final fade = normal.map((f) => f.split(' ').first).toSet();
    expect(fade.length, greaterThan(20), reason: '$normal');
    expect(normal.last.split(' ').first, '1.000');
    expect(handedOff, normal);
  });

  testWidgets('entrance scales Inicio 1.06 → 1 and keeps its state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: V4dHomeEntrance(child: _Probe())),
    );
    final state = tester.state(find.byType(_Probe));
    Matrix4 transform() => tester
        .widget<Transform>(
          find
              .ancestor(
                of: find.byType(_Probe),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform;
    expect(transform(), Matrix4.identity());
    V4dHandoff.current.value = const V4dOpening(
      elapsed: 0,
      centre: Offset(100, 100),
      reduced: false,
    );
    await tester.pump();
    expect(transform().getMaxScaleOnAxis(), closeTo(1.06, 1e-9));
    V4dHandoff.current.value = null;
    await tester.pump();
    expect(transform(), Matrix4.identity());
    expect(tester.state(find.byType(_Probe)), same(state));
  });

  testWidgets('header logo lands 440 ms into the opening', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V4dHeaderLanding(child: Text('logo'))),
    );
    double opacity() => tester
        .widget<Opacity>(
          find.ancestor(of: find.text('logo'), matching: find.byType(Opacity)),
        )
        .opacity;
    expect(opacity(), 1);
    for (final (elapsed, expected) in const [
      (0.0, 0.0),
      (440.0, 0.0),
      (500.0, 0.5),
      (560.0, 1.0),
    ]) {
      V4dHandoff.current.value = V4dOpening(
        elapsed: elapsed,
        centre: Offset.zero,
        reduced: false,
      );
      await tester.pump();
      expect(opacity(), closeTo(expected, 1e-9), reason: '$elapsed ms');
    }
    V4dHandoff.current.value = null;
    await tester.pump();
    expect(opacity(), 1);
  });

  // r3, D3-Q6: the opening waits until Inicio has painted content. MainShell
  // reports it with this call and predicate (as the probe of
  // splash_page_timing_test.dart does): only the states with Inicio's data
  // count, only during a hand-off, and only after the frame that paints them.
  test('Inicio content: only the states with its data', () {
    final day = DateTime(2026, 11, 25);
    expect(isInicioContent(const HomeInitial()), isFalse);
    expect(isInicioContent(const HomeLoading()), isFalse);
    expect(isInicioContent(const HomeError('offline')), isFalse);
    expect(
      isInicioContent(HomeLoaded(const HomeSummaryEntity(), selectedDate: day)),
      isTrue,
    );
    expect(
      isInicioContent(
        HomeRestDay(
          const HomeSummaryEntity(isRestDay: true),
          selectedDate: day,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('Inicio content is reported after the frame that paints it, '
      'only during a hand-off', (tester) async {
    final states = StreamController<HomeState>.broadcast();
    addTearDown(states.close);
    await tester.pumpWidget(const SizedBox());

    // Outside a hand-off nothing is watched.
    expect(
      V4dHandoff.watchInicioContent(() => states.stream, isInicioContent),
      isNull,
    );

    V4dHandoff.current.value = const V4dOpening(
      elapsed: -1,
      centre: Offset.zero,
      reduced: false,
    );
    final watch = V4dHandoff.watchInicioContent(
      () => states.stream,
      isInicioContent,
    );
    addTearDown(() => watch?.cancel());
    expect(watch, isNotNull);

    states.add(const HomeLoading());
    await tester.pump();
    expect(V4dHandoff.inicioContent.value, isFalse);

    states.add(
      HomeLoaded(const HomeSummaryEntity(), selectedDate: DateTime(2026)),
    );
    await null;
    // Seen, but not painted yet: reported at the end of the next frame.
    expect(V4dHandoff.inicioContent.value, isFalse);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump();
    expect(V4dHandoff.inicioContent.value, isTrue);

    V4dHandoff.reset();
    expect(V4dHandoff.inicioContent.value, isFalse);
  });
}
