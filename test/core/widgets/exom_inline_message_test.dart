import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme/wcag_contrast.dart';
import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';
import 'expect_no_lime_ink.dart';

const _body = 'Comprueba la conexión e inténtalo de nuevo.';

Widget _msg(
  ExomMessageKind kind, {
  String? body = _body,
  String? actionLabel = 'Reintentar',
  VoidCallback? onAction,
}) => ExomInlineMessage(
  kind: kind,
  title: 'No se pudo guardar',
  body: body,
  actionLabel: actionLabel,
  onAction: onAction ?? () {},
);

/// Labels of every live-region node in the semantics tree.
List<String> _liveRegions(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isLiveRegion) labels.add(data.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(Scaffold)));
  return labels;
}

void main() {
  for (final kind in ExomMessageKind.values) {
    registerTextComponentMatrix(
      'ExomInlineMessage ${kind.name}',
      () => _msg(kind),
    );
  }

  for (final kind in ExomMessageKind.values) {
    testWidgets('exactly one liveRegion node (${kind.name})', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, _msg(kind));
      expect(_liveRegions(tester), hasLength(1));
      handle.dispose();
    });
  }

  testWidgets('no action: one liveRegion announcing title and body', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _msg(ExomMessageKind.error, actionLabel: null));
    expect(find.byType(ExomTextLink), findsNothing);
    final live = _liveRegions(tester);
    expect(live, hasLength(1));
    expect(
      live.single,
      allOf(contains('No se pudo guardar'), contains('Comprueba la conexión')),
    );
    handle.dispose();
  });

  testWidgets('title-only message works', (tester) async {
    await pumpComponent(tester, _msg(ExomMessageKind.info, body: null));
    expect(find.text('No se pudo guardar'), findsOneWidget);
    expect(find.text(_body), findsNothing);
  });

  testWidgets('action is a link outside the live region and fires onAction', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpComponent(
      tester,
      _msg(ExomMessageKind.error, onAction: () => taps++),
    );
    expect(_liveRegions(tester).single, isNot(contains('Reintentar')));
    final size = tester.getSize(find.byType(InkWell));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Reintentar'));
    expect(taps, 1);
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  testWidgets('actionLabel without onAction shows no action', (tester) async {
    await pumpComponent(
      tester,
      const ExomInlineMessage(
        kind: ExomMessageKind.error,
        title: 'x',
        actionLabel: 'Reintentar',
      ),
    );
    expect(find.byType(ExomTextLink), findsNothing);
  });

  for (final brightness in Brightness.values) {
    final theme = themeFor(brightness);
    final palette = theme.extension<ExomThemePalette>()!;
    final semantic = theme.extension<ExomSemanticPalette>()!;

    Color titleColor(WidgetTester tester) =>
        tester.widget<Text>(find.text('No se pudo guardar')).style!.color!;
    Color iconColor(WidgetTester tester) =>
        tester.widget<Icon>(find.byType(Icon)).color!;

    testWidgets('colour by kind (${brightness.name})', (tester) async {
      final expected = {
        ExomMessageKind.error: palette.error,
        ExomMessageKind.pendiente: semantic.warning,
        ExomMessageKind.ok: palette.textPrimary,
        ExomMessageKind.info: palette.textSecondary,
      };
      for (final entry in expected.entries) {
        await pumpComponent(
          tester,
          _msg(entry.key, actionLabel: null),
          brightness: brightness,
        );
        expect(titleColor(tester), entry.value, reason: entry.key.name);
        expect(iconColor(tester), entry.value, reason: entry.key.name);
      }
    });

    testWidgets('ok is text colour with a check, never lime '
        '(${brightness.name})', (tester) async {
      await pumpComponent(
        tester,
        _msg(ExomMessageKind.ok, actionLabel: null),
        brightness: brightness,
      );
      expect(tester.widget<Icon>(find.byType(Icon)).icon, ExomIcons.check);
      expect(titleColor(tester), palette.textPrimary);
      expect(titleColor(tester), isNot(palette.limeFill));
    });

    testWidgets('error has a 2 px leading edge in error; info none '
        '(${brightness.name})', (tester) async {
      BorderDirectional? edge() => tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((b) => b.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<BorderDirectional>()
          .firstOrNull;
      await pumpComponent(
        tester,
        _msg(ExomMessageKind.error, actionLabel: null),
        brightness: brightness,
      );
      expect(edge()!.start.width, ExomRule.replyEdge);
      expect(edge()!.start.color, palette.error);
      await pumpComponent(
        tester,
        _msg(ExomMessageKind.info, actionLabel: null),
        brightness: brightness,
      );
      expect(edge(), isNull);
    });
  }

  for (final scale in const [1.0, 1.3, 1.6, 2.0]) {
    testWidgets('title, body and action share the start edge at $scale x', (
      tester,
    ) async {
      for (final kind in [ExomMessageKind.error, ExomMessageKind.info]) {
        await pumpComponent(
          tester,
          SingleChildScrollView(child: _msg(kind)),
          width: 360,
          textScale: scale,
        );
        final title = tester.getTopLeft(find.text('No se pudo guardar')).dx;
        final body = tester.getTopLeft(find.text(_body)).dx;
        final action = tester.getTopLeft(find.text('Reintentar')).dx;
        expect(body, closeTo(title, 0.5), reason: '${kind.name} body');
        expect(action, closeTo(title, 0.5), reason: '${kind.name} action');
      }
    });
  }

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('body is secondary text at 14 (${brightness.name})', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        _msg(ExomMessageKind.error),
        brightness: brightness,
      );
      final style = tester.widget<Text>(find.text(_body)).style!;
      expect(style.color, palette.textSecondary);
      expect(style.fontSize, 14);
      expect(
        contrastRatio(style.color!, palette.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(style.color!, palette.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  for (final kind in ExomMessageKind.values) {
    testWidgets('no lime ink in the light theme (${kind.name})', (
      tester,
    ) async {
      await pumpComponent(tester, _msg(kind), brightness: Brightness.light);
      expectNoLimeInk(tester);
    });
  }
}
