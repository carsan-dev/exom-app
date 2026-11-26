// A default SnackBarAction (no explicit colour) must be readable on the real
// SnackBar background of both themes (WCAG AA 4.5:1). Without
// snackBarTheme.actionTextColor the action falls back to
// colorScheme.inversePrimary (1.10:1 light, 1.22:1 dark).
import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wcag_contrast.dart';

Future<void> _checkAction(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Mensaje'),
                action: SnackBarAction(label: 'Accion', onPressed: () {}),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();

  final button = tester.widget<TextButton>(
    find.descendant(
      of: find.byType(SnackBarAction),
      matching: find.byType(TextButton),
    ),
  );
  final fg = button.style!.foregroundColor!.resolve(<WidgetState>{})!;
  final bg = theme.snackBarTheme.backgroundColor!;
  final ratio = contrastRatio(fg, bg);
  // ignore: avoid_print
  print('SNACK_ACTION ${hexRgb(fg)} on ${hexRgb(bg)} = '
      '${ratio.toStringAsFixed(2)}:1');
  expect(ratio, greaterThanOrEqualTo(4.5));
  expect(fg, theme.extension<ExomThemePalette>()!.primary);
}

void main() {
  testWidgets('SnackBarAction contrast, light theme', (tester) async {
    await _checkAction(tester, AppTheme.light);
  });

  testWidgets('SnackBarAction contrast, dark theme', (tester) async {
    await _checkAction(tester, AppTheme.dark);
  });

  test('main.dart retry action does not pin inversePrimary', () {
    // main.dart needs Firebase to mount, so guard the source instead.
    final source = File('lib/main.dart').readAsStringSync();
    expect(source.contains('inversePrimary'), isFalse);
  });
}
