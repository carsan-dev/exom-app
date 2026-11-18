import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/exom_component_harness.dart';

const _itemsEs = [
  'Perfil',
  'Retos',
  'Recap Semanal',
  'Feedback',
  'Ajustes',
  'Ayuda',
  'Cerrar Sesión',
];

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
      final logout = tester.widget<Text>(find.text('Cerrar Sesión'));
      expect(logout.style?.color, palette.error);
      expect(find.text('Lucía'), findsOneWidget);
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
                  Icon(Icons.notifications_outlined, size: 24),
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
