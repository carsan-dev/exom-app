// L6 E-D1 / INT-D1: in the set-logging sheet, after a weight validation
// error, tapping the weight field again opens the keyboard and the field and
// its whole error must stay visible above the keyboard. Since L6 A-O1
// (variant B) the weight row and its error live in the pinned footer, which
// sits on top of the keyboard and scrolls inside itself when it does not fit.
// The keyboard is simulated with the view's insets, as the engine reports it,
// so the focused field reacts to the metrics change like on a device.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

final _weight = find.byKey(const Key('set-sheet-weight-field'));
final _save = find.byKey(const Key('set-sheet-save'));

/// The pinned footer (Reps, Peso, Guardar and the quiet actions).
final _footer = find.byKey(const Key('set-sheet-footer'));

/// The visible part of the footer (its scroll view).
Rect _footerViewport(WidgetTester tester) => tester.getRect(
  find.descendant(of: _footer, matching: find.byType(Scrollable)).first,
);

// Samsung S25: 1080 x 2340 px; the Samsung keyboard starts at y = 1330 px.
const double _dpr = 2.625;
const Size _physical = Size(1080, 2340);
const double _keyboardPx = 2340 - 1330;

Future<void> _openSheet(WidgetTester tester, Locale locale) async {
  await loadRedesignFonts();
  tester.view.physicalSize = _physical;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () => showSetPerformanceSheet(
                context,
                AppLocalizations.of(context),
                setNumber: 2,
                prescribedReps: '8 reps · RIR 2',
                repsRequired: false,
                timeUnit: null,
                previousPerformance: const SetPerformance(
                  setNumber: 2,
                  reps: 8,
                  weightKg: 60,
                  rir: 2,
                ),
                targetCount: 8,
                targetRir: 2,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

/// Raises the keyboard over several frames, as the engine reports it.
Future<void> _raiseKeyboard(WidgetTester tester) async {
  const steps = 8;
  for (var i = 1; i <= steps; i++) {
    tester.view.viewInsets = FakeViewPadding(bottom: _keyboardPx * i / steps);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = FakeViewPadding.zero;
  await tester.pumpAndSettle();
}

/// [rect] is inside the visible footer and above the keyboard.
void _expectVisible(WidgetTester tester, Rect rect, String what) {
  final viewport = _footerViewport(tester);
  final keyboardTop = (_physical.height - _keyboardPx) / _dpr;
  expect(viewport.bottom, lessThanOrEqualTo(keyboardTop + 0.5));
  expect(
    rect.top,
    greaterThanOrEqualTo(viewport.top - 0.5),
    reason: '$what must not be scrolled out of the top of the footer',
  );
  expect(
    rect.bottom,
    lessThanOrEqualTo(viewport.bottom + 0.5),
    reason: '$what must be fully visible above the keyboard',
  );
}

void _expectWeightAboveFooter(WidgetTester tester) {
  expect(find.descendant(of: _footer, matching: _weight), findsOneWidget);
  _expectVisible(tester, tester.getRect(_weight), 'the focused weight field');
}

/// The weight error message (it quotes what was typed).
Finder get _weightError => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.data?.contains('62.5,5') ?? false),
);

/// INT-D1: the whole error message under the focused weight field, not only
/// the field and its caret, must be visible above the keyboard.
void _expectWeightErrorAboveFooter(WidgetTester tester) {
  _expectWeightAboveFooter(tester);
  expect(find.descendant(of: _footer, matching: _weightError), findsOneWidget);
  _expectVisible(
    tester,
    tester.getRect(_weightError),
    'the weight error under the focused field',
  );
}

void main() {
  for (final locale in const [Locale('es'), Locale('en')]) {
    testWidgets('E-D1 ($locale): after a weight error, tapping the field '
        'again keeps it visible in the footer above the keyboard', (
      tester,
    ) async {
      await _openSheet(tester, locale);
      await tester.enterText(_weight, '62.5,5');
      await tester.pump();
      await tester.tap(_save);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && (widget.data?.contains('62.5,5') ?? false),
        ),
        findsOneWidget,
        reason: 'the weight error is shown',
      );
      expect(tester.widget<TextField>(_weight).focusNode!.hasFocus, isTrue);

      // The keyboard was dismissed; the user taps the weight field again.
      await _hideKeyboard(tester);
      await tester.tap(_weight);
      await _raiseKeyboard(tester);

      _expectWeightAboveFooter(tester);
    });
  }

  testWidgets('INT-D1 (es): after a weight error, tapping the field again '
      'keeps the field and its whole two-line error above the keyboard', (
    tester,
  ) async {
    await _openSheet(tester, const Locale('es'));
    await tester.enterText(_weight, '62.5,5');
    await tester.pump();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(_weightError, findsOneWidget);

    await _hideKeyboard(tester);
    await tester.tap(_weight);
    await _raiseKeyboard(tester);

    _expectWeightErrorAboveFooter(tester);
  });

  // Regression guard for the Save path; it also passes without the INT-D1 fix.
  testWidgets('guard (es): when the weight error appears with the field '
      'focused and the keyboard up, the whole error is above the keyboard', (
    tester,
  ) async {
    await _openSheet(tester, const Locale('es'));
    await tester.tap(_weight);
    await _raiseKeyboard(tester);
    await tester.enterText(_weight, '62.5,5');
    await tester.pump();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(_weightError, findsOneWidget);

    _expectWeightErrorAboveFooter(tester);
  });

  testWidgets('E-D1 control: without an error, focusing the weight field '
      'with the keyboard keeps it above the keyboard', (tester) async {
    await _openSheet(tester, const Locale('es'));
    await tester.tap(_weight);
    await _raiseKeyboard(tester);

    _expectWeightAboveFooter(tester);
  });
}
