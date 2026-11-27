import 'dart:math' as math;

import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../golden/redesign_scenes.dart' show loadRedesignFonts;
import '../widgets/exom_component_harness.dart';
import '../widgets/expect_no_lime_ink.dart';

// L5-F2: «Recap semanal» and «Cerrar sesión» in sentence case. The six
// destinations are painted upper case (numbered index, `.x-ix`); the log-out
// button keeps its sentence case (`.btn-out`).
const _itemsEs = [
  'PERFIL',
  'RETOS',
  'RECAP SEMANAL',
  'FEEDBACK',
  'AJUSTES',
  'AYUDA',
  'Cerrar sesión',
];

class _Auth extends Fake implements AuthBloc {
  final events = <AuthEvent>[];

  @override
  AuthState get state => AuthInitial();

  @override
  Stream<AuthState> get stream => const Stream<AuthState>.empty();

  @override
  void add(AuthEvent event) => events.add(event);

  @override
  Future<void> close() async {}
}

/// Every word of the paragraph must sit on one line: nothing is split
/// mid-word.
void _expectNoWordSplit(Element element) {
  final paragraph = element.findRenderObject()! as RenderParagraph;
  final text = paragraph.text.toPlainText();
  for (final match in RegExp(r'\S+').allMatches(text)) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: match.start, extentOffset: match.end),
    );
    final tops = boxes.map((b) => b.top.round()).toSet();
    expect(tops.length, 1, reason: '«${match.group(0)}» split across lines');
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('drawer tutorial GlobalKeys still resolve to the item labels '
        '(${brightness.name})', (tester) async {
      final keys = List.generate(7, (_) => GlobalKey());
      final scaffoldKey = GlobalKey<ScaffoldState>();
      await pumpComponent(
        tester,
        Scaffold(
          key: scaffoldKey,
          endDrawer: AppDrawer(drawerItemKeys: keys, displayName: 'Lucía'),
          body: const SizedBox.expand(),
        ),
        brightness: brightness,
        wrapInScaffold: false,
      );
      scaffoldKey.currentState!.openEndDrawer();
      await tester.pumpAndSettle();

      final labels = <String>[];
      for (final key in keys) {
        final context = key.currentContext;
        expect(context, isNotNull, reason: 'tutorial key not mounted');
        final widget = context!.widget;
        expect(widget, isA<Text>());
        labels.add((widget as Text).data!);
        // TutorialOverlay._rectForKey needs a laid-out RenderBox on screen.
        final box = context.findRenderObject()! as RenderBox;
        expect(box.hasSize, isTrue);
        final rect = box.localToGlobal(Offset.zero) & box.size;
        expect(
          const Rect.fromLTWH(0, 0, 390, 844).contains(rect.center),
          isTrue,
        );
      }
      expect(labels, _itemsEs);

      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(drawer.backgroundColor, palette.background);
      // L5-LOGO: the drawer shows the unified EXOM lockup at h24, not a raw
      // logo asset.
      final logo = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(ExomBrandLogo),
      );
      expect(logo, findsOneWidget);
      expect(tester.widget<ExomBrandLogo>(logo).height, 24);
      // «Cerrar sesión» is a secondary button (1.5 px `text` border), no
      // longer a red row.
      final logoutText = tester.widget<Text>(find.text('Cerrar sesión'));
      expect(logoutText.style?.color, palette.textPrimary);
      expect(identical(keys[6].currentWidget, logoutText), isTrue);
      expect(find.byType(ExomSecondaryButton), findsOneWidget);
      expect(find.text('Recap Semanal'), findsNothing);
      expect(find.text('Cerrar Sesión'), findsNothing);
      // The account name is the protagonist: Barlow 28, painted upper case.
      final name = tester.widget<Text>(find.text('LUCÍA'));
      expect(name.style?.fontSize, 28);
      expect(find.text('Miembro EXOM'), findsOneWidget);
      // No gradient remains in the drawer.
      for (final box in tester.widgetList<Container>(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Container),
        ),
      )) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.gradient, isNull);
        }
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  }

  testWidgets('drawer panel is 304 wide (264 at 320 dp), icons, scrolls', (
    tester,
  ) async {
    for (final width in [390.0, 320.0]) {
      final keys = List.generate(7, (_) => GlobalKey());
      final scaffoldKey = GlobalKey<ScaffoldState>();
      await pumpComponent(
        tester,
        Scaffold(
          key: scaffoldKey,
          endDrawer: AppDrawer(drawerItemKeys: keys, displayName: 'Lucía'),
          body: const SizedBox.expand(),
        ),
        width: width,
        wrapInScaffold: false,
      );
      scaffoldKey.currentState!.openEndDrawer();
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(Drawer)).width,
        width == 390 ? 304 : 264,
      );
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(find.byType(ExomIndexList), findsOneWidget);
      // L5-F2-ICONOS: the icons replace the numbers.
      for (final n in ['01', '02', '03', '04', '05', '06']) {
        expect(find.text(n), findsNothing);
      }
    }
  });

  const destinationIcons = <(String, IconData)>[
    (AppRoutes.profile, ExomIcons.profile),
    (AppRoutes.challenges, ExomIcons.trophy),
    (AppRoutes.recap, ExomIcons.barChart),
    (AppRoutes.feedback, ExomIcons.feedback),
    (AppRoutes.settings, ExomIcons.settings),
    (AppRoutes.help, ExomIcons.help),
  ];

  /// Opens the drawer on a real router at [location].
  Future<void> pumpDrawerAt(
    WidgetTester tester,
    String location, {
    Brightness brightness = Brightness.dark,
    double width = 390,
    double textScale = 1.0,
  }) async {
    final keys = List.generate(7, (_) => GlobalKey());
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/:rest(.*)',
          builder: (context, _) => Scaffold(
            endDrawer: AppDrawer(drawerItemKeys: keys, displayName: 'Lucía'),
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
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: _Auth(),
        child: MaterialApp.router(
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          ),
          routerConfig: router,
          theme: themeFor(brightness),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder entryOf(IconData icon) => find.ancestor(
    of: find.descendant(of: find.byType(Drawer), matching: find.byIcon(icon)),
    matching: find.byKey(const Key('exom-index-entry')),
  );

  for (final brightness in Brightness.values) {
    testWidgets('each destination shows its icon, no number '
        '(${brightness.name})', (tester) async {
      await pumpDrawerAt(tester, AppRoutes.home, brightness: brightness);
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      for (final (_, icon) in destinationIcons) {
        final finder = find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(icon),
        );
        expect(finder, findsOneWidget, reason: '$icon');
        final widget = tester.widget<Icon>(finder);
        expect(widget.size, 22);
        expect(widget.color, palette.textSecondary);
        expect(tester.getSize(entryOf(icon)).height, greaterThanOrEqualTo(60));
      }
      for (final n in ['01', '02', '03', '04', '05', '06']) {
        expect(find.text(n), findsNothing);
      }
      expect(find.byKey(const Key('exom-index-selected-rule')), findsNothing);
      expectNoLimeInk(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      // Icon and rule contrast against the panel (the generic text guideline
      // reads the scrim behind the drawer, not the panel).
      double ratio(Color a, Color b) {
        final l1 = a.computeLuminance();
        final l2 = b.computeLuminance();
        return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
      }

      expect(
        ratio(palette.textSecondary, palette.background),
        greaterThan(4.5),
      );
      expect(ratio(palette.textPrimary, palette.background), greaterThan(4.5));
    });

    testWidgets('on Retos only Retos is selected (${brightness.name})', (
      tester,
    ) async {
      await pumpDrawerAt(tester, AppRoutes.challenges, brightness: brightness);
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      final handle = tester.ensureSemantics();
      for (final (path, icon) in destinationIcons) {
        final current = path == AppRoutes.challenges;
        final entry = entryOf(icon);
        expect(
          // ignore: deprecated_member_use
          tester.getSemantics(entry).hasFlag(SemanticsFlag.isSelected),
          current,
          reason: path,
        );
        final iconWidget = tester.widget<Icon>(
          find.descendant(of: entry, matching: find.byIcon(icon)),
        );
        expect(
          iconWidget.color,
          current ? palette.textPrimary : palette.textSecondary,
          reason: path,
        );
      }
      final rule = find.byKey(const Key('exom-index-selected-rule'));
      expect(rule, findsOneWidget);
      expect(tester.getSize(rule).width, 2);
      expect(tester.widget<ColoredBox>(rule).color, palette.textPrimary);
      final entryRect = tester.getRect(entryOf(ExomIcons.trophy));
      expect(tester.getRect(rule).left, entryRect.left);
      expect(tester.getRect(rule).height, entryRect.height);
      expectNoLimeInk(tester);
      handle.dispose();
    });
  }

  testWidgets('prefix boundary: /recaps-algo and /challengesX mark nothing', (
    tester,
  ) async {
    for (final location in ['/recaps-algo', '/challengesX']) {
      await pumpDrawerAt(tester, location);
      expect(
        find.byKey(const Key('exom-index-selected-rule')),
        findsNothing,
        reason: location,
      );
    }
  });

  testWidgets('the 2 px rule does not swallow the tap on the marked row', (
    tester,
  ) async {
    await pumpDrawerAt(tester, AppRoutes.challenges);
    final rect = tester.getRect(entryOf(ExomIcons.trophy));
    await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing, reason: 'tap at left + 1 closes');
  });

  testWidgets('with an icon the column stays 26 wide at 160 % and 320 dp', (
    tester,
  ) async {
    await pumpDrawerAt(
      tester,
      AppRoutes.challenges,
      width: 320,
      textScale: 1.6,
    );
    for (final (_, icon) in destinationIcons) {
      final column = find.ancestor(
        of: find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(icon),
        ),
        matching: find.byType(SizedBox),
      );
      final widths = tester
          .widgetList<SizedBox>(column)
          .map((b) => b.width)
          .whereType<double>();
      expect(widths, contains(26.0), reason: '$icon');
    }
    expectNoOverflow(tester);
  });

  testWidgets('a sub-route of Retos still marks Retos; Inicio marks none', (
    tester,
  ) async {
    await pumpDrawerAt(tester, '${AppRoutes.challenges}/abc');
    expect(find.byKey(const Key('exom-index-selected-rule')), findsOneWidget);
    expect(
      find.descendant(
        of: entryOf(ExomIcons.trophy),
        matching: find.byKey(const Key('exom-index-selected-rule')),
      ),
      findsNothing,
      reason: 'the rule is a sibling of the entry, not inside it',
    );
    await pumpDrawerAt(tester, AppRoutes.home);
    expect(find.byKey(const Key('exom-index-selected-rule')), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'no label splits mid-word at 320 dp and 160 % (${brightness.name})',
      (tester) async {
        final keys = List.generate(7, (_) => GlobalKey());
        final scaffoldKey = GlobalKey<ScaffoldState>();
        await pumpComponent(
          tester,
          Scaffold(
            key: scaffoldKey,
            endDrawer: AppDrawer(drawerItemKeys: keys, displayName: 'Lucía'),
            body: const SizedBox.expand(),
          ),
          width: 320,
          textScale: 1.6,
          brightness: brightness,
          wrapInScaffold: false,
        );
        scaffoldKey.currentState!.openEndDrawer();
        await tester.pumpAndSettle();
        for (final key in keys) {
          _expectNoWordSplit(key.currentContext! as Element);
        }
        for (final text in tester.widgetList<Text>(
          find.descendant(of: find.byType(Drawer), matching: find.byType(Text)),
        )) {
          expect(text.overflow, isNot(TextOverflow.ellipsis));
        }
        expectNoOverflow(tester);
      },
    );
  }

  testWidgets('drawer destinations navigate as before and close the drawer', (
    tester,
  ) async {
    final auth = _Auth();
    final keys = List.generate(7, (_) => GlobalKey());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            endDrawer: AppDrawer(drawerItemKeys: keys, displayName: 'Lucía'),
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        for (final path in [
          AppRoutes.profile,
          AppRoutes.challenges,
          AppRoutes.recap,
          AppRoutes.feedback,
          AppRoutes.settings,
          AppRoutes.help,
        ])
          GoRoute(
            path: path,
            builder: (context, _) => Scaffold(body: Text('page $path')),
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
        value: auth,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.dark,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    const destinations = <(int, String)>[
      (0, AppRoutes.profile),
      (1, AppRoutes.challenges),
      (2, AppRoutes.recap),
      (3, AppRoutes.feedback),
      (4, AppRoutes.settings),
      (5, AppRoutes.help),
    ];
    for (final (index, path) in destinations) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(keys[index]));
      await tester.pumpAndSettle();
      expect(find.text('page $path'), findsOneWidget, reason: path);
      expect(find.byType(Drawer), findsNothing, reason: 'drawer closed');
      router.go('/');
      await tester.pumpAndSettle();
    }

    // «Cerrar sesión» closes the drawer and logs out, with no confirmation.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys[6]));
    await tester.pumpAndSettle();
    expect(auth.events.single, isA<AuthLogoutRequested>());
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'unread badge: 13 px, token colours, fits (${brightness.name})',
      (tester) async {
        await pumpComponent(
          tester,
          Center(
            child: IconButton(
              tooltip: 'Notificaciones',
              onPressed: () {},
              icon: const Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(ExomIcons.notifications, size: 24),
                  Positioned(
                    right: -8,
                    top: -7,
                    child: ShellUnreadBadge(count: 120),
                  ),
                ],
              ),
            ),
          ),
          brightness: brightness,
          textScale: 1.6,
        );
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        final text = tester.widget<Text>(find.text('99+'));
        expect(text.style?.fontSize, greaterThanOrEqualTo(13));
        expect(text.style?.color, palette.background);
        final button = tester.getRect(find.byType(IconButton));
        final badge = tester.getRect(find.byType(ShellUnreadBadge));
        expect(button.width, greaterThanOrEqualTo(48));
        expect(button.height, greaterThanOrEqualTo(48));
        expect(button.contains(badge.topLeft), isTrue);
        expect(
          button.contains(badge.bottomRight - const Offset(0.01, 0.01)),
          isTrue,
        );
        expectNoOverflow(tester);
        await expectTapTargetGuidelines(tester);
      },
    );
  }
}
