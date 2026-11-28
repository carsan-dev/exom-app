import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_notice_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

const _title = 'Tu entrenador ha respondido';
const _body =
    '«Buen trabajo en la búlgara. La semana que viene subimos a 65 kg.»';

ExomThemePalette _palette(Brightness b) =>
    themeFor(b).extension<ExomThemePalette>()!;

Widget _notice({bool unread = true, VoidCallback? onTap}) => ExomNoticeRow(
  title: _title,
  body: _body,
  time: '10:42',
  unread: unread,
  onTap: onTap ?? () {},
);

BoxDecoration _dot(WidgetTester tester) =>
    tester
            .widget<Container>(find.byKey(const Key('exom-notice-dot')))
            .decoration!
        as BoxDecoration;

void main() {
  registerTextComponentMatrix('ExomNoticeRow unread', _notice);
  registerTextComponentMatrix(
    'ExomNoticeRow read',
    () => _notice(unread: false),
  );

  testWidgets('tap targets meet the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _notice(), width: 320);
    await expectTapTargetGuidelines(tester);
    expect(
      tester.getSize(find.byType(ExomNoticeRow)).height,
      greaterThanOrEqualTo(56),
    );
    handle.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('unread: 6 dp dot in text colour and 600 title '
        '(${brightness.name})', (tester) async {
      final palette = _palette(brightness);
      await pumpComponent(tester, _notice(), brightness: brightness);
      expect(
        tester.getSize(find.byKey(const Key('exom-notice-dot'))),
        const Size(6, 6),
      );
      expect(_dot(tester).color, palette.textPrimary);
      final title = tester.widget<Text>(find.text(_title));
      expect(title.style?.fontWeight, FontWeight.w600);
      expect(title.style?.color, palette.textPrimary);
      final time = tester.widget<Text>(find.text('10:42'));
      expect(time.style?.fontSize, 13);
      expect(time.style?.color, palette.textSecondary);
      final body = tester.widget<Text>(find.text(_body));
      expect(body.style?.fontSize, 14);
      expect(body.style?.color, palette.textSecondary);
      expect(body.maxLines, isNull);
    });

    testWidgets('read: no dot fill and regular title (${brightness.name})', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        _notice(unread: false),
        brightness: brightness,
      );
      expect(_dot(tester).color, isNull);
      final title = tester.widget<Text>(find.text(_title));
      expect(title.style?.fontWeight, FontWeight.w400);
    });
  }

  testWidgets('screen reader hears «No leído» only when unread', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _notice());
    var node = tester.getSemantics(find.byType(ExomNoticeRow));
    expect(node.label, contains('No leído'));
    expect(node.label, contains(_title));
    expect(node.label, contains(_body));
    expect(node.label, contains('10:42'));
    expect(node.flagsCollection.isButton, isTrue);

    await pumpComponent(tester, _notice(unread: false));
    node = tester.getSemantics(find.byType(ExomNoticeRow));
    expect(node.label, isNot(contains('No leído')));
    handle.dispose();
  });

  testWidgets('English label is «Unread»', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _notice(), locale: const Locale('en'));
    expect(
      tester.getSemantics(find.byType(ExomNoticeRow)).label,
      contains('Unread'),
    );
    handle.dispose();
  });

  testWidgets('tap reaches onTap; start padding 14, dot then title', (
    tester,
  ) async {
    var taps = 0;
    await pumpComponent(tester, _notice(onTap: () => taps++));
    await tester.tap(find.text(_title));
    expect(taps, 1);
    final dot = tester.getRect(find.byKey(const Key('exom-notice-dot')));
    final title = tester.getRect(find.text(_title));
    expect(dot.left, 14);
    expect(title.left, dot.right + 10);
  });

  testWidgets('optional leading sits between the dot and the text', (
    tester,
  ) async {
    const leadingKey = Key('notice-leading');
    await pumpComponent(
      tester,
      ExomNoticeRow(
        title: _title,
        body: _body,
        time: '10:42',
        unread: true,
        onTap: () {},
        leading: const SizedBox(key: leadingKey, width: 56, height: 56),
      ),
      width: 320,
    );
    final dot = tester.getRect(find.byKey(const Key('exom-notice-dot')));
    final leading = tester.getRect(find.byKey(leadingKey));
    final title = tester.getRect(find.text(_title));
    expect(dot.left, 14);
    expect(leading.left, dot.right + 10);
    expect(leading.top, tester.getTopLeft(find.byType(ExomNoticeRow)).dy + 12);
    expect(title.left, leading.right + 14);
    expect(tester.takeException(), isNull);
  });
}
