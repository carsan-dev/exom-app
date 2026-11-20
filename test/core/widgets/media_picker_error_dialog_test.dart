// Skin of the shared media-picker dialog (L5 T0.3b): same text, same actions
// and same returned values as before; only tokens change.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme/wcag_contrast.dart';
import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';
import 'expect_no_lime_ink.dart';

Future<void> _open(
  WidgetTester tester,
  Object error, {
  required bool canUseGallery,
  required List<MediaPickerRecoveryAction> results,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  double width = 390,
  double height = 844,
}) async {
  await pumpComponent(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () async => results.add(
          await showMediaPickerErrorDialog(
            context,
            error,
            canUseGallery: canUseGallery,
          ),
        ),
        child: const Text('open'),
      ),
    ),
    brightness: brightness,
    textScale: textScale,
    width: width,
    height: height,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final permission = PlatformException(code: 'permission_denied');

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;

    testWidgets('skin: square-ish dialog with hairline, display title '
        '(${brightness.name})', (tester) async {
      await _open(
        tester,
        permission,
        canUseGallery: true,
        results: [],
        brightness: brightness,
      );
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(4));
      expect(shape.side.color, palette.borderSoft);
      expect(shape.side.width, 1);
      expect(dialog.titleTextStyle?.fontFamily, ExomType.section.fontFamily);
      expect(dialog.titleTextStyle?.color, palette.textPrimary);
      expect(dialog.contentTextStyle?.color, palette.textSecondary);
    });
  }

  testWidgets('permission error: same text and actions, 48 dp targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, permission, canUseGallery: true, results: []);
    expect(find.text('Permiso necesario'), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(3)); // opener + 2 actions
    expect(find.byType(FilledButton), findsOneWidget);
    for (final finder in [
      find.byType(FilledButton),
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ),
    ]) {
      for (final element in finder.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    }
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  testWidgets('returned values are unchanged', (tester) async {
    final results = <MediaPickerRecoveryAction>[];
    await _open(tester, permission, canUseGallery: true, results: results);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await _open(tester, permission, canUseGallery: true, results: results);
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          )
          .at(1),
    );
    await tester.pumpAndSettle();
    await _open(
      tester,
      StateError('x'),
      canUseGallery: false,
      results: results,
    );
    await tester.tapAt(const Offset(2, 2)); // barrier dismiss
    await tester.pumpAndSettle();
    expect(results, [
      MediaPickerRecoveryAction.retry,
      MediaPickerRecoveryAction.gallery,
      MediaPickerRecoveryAction.cancel,
    ]);
  });

  testWidgets('non permission error without gallery shows only retry', (
    tester,
  ) async {
    await _open(tester, StateError('x'), canUseGallery: false, results: []);
    expect(find.text('No se pudo abrir el archivo'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ),
      findsNothing,
    );
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('filled action keeps the theme height; text actions are 48 dp', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final themeHeight = themeFor(
        brightness,
      ).filledButtonTheme.style!.minimumSize!.resolve(<WidgetState>{})!.height;
      expect(themeHeight, 56);
      await _open(
        tester,
        permission,
        canUseGallery: true,
        results: [],
        brightness: brightness,
      );
      expect(tester.getSize(find.byType(FilledButton)).height, themeHeight);
      final textActions = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      );
      expect(textActions, findsNWidgets(2));
      for (final element in textActions.evaluate()) {
        expect(
          tester.getSize(find.byWidget(element.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('settings action is pressed and returns cancel', (tester) async {
    final results = <MediaPickerRecoveryAction>[];
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.exommethod.exom/app_settings'),
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.exommethod.exom/app_settings'),
        null,
      ),
    );
    await _open(tester, permission, canUseGallery: true, results: results);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(calls, ['open']);
    expect(results, [MediaPickerRecoveryAction.cancel]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final width in const [320.0, 360.0]) {
    for (final scale in const [1.0, 1.3, 1.6]) {
      testWidgets('${width.toInt()} dp at $scale x: no overflow, no ellipsis', (
        tester,
      ) async {
        await _open(
          tester,
          permission,
          canUseGallery: true,
          results: [],
          width: width,
          textScale: scale,
        );
        expectNoOverflow(tester);
        expectNoEllipsis(tester);
      });
    }
  }

  for (final brightness in Brightness.values) {
    final palette = themeFor(brightness).extension<ExomThemePalette>()!;
    testWidgets('320 dp at 2.0 x: content reachable by scroll '
        '(${brightness.name})', (tester) async {
      await _open(
        tester,
        permission,
        canUseGallery: true,
        results: [],
        width: 320,
        height: 480,
        textScale: 2.0,
        brightness: brightness,
      );
      expectNoOverflow(tester);
      final scrollable = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsWidgets);
      for (final element in scrollable.evaluate()) {
        final position = tester
            .state<ScrollableState>(find.byWidget(element.widget))
            .position;
        await tester.drag(
          find.byWidget(element.widget),
          const Offset(0, -2000),
        );
        await tester.pump();
        expect(position.pixels, position.maxScrollExtent);
      }
      expectNoOverflow(tester);
      expectNoEllipsis(tester);
      final screen = Offset.zero & const Size(320, 480);
      for (final label in ['Ajustes', 'Desde galería', 'Reintentar']) {
        final finder = find.text(label, skipOffstage: false);
        expect(finder, findsOneWidget, reason: label);
        await tester.ensureVisible(finder);
        await tester.pump();
        final rect = tester.getRect(finder);
        expect(screen.contains(rect.topLeft), isTrue, reason: label);
        expect(screen.contains(rect.bottomRight), isTrue, reason: label);
      }
    });

    // Computed from the colours the dialog really uses: the rendered-text
    // guideline samples anti-aliased glyph pixels and misreads thin text.
    testWidgets('text contrast on the panel (${brightness.name})', (
      tester,
    ) async {
      await _open(
        tester,
        permission,
        canUseGallery: true,
        results: [],
        brightness: brightness,
      );
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final panel = dialog.backgroundColor!;
      expect(panel, palette.surface);
      expect(
        contrastRatio(dialog.titleTextStyle!.color!, panel),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(dialog.contentTextStyle!.color!, panel),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  testWidgets('no lime ink in the light theme', (tester) async {
    await _open(
      tester,
      permission,
      canUseGallery: true,
      results: [],
      brightness: Brightness.light,
    );
    expectNoLimeInk(tester);
  });

  testWidgets('160 % text does not overflow', (tester) async {
    await _open(
      tester,
      permission,
      canUseGallery: true,
      results: [],
      textScale: 1.6,
    );
    expectNoOverflow(tester);
  });
}
