import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

const _text = 'Buen trabajo esta semana, sube el peso un poco la próxima vez.';

Widget _coach() =>
    const ExomCoachBlock(text: _text, author: 'Marta Ruiz', time: 'hace 2 h');
Widget _reply() =>
    const ExomReplyBlock(text: _text, author: 'Tu entrenador', time: 'ayer');

BoxDecoration _decorationOf(WidgetTester tester, Type type) {
  final boxes = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(type),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((b) => b.decoration)
      .whereType<BoxDecoration>();
  return boxes.firstWhere((d) => d.border != null);
}

void main() {
  registerTextComponentMatrix('ExomCoachBlock', _coach);
  registerTextComponentMatrix('ExomReplyBlock', _reply);

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;

    testWidgets('reply: 2 px leading edge in data, no panel '
        '(${brightness.name})', (tester) async {
      await pumpComponent(tester, _reply(), brightness: brightness);
      final decoration = _decorationOf(tester, ExomReplyBlock);
      final border = decoration.border! as BorderDirectional;
      expect(border.start.width, ExomRule.replyEdge);
      expect(border.start.color, palette.data);
      expect(border.end, BorderSide.none);
      expect(decoration.color, isNull);
    });

    testWidgets('coach: panel with 2 px top rule in data '
        '(${brightness.name})', (tester) async {
      await pumpComponent(tester, _coach(), brightness: brightness);
      final decoration = _decorationOf(tester, ExomCoachBlock);
      final border = decoration.border! as Border;
      expect(border.top.width, ExomRule.replyEdge);
      expect(border.top.color, palette.data);
      expect(decoration.color, palette.surface);
    });
  }

  testWidgets('shows author, time and text; time is optional', (tester) async {
    await pumpComponent(tester, _coach());
    expect(find.text('Marta Ruiz'), findsOneWidget);
    expect(find.text('hace 2 h'), findsOneWidget);
    expect(find.text(_text), findsOneWidget);
    await pumpComponent(
      tester,
      const ExomReplyBlock(text: _text, author: 'Tu entrenador'),
    );
    expect(find.text('Tu entrenador'), findsOneWidget);
    expect(find.text('hace 2 h'), findsNothing);
  });

  group('avatar (L5-C5b)', () {
    const photo = AssetImage('assets/images/coach/moi.png');
    Widget withAvatar(ImageProvider avatar) => ExomCoachBlock(
      text: _text,
      author: 'Marta Ruiz',
      time: 'hace 2 h',
      avatar: avatar,
    );

    testWidgets('without avatar the square shows the initial, no image', (
      tester,
    ) async {
      await pumpComponent(tester, _coach());
      expect(find.text('M'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExomCoachBlock),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
    });

    testWidgets('with avatar the 32 px square shows the photo, no initial', (
      tester,
    ) async {
      await pumpComponent(tester, withAvatar(photo));
      final image = find.descendant(
        of: find.byType(ExomCoachBlock),
        matching: find.byType(Image),
      );
      expect(image, findsOneWidget);
      final widget = tester.widget<Image>(image);
      expect(widget.image, photo);
      expect(widget.fit, BoxFit.cover);
      expect(widget.alignment, Alignment.topCenter);
      expect(widget.filterQuality, FilterQuality.medium);
      expect(tester.getSize(image), const Size(32, 32));
      expect(find.text('M'), findsNothing);
    });

    testWidgets('a photo that fails to load falls back to the initial', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        withAvatar(const AssetImage('assets/images/coach/missing.png')),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('semantics are the same with and without avatar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, _coach());
      final plain = tester.getSemantics(find.byType(ExomCoachBlock));
      await pumpComponent(tester, withAvatar(photo));
      final photoNode = tester.getSemantics(find.byType(ExomCoachBlock));
      expect(photoNode.label, plain.label);
      expect(photoNode.mergeAllDescendantsIntoThisNode, isFalse);
      var children = 0;
      photoNode.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0, reason: 'the photo is decorative');
      handle.dispose();
    });
  });

  testWidgets('semantics reads author, time and text as one node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _coach());
    final label = tester.getSemantics(find.byType(ExomCoachBlock)).label;
    expect(label, contains('Marta Ruiz'));
    expect(label, contains('hace 2 h'));
    expect(label, contains(_text));
    await pumpComponent(tester, _reply());
    final reply = tester.getSemantics(find.byType(ExomReplyBlock)).label;
    expect(reply, allOf(contains('Tu entrenador'), contains('ayer')));
    expect(reply, contains(_text));
    handle.dispose();
  });
}
