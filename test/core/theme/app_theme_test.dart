// Contract change approved in decision D2 (redesign plan
// docs/plans/rediseno-exom-app.md, lot L1): the app adopts the web's V4 brand.
// The assertions below pin the approved V4 token values; the previous brown /
// cream palette and the CabinetGrotesk default font are intentionally replaced.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _lime = Color(0xFFBAF23A);
const _charcoal = Color(0xFF101111);
const _bone = Color(0xFFF2F1E9);

Color? _resolve(WidgetStateProperty<Color?>? property, [
  Set<WidgetState> states = const <WidgetState>{},
]) => property?.resolve(states);

void main() {
  test('light theme exposes the approved V4 light palette', () {
    final theme = AppTheme.light;
    final palette = theme.extension<ExomThemePalette>();
    final semantic = theme.extension<ExomSemanticPalette>();

    expect(theme.brightness, Brightness.light);
    expect(palette, isNotNull);
    expect(semantic, isNotNull);
    expect(palette!.background, _bone);
    expect(palette.surface, const Color(0xFFFBFAF4));
    expect(palette.surfaceElevated, const Color(0xFFE8E7DD));
    expect(palette.surfaceVariant, const Color(0xFFE8E7DD));
    expect(palette.borderSoft, const Color(0xFFCFCEC2));
    expect(palette.divider, const Color(0xFFCFCEC2));
    expect(palette.textPrimary, _charcoal);
    expect(palette.textSecondary, const Color(0xFF55594F));
    expect(palette.textMuted, const Color(0xFF55594F));
    expect(palette.textDisabled, const Color(0xFF63675D));
    expect(palette.primary, const Color(0xFF4F6B00));
    expect(palette.onPrimary, _bone);
    expect(palette.primarySoft, const Color(0xFFE3EDC2));
    expect(palette.error, const Color(0xFFA3321F));
    expect(palette.glassBackground, palette.surface);
    expect(palette.glassBorder, palette.borderSoft);
    expect(palette.gradientStart, palette.background);
    expect(palette.gradientEnd, palette.background);
    expect(semantic!.warning, const Color(0xFF7A5200));
    expect(semantic.success, const Color(0xFF3D6931));
    expect(semantic.info, const Color(0xFF2D6C89));
    expect(semantic.accent, palette.error);
    expect(theme.colorScheme.primary, palette.primary);
    expect(theme.colorScheme.onPrimary, palette.onPrimary);
    expect(theme.colorScheme.surface, palette.surface);
    expect(theme.colorScheme.onSurface, palette.textPrimary);
    expect(theme.colorScheme.error, palette.error);
    expect(theme.scaffoldBackgroundColor, palette.background);
  });

  test('dark theme exposes the approved V4 dark palette', () {
    final theme = AppTheme.dark;
    final palette = theme.extension<ExomThemePalette>();
    final semantic = theme.extension<ExomSemanticPalette>();

    expect(theme.brightness, Brightness.dark);
    expect(palette, isNotNull);
    expect(semantic, isNotNull);
    expect(palette!.background, _charcoal);
    expect(palette.background, AppColors.background);
    expect(palette.surface, const Color(0xFF191B19));
    expect(palette.surfaceElevated, const Color(0xFF222522));
    expect(palette.surfaceVariant, const Color(0xFF222522));
    expect(palette.borderSoft, const Color(0xFF363B32));
    expect(palette.divider, const Color(0xFF363B32));
    expect(palette.textPrimary, _bone);
    expect(palette.textSecondary, const Color(0xFFB7BCB3));
    expect(palette.textMuted, const Color(0xFFB7BCB3));
    expect(palette.textDisabled, const Color(0xFF9A9F96));
    expect(palette.primary, _lime);
    expect(palette.onPrimary, _charcoal);
    expect(palette.primarySoft, const Color(0xFF232B14));
    expect(palette.error, const Color(0xFFFF8A73));
    expect(palette.glassBackground, palette.surface);
    expect(palette.glassBorder, palette.borderSoft);
    expect(palette.gradientStart, palette.background);
    expect(palette.gradientEnd, palette.background);
    expect(semantic!.warning, const Color(0xFFE5BE58));
    expect(semantic.success, const Color(0xFF8CCB68));
    expect(semantic.info, const Color(0xFF7FB5D8));
    expect(semantic.accent, palette.error);
    expect(AppColors.primaryHover, const Color(0xFFC8F562));
    expect(AppColors.primaryPressed, const Color(0xFFA4DA2A));
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.primary, _lime);
    expect(theme.colorScheme.onPrimary, _charcoal);
    expect(theme.colorScheme.surface, palette.surface);
    expect(theme.colorScheme.onSurface, palette.textPrimary);
  });

  group('typography', () {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      final name = theme.brightness.name;

      test('$name uses DM Sans by default on every platform', () {
        expect(AppTheme.fontFamily, 'DMSans');
        expect(theme.textTheme.bodyMedium!.fontFamily, 'DMSans');
        expect(theme.textTheme.labelLarge!.fontFamily, 'DMSans');
      });

      test('$name display and large headlines use Barlow Condensed 800', () {
        final text = theme.textTheme;
        for (final style in [
          text.displayLarge!,
          text.displayMedium!,
          text.displaySmall!,
          text.headlineLarge!,
          text.headlineMedium!,
        ]) {
          expect(style.fontFamily, 'BarlowCondensed');
          expect(style.fontWeight, FontWeight.w800);
          expect(style.height, 1.0);
          expect(style.letterSpacing, closeTo(-0.02 * style.fontSize!, 1e-9));
        }
      });

      test('$name keeps slot sizes and DM Sans weights', () {
        final text = theme.textTheme;
        final sizes = {
          'displayLarge': (text.displayLarge!, 32.0),
          'displayMedium': (text.displayMedium!, 28.0),
          'displaySmall': (text.displaySmall!, 24.0),
          'headlineLarge': (text.headlineLarge!, 24.0),
          'headlineMedium': (text.headlineMedium!, 20.0),
          'headlineSmall': (text.headlineSmall!, 18.0),
          'titleLarge': (text.titleLarge!, 16.0),
          'titleMedium': (text.titleMedium!, 14.0),
          'titleSmall': (text.titleSmall!, 13.0),
          'bodyLarge': (text.bodyLarge!, 16.0),
          'bodyMedium': (text.bodyMedium!, 14.0),
          'bodySmall': (text.bodySmall!, 13.0),
          'labelLarge': (text.labelLarge!, 14.0),
          'labelMedium': (text.labelMedium!, 13.0),
          // Raised to the plan's 13 minimum in L1 (labelSmall was 10 in L0).
          'labelSmall': (text.labelSmall!, 13.0),
        };
        for (final entry in sizes.entries) {
          expect(entry.value.$1.fontSize, entry.value.$2, reason: entry.key);
          expect(entry.value.$1.fontSize, greaterThanOrEqualTo(13));
        }
        for (final style in [
          text.headlineSmall!,
          text.titleLarge!,
          text.titleMedium!,
          text.titleSmall!,
          text.labelLarge!,
          text.labelMedium!,
          text.labelSmall!,
        ]) {
          expect(style.fontFamily, 'DMSans');
          expect(style.fontWeight, FontWeight.w600);
        }
        for (final style in [text.bodyLarge!, text.bodyMedium!, text.bodySmall!]) {
          expect(style.fontFamily, 'DMSans');
          expect(style.fontWeight, FontWeight.w400);
        }
      });
    }
  });

  group('components', () {
    test('primary filled buttons are lime with a charcoal label', () {
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        for (final style in [
          theme.elevatedButtonTheme.style!,
          theme.filledButtonTheme.style!,
        ]) {
          expect(_resolve(style.backgroundColor), _lime);
          expect(_resolve(style.foregroundColor), _charcoal);
          expect(
            _resolve(style.backgroundColor, {WidgetState.pressed}),
            AppColors.primaryPressed,
          );
          expect(
            _resolve(style.backgroundColor, {WidgetState.hovered}),
            AppColors.primaryHover,
          );
          expect(style.minimumSize!.resolve({})!.height, 56);
          final shape = style.shape!.resolve({})! as RoundedRectangleBorder;
          expect(shape.borderRadius, BorderRadius.circular(4));
          final label = style.textStyle!.resolve({})!;
          expect(label.fontFamily, 'DMSans');
          expect(label.fontWeight, FontWeight.w600);
          expect(label.fontSize, 16);
          final side = style.side?.resolve({});
          if (theme.brightness == Brightness.light) {
            expect(side, const BorderSide(color: _charcoal, width: 1.5));
          } else {
            expect(side == null || side.style == BorderStyle.none, isTrue);
          }
        }
      }
    });

    test('outlined and text buttons use the text colour', () {
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        final palette = theme.extension<ExomThemePalette>()!;
        final outlined = theme.outlinedButtonTheme.style!;
        expect(_resolve(outlined.foregroundColor), palette.textPrimary);
        expect(
          outlined.side!.resolve({}),
          BorderSide(color: palette.textPrimary, width: 1.5),
        );
        expect(outlined.minimumSize!.resolve({})!.height, 56);
        final outlinedShape =
            outlined.shape!.resolve({})! as RoundedRectangleBorder;
        expect(outlinedShape.borderRadius, BorderRadius.circular(4));

        final textButton = theme.textButtonTheme.style!;
        expect(
          _resolve(textButton.foregroundColor),
          theme.brightness == Brightness.dark
              ? palette.textPrimary
              : const Color(0xFF4F6B00),
        );
      }
    });

    test('cards, inputs, sheets and dialogs follow the V4 shapes', () {
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        final palette = theme.extension<ExomThemePalette>()!;

        final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(cardShape.borderRadius, BorderRadius.zero);
        expect(cardShape.side, BorderSide(color: palette.borderSoft));
        expect(theme.cardTheme.elevation, 0);
        expect(theme.cardTheme.color, palette.surface);

        final input = theme.inputDecorationTheme;
        expect(input.filled, isTrue);
        expect(input.fillColor, palette.surfaceElevated);
        final enabled = input.enabledBorder! as OutlineInputBorder;
        expect(enabled.borderRadius, BorderRadius.circular(4));
        expect(enabled.borderSide, BorderSide(color: palette.borderSoft));
        final focused = input.focusedBorder! as OutlineInputBorder;
        expect(
          focused.borderSide,
          BorderSide(color: palette.textPrimary, width: 1.5),
        );
        final error = input.errorBorder! as OutlineInputBorder;
        expect(error.borderSide.color, palette.error);

        final sheetShape =
            theme.bottomSheetTheme.shape! as RoundedRectangleBorder;
        expect(
          sheetShape.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(20)),
        );
        expect(theme.bottomSheetTheme.backgroundColor, palette.surface);

        final dialogShape = theme.dialogTheme.shape! as RoundedRectangleBorder;
        expect(dialogShape.borderRadius, BorderRadius.circular(4));
      }
    });
  });
}
