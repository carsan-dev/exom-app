import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

const _longLabel =
    'Guardar serie y continuar con el siguiente ejercicio del circuito';

Widget _column(List<Widget> children) => Padding(
  padding: const EdgeInsets.all(20),
  child: Column(mainAxisSize: MainAxisSize.min, children: children),
);

BoxDecoration _decorationOf(WidgetTester tester, Key key) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('ExomPrimaryButton', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'lime fill, carbon label, 56 min height (${brightness.name})',
        (tester) async {
          await pumpComponent(
            tester,
            _column([
              ExomPrimaryButton(
                key: const Key('primary'),
                label: 'Guardar serie',
                trailingIcon: ExomIcons.check,
                onPressed: () {},
              ),
            ]),
            brightness: brightness,
          );
          final size = tester.getSize(find.byKey(const Key('primary')));
          expect(size.height, greaterThanOrEqualTo(56));
          final decoration = _decorationOf(tester, const Key('primary'));
          expect(decoration.color, AppColors.primary);
          expect(decoration.borderRadius, BorderRadius.circular(4));
          final border = decoration.border as Border?;
          if (brightness == Brightness.light) {
            expect(border, isNotNull);
            expect(border!.top.color, const Color(0xFF101111));
            expect(border.top.width, 1.5);
          } else {
            expect(border == null || border.top.width == 0, isTrue);
          }
          final text = tester.widget<Text>(find.text('GUARDAR SERIE'));
          expect(text.style?.color, const Color(0xFF101111));
          expect(text.style?.fontFamily, AppTheme.bodyFontFamily);
          expect(text.style?.fontWeight, FontWeight.w600);
          expect(text.style?.fontSize, 16);
          expect(find.byIcon(ExomIcons.check), findsOneWidget);
          await expectTapTargetGuidelines(tester);
        },
      );
    }

    testWidgets('fires on tap and ignores taps while busy', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      Widget build(bool busy) => _column([
        ExomPrimaryButton(
          key: const Key('primary'),
          label: 'Registrar',
          busy: busy,
          onPressed: () => taps++,
        ),
      ]);
      await pumpComponent(tester, build(false));
      await tester.tap(find.byKey(const Key('primary')));
      await tester.pumpAndSettle();
      expect(taps, 1);

      await pumpComponent(tester, build(true));
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('primary')), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1, reason: 'repeat taps while busy must be ignored');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final semantics = tester.getSemantics(find.bySemanticsLabel('Registrar'));
      expect(
        semantics,
        matchesSemantics(
          label: 'Registrar',
          value: 'En curso',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          textDirection: TextDirection.ltr,
        ),
      );
      handle.dispose();
    });

    testWidgets('busy state is announced, localized (es/en)', (tester) async {
      final handle = tester.ensureSemantics();
      for (final (locale, busyText) in const [
        (Locale('es'), 'En curso'),
        (Locale('en'), 'In progress'),
      ]) {
        for (final busy in [false, true]) {
          await pumpComponent(
            tester,
            _column([
              ExomPrimaryButton(
                label: 'Registrar',
                busy: busy,
                onPressed: () {},
              ),
            ]),
            locale: locale,
          );
          final node = tester.getSemantics(find.bySemanticsLabel('Registrar'));
          expect(
            // Merged data: the button node merges its label and value.
            node.getSemanticsData().value,
            busy ? busyText : isEmpty,
            reason: 'busy=$busy ${locale.languageCode}',
          );
        }
      }
      handle.dispose();
    });

    testWidgets('screen readers hear the label in its original case', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        _column([
          ExomPrimaryButton(
            key: const Key('primary'),
            label: 'Registrar serie',
            onPressed: () {},
          ),
          ExomPrimaryButton(
            key: const Key('overridden'),
            label: 'Guardar',
            semanticLabel: 'Guardar la serie 2',
            onPressed: () {},
          ),
        ]),
      );
      // The painted label stays uppercase.
      expect(find.text('REGISTRAR SERIE'), findsOneWidget);
      expect(find.bySemanticsLabel('Registrar serie'), findsOneWidget);
      expect(find.bySemanticsLabel('REGISTRAR SERIE'), findsNothing);
      expect(find.bySemanticsLabel('Guardar la serie 2'), findsOneWidget);
      handle.dispose();
    });

    for (final override in [null, 'Registrar la serie 2']) {
      testWidgets('enabled: screen readers can activate it '
          '(semanticLabel: $override)', (tester) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        await pumpComponent(
          tester,
          _column([
            ExomPrimaryButton(
              label: 'Registrar',
              semanticLabel: override,
              onPressed: () => taps++,
            ),
          ]),
        );
        final label = override ?? 'Registrar';
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            textDirection: TextDirection.ltr,
          ),
        );
        tester.semantics.tap(find.semantics.byLabel(label));
        await tester.pump();
        expect(taps, 1);
        handle.dispose();
      });
    }

    for (final busy in [false, true]) {
      testWidgets('${busy ? 'busy' : 'disabled'}: no tap action', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpComponent(
          tester,
          _column([
            ExomPrimaryButton(
              label: 'Registrar',
              busy: busy,
              onPressed: busy ? () {} : null,
            ),
          ]),
        );
        final data = tester
            .getSemantics(find.bySemanticsLabel('Registrar'))
            .getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        handle.dispose();
      });
    }

    testWidgets('disabled when onPressed is null', (tester) async {
      await pumpComponent(
        tester,
        _column([
          const ExomPrimaryButton(
            key: Key('primary'),
            label: 'Registrar',
            onPressed: null,
          ),
        ]),
      );
      final decoration = _decorationOf(tester, const Key('primary'));
      expect(decoration.color, isNot(AppColors.primary));
      await tester.tap(find.byKey(const Key('primary')), warnIfMissed: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('press scales to .97 with standard motion, size stable', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        _column([
          ExomPrimaryButton(
            key: const Key('primary'),
            label: 'Registrar',
            onPressed: () {},
          ),
        ]),
      );
      final before = tester.getSize(find.byKey(const Key('primary')));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('primary'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final scale = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byKey(const Key('primary')),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scale.scale, 0.97);
      expect(scale.duration, const Duration(milliseconds: 80));
      expect(tester.getSize(find.byKey(const Key('primary'))), before);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: no scale, opacity only', (tester) async {
      await pumpComponent(
        tester,
        _column([
          ExomPrimaryButton(
            key: const Key('primary'),
            label: 'Registrar',
            onPressed: () {},
          ),
        ]),
        disableAnimations: true,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('primary'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byKey(const Key('primary')),
          matching: find.byType(AnimatedScale),
        ),
        findsNothing,
      );
      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(const Key('primary')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.opacity, lessThan(1));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    for (final brightness in Brightness.values) {
      testWidgets('long label wraps at 320 dp and 1.6x (${brightness.name})', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          _column([
            ExomPrimaryButton(
              key: const Key('primary'),
              label: _longLabel,
              trailingIcon: ExomIcons.forward,
              onPressed: () {},
            ),
            const SizedBox(height: 8),
            ExomSecondaryButton(
              key: const Key('secondary'),
              label: _longLabel,
              icon: ExomIcons.retry,
              onPressed: () {},
            ),
            ExomQuietButton(
              key: const Key('quiet'),
              label: _longLabel,
              onPressed: () {},
            ),
          ]),
          brightness: brightness,
          width: 320,
          textScale: 1.6,
        );
        expectNoOverflow(tester);
        final primary = tester.getSize(find.byKey(const Key('primary')));
        expect(primary.height, greaterThan(56), reason: 'label wraps');
        final text = tester.widget<Text>(find.text(_longLabel.toUpperCase()));
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        await expectTapTargetGuidelines(tester);
      });
    }
  });

  group('ExomSecondaryButton / ExomQuietButton', () {
    for (final brightness in Brightness.values) {
      testWidgets('targets and styles (${brightness.name})', (tester) async {
        var secondary = 0;
        var quiet = 0;
        await pumpComponent(
          tester,
          _column([
            ExomSecondaryButton(
              key: const Key('secondary'),
              label: 'Reintentar',
              icon: ExomIcons.retry,
              onPressed: () => secondary++,
            ),
            ExomQuietButton(
              key: const Key('quiet'),
              label: 'Cancelar',
              onPressed: () => quiet++,
            ),
          ]),
          brightness: brightness,
        );
        final palette = themeFor(brightness).extension<ExomThemePalette>()!;
        expect(
          tester.getSize(find.byKey(const Key('secondary'))).height,
          greaterThanOrEqualTo(56),
        );
        final quietSize = tester.getSize(find.byKey(const Key('quiet')));
        expect(quietSize.height, greaterThanOrEqualTo(48));
        expect(quietSize.width, greaterThanOrEqualTo(48));
        final decoration = _decorationOf(tester, const Key('secondary'));
        final border = decoration.border! as Border;
        expect(border.top.color, palette.textPrimary);
        expect(border.top.width, 1.5);
        expect(decoration.color, isNull);
        final quietText = tester.widget<Text>(find.text('Cancelar'));
        expect(quietText.style?.decoration, TextDecoration.underline);
        expect(quietText.style?.color, palette.textPrimary);
        await tester.tap(find.byKey(const Key('secondary')));
        await tester.tap(find.byKey(const Key('quiet')));
        await tester.pumpAndSettle();
        expect(secondary, 1);
        expect(quiet, 1);
        await expectTapTargetGuidelines(tester);
      });
    }
  });
}
