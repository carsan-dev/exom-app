// showExomSheet as a confirmation sheet (L5 T0.3a): optional title, body and
// actions, and the page-aware close of contract R22.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../golden/redesign_scenes.dart' show loadRedesignFonts;
import '../theme/wcag_contrast.dart';
import 'exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines, themeFor;
import 'exom_text_component_matrix.dart' show expectNoEllipsis;
import 'expect_no_lime_ink.dart';

const _title = 'Descartar la serie';
const _longAction = 'Descartar la serie y todas sus repeticiones guardadas';
const _longCancel = 'Cancelar y volver al entrenamiento de hoy';
const _body = 'Se borrarán las repeticiones y el peso de esta serie.';

Future<GoRouter> _pump(
  WidgetTester tester, {
  required List<String> events,
  required List<Object?> results,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  bool withBuilder = false,
  bool longActions = false,
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () {
                showExomSheet<bool>(
                  context: context,
                  title: _title,
                  body: _body,
                  builder: withBuilder
                      ? (_) => const Padding(
                          padding: EdgeInsetsDirectional.symmetric(
                            horizontal: 20,
                          ),
                          child: Text('Contenido propio'),
                        )
                      : null,
                  actions: [
                    Builder(
                      builder: (sheetContext) => FilledButton(
                        key: const Key('confirm'),
                        onPressed: () {
                          events.add('action');
                          Navigator.of(sheetContext).pop(true);
                        },
                        child: Text(longActions ? _longAction : 'Descartar'),
                      ),
                    ),
                    Builder(
                      builder: (sheetContext) => TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: Text(longActions ? _longCancel : 'Cancelar'),
                      ),
                    ),
                  ],
                ).then((result) {
                  events.add('returned');
                  results.add(result);
                });
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/other',
        builder: (context, state) => const Scaffold(body: Text('Otra')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  return router;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('R22: a route change closes the confirmation sheet with no '
      'result and without running its action', (tester) async {
    final events = <String>[];
    final results = <Object?>[];
    final router = await _pump(tester, events: events, results: results);
    await _open(tester);
    expect(find.text('Descartar'), findsOneWidget);
    router.go('/other');
    await tester.pumpAndSettle();
    expect(find.text('Descartar'), findsNothing);
    expect(find.text('Otra'), findsOneWidget);
    expect(events, ['returned']);
    expect(results, [null]);
  });

  testWidgets('the action pops with its value', (tester) async {
    final events = <String>[];
    final results = <Object?>[];
    await _pump(tester, events: events, results: results);
    await _open(tester);
    await tester.tap(find.byKey(const Key('confirm')));
    await tester.pumpAndSettle();
    expect(events, ['action', 'returned']);
    expect(results, [true]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('title upper case as a header, body in secondary, actions '
        'pinned under a rule (${brightness.name})', (tester) async {
      final handle = tester.ensureSemantics();
      final palette =
          (brightness == Brightness.dark ? AppTheme.dark : AppTheme.light)
              .extension<ExomThemePalette>()!;
      await _pump(tester, events: [], results: [], brightness: brightness);
      await _open(tester);
      final title = tester.widget<Text>(find.text(_title.toUpperCase()));
      expect(title.style?.fontFamily, ExomType.headline2Section.fontFamily);
      expect(title.style?.fontSize, ExomType.headline2Section.fontSize);
      expect(title.style?.color, palette.textPrimary);
      final titleNode = tester.getSemantics(find.text(_title.toUpperCase()));
      expect(titleNode.label, _title);
      expect(titleNode.flagsCollection.isHeader, isTrue);
      final body = tester.widget<Text>(find.text(_body));
      expect(body.style?.color, palette.textSecondary);

      final actions = find.byKey(const Key('exom-sheet-actions'));
      expect(actions, findsOneWidget);
      expect(
        find.descendant(of: actions, matching: find.text('Cancelar')),
        findsOneWidget,
      );
      // Pinned: outside the scrolling content.
      expect(
        find.ancestor(
          of: actions,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      final rule = tester.widget<DecoratedBox>(
        find.descendant(of: actions, matching: find.byType(DecoratedBox)).first,
      );
      final border = (rule.decoration as BoxDecoration).border! as Border;
      expect(border.top, BorderSide(color: palette.borderSoft, width: 1));
      expect(
        tester.getRect(find.text(_body)).bottom,
        lessThanOrEqualTo(tester.getRect(actions).top),
      );
      if (brightness == Brightness.light) expectNoLimeInk(tester);
      handle.dispose();
    });
  }

  testWidgets('a builder still renders between the text and the actions', (
    tester,
  ) async {
    await _pump(tester, events: [], results: [], withBuilder: true);
    await _open(tester);
    final body = tester.getRect(find.text(_body));
    final own = tester.getRect(find.text('Contenido propio'));
    final actions = tester.getRect(find.byKey(const Key('exom-sheet-actions')));
    expect(own.top, greaterThanOrEqualTo(body.bottom));
    expect(actions.top, greaterThanOrEqualTo(own.bottom));
  });

  // Requirements of redesign L5 section 2.1 for the confirmation variant. The
  // sheet is a route, so the shared registerTextComponentMatrix cannot wrap it
  // in a scroll view: the same matrix is run against the opened sheet, with the
  // same no-overflow / no-ellipsis checks of exom_text_component_matrix.dart.
  for (final width in const [320.0, 360.0]) {
    for (final scale in const [1.0, 1.3, 1.6]) {
      testWidgets('matrix: ${width.toInt()} dp at $scale x, no overflow', (
        tester,
      ) async {
        await _pump(
          tester,
          events: [],
          results: [],
          width: width,
          textScale: scale,
          withBuilder: true,
        );
        await _open(tester);
        expectNoOverflow(tester);
        expectNoEllipsis(tester);
        _expectActionsOnScreen(tester, Size(width, 844));
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('matrix: 2.0 x on a short screen scrolls the body and keeps '
        'the actions reachable (${brightness.name})', (tester) async {
      await _pump(
        tester,
        events: [],
        results: [],
        width: 320,
        height: 480,
        textScale: 2.0,
        brightness: brightness,
        withBuilder: true,
      );
      await _open(tester);
      expectNoOverflow(tester);
      expectNoEllipsis(tester);
      _expectActionsOnScreen(tester, const Size(320, 480));
      final scrollable = find.descendant(
        of: find.byKey(const Key('exom-sheet-panel')),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pump();
      expect(position.pixels, position.maxScrollExtent);
      expectNoOverflow(tester);
      _expectActionsOnScreen(tester, const Size(320, 480));
    });

    testWidgets('matrix: text contrast (${brightness.name})', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, events: [], results: [], brightness: brightness);
      await _open(tester);
      // textContrastGuideline samples rendered pixels and, on 14 px DM Sans,
      // can measure an antialiasing shade (3.23 on the body in the light
      // theme, already seen in the L0 baseline; see
      // test/a11y/redesign_baseline_guidelines_test.dart). So a report may
      // only name the body, and the real colour pairs must reach AA.
      final evaluation = await textContrastGuideline.evaluate(tester);
      if (!evaluation.passed) {
        final reason = evaluation.reason ?? '';
        expect(
          RegExp('SemanticsNode#').allMatches(reason).length,
          1,
          reason: reason,
        );
        expect(reason, contains('Se borrarán'), reason: reason);
      }
      final palette = themeFor(brightness).extension<ExomThemePalette>()!;
      expect(
        contrastRatio(palette.textSecondary, palette.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(palette.textPrimary, palette.surface),
        greaterThanOrEqualTo(4.5),
      );
      handle.dispose();
    });
  }

  testWidgets('matrix: tap targets meet the guidelines at 320 dp, 1.6x', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, events: [], results: [], width: 320, textScale: 1.6);
    await _open(tester);
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  testWidgets('long action labels wrap and stay inside the pinned actions', (
    tester,
  ) async {
    await _pump(
      tester,
      events: [],
      results: [],
      width: 320,
      height: 480,
      textScale: 2.0,
      longActions: true,
    );
    await _open(tester);
    expectNoOverflow(tester);
    expectNoEllipsis(tester);
    _expectActionsOnScreen(
      tester,
      const Size(320, 480),
      labels: const [_longAction, _longCancel],
    );
  });
}

/// Every action stays inside the screen (never pushed out by the body).
void _expectActionsOnScreen(
  WidgetTester tester,
  Size screen, {
  List<String> labels = const ['Descartar', 'Cancelar'],
}) {
  final area = Offset.zero & screen;
  for (final label in labels) {
    final rect = tester.getRect(find.text(label));
    expect(area.contains(rect.topLeft), isTrue, reason: '$label top-left');
    expect(
      area.contains(rect.bottomRight - const Offset(0.1, 0.1)),
      isTrue,
      reason: '$label bottom-right',
    );
  }
}
