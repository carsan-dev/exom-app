// L5-C5b selected-zones summary of the body map: one line (at most two) under
// the figure instead of a chip per zone. The payload is unchanged: zones are
// still toggled by tapping the figure and `onChanged` gets the same ids in
// selection order.
import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/exom_component_harness.dart';

const _viewBox = Size(340, 720);
const _summary = ValueKey('recap-zones-summary');

const _four = <String>[
  'shoulder_left_front',
  'quadriceps_right',
  'lower_back',
  'hamstrings_left',
];

List<String> _first20(Locale locale) => RecapAnatomyZone.values
    .take(20)
    .map((z) => locale.languageCode == 'es' ? z.spanishLabel : z.englishLabel)
    .toList();

class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  var values = <String>[];
  final emitted = <List<String>>[];

  Future<void> pump({
    List<String> initial = const [],
    Locale locale = const Locale('es'),
    double width = 360,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    values = [...initial];
    await pumpComponent(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setState) => RecapBodyMapField(
                  label: 'Zonas',
                  helperText: 'Toca',
                  values: values,
                  onChanged: (next) {
                    emitted.add(next);
                    setState(() => values = next);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      width: width,
      height: 1400,
      locale: locale,
      disableAnimations: true,
    );
  }

  Finder get paragraphs => find.descendant(
    of: find.byKey(_summary),
    matching: find.byType(RichText),
  );

  RenderParagraph get paragraph =>
      tester.renderObject<RenderParagraph>(paragraphs);

  String get text => paragraph.text.toPlainText();

  int get lines {
    final box = paragraph;
    final lineHeight = box.getFullHeightForCaret(const TextPosition(offset: 0));
    return (box.size.height / lineHeight).round();
  }

  Future<void> tapZone(String id) async {
    final figure = tester.getRect(
      find.descendant(
        of: find.byType(RecapAnatomySelector),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter != null && w.size.height > 200,
        ),
      ),
    );
    final centre = RecapAnatomySelector.debugZoneCentre(id)!;
    await tester.tapAt(
      figure.topLeft +
          Offset(
            centre.dx * figure.width / _viewBox.width,
            centre.dy * figure.height / _viewBox.height,
          ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('summary of the chosen zones', () {
    testWidgets('empty: a placeholder keeps the block, no chips', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      expect(find.text('Sin zonas marcadas'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.textContaining('Zonas elegidas'), findsNothing);
    });

    testWidgets('empty in English', (tester) async {
      final h = _Harness(tester);
      await h.pump(locale: const Locale('en'));
      expect(find.text('No areas selected'), findsOneWidget);
    });

    testWidgets('4 zones: count and every label, in selection order', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(initial: _four);
      expect(
        h.text,
        '4 zonas · Hombro izquierdo (delante) · Cuádriceps derecho · Lumbar · '
        'Isquio izquierdo',
      );
      expect(h.lines, lessThanOrEqualTo(2));
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('4 zones in English', (tester) async {
      final h = _Harness(tester);
      await h.pump(initial: _four, locale: const Locale('en'));
      expect(
        h.text,
        '4 areas · Left shoulder (front) · Right quadriceps · Lower back · '
        'Left hamstring',
      );
    });

    testWidgets('the count is bold, labels are not', (tester) async {
      final h = _Harness(tester);
      await h.pump(initial: _four);
      final spans = <TextSpan>[];
      (h.paragraph.text as TextSpan).visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });
      final count = spans.firstWhere((s) => s.text == '4 zonas');
      final label = spans.firstWhere(
        (s) => s.text?.contains('Lumbar') ?? false,
      );
      expect(count.style?.fontWeight, FontWeight.w700);
      expect(label.style?.fontWeight, isNot(FontWeight.w700));
      expect(count.style?.color, isNot(label.style?.color));
    });

    for (final (name, scaler) in <(String, TextScaler)>[
      ('360 dp', TextScaler.noScaling),
      ('360 dp at 2.0x', const AndroidNonlinearTextScaler(2.0)),
    ]) {
      for (final locale in const [Locale('es'), Locale('en')]) {
        testWidgets(
          '20 zones fit in two lines with the remaining count ($name, '
          '${locale.languageCode})',
          (tester) async {
            final h = _Harness(tester);
            final ids = RecapAnatomyZone.values.take(20).map((z) => z.id);
            await h.pump(
              initial: ids.toList(),
              locale: locale,
              textScaler: scaler,
            );
            final es = locale.languageCode == 'es';
            expect(h.lines, lessThanOrEqualTo(2));
            final parts = h.text.split(' · ');
            expect(parts.first, es ? '20 zonas' : '20 areas');
            final tail = RegExp(
              es ? r'^\+(\d+) más$' : r'^\+(\d+) more$',
            ).firstMatch(parts.last);
            expect(tail, isNotNull, reason: h.text);
            final shown = parts.sublist(1, parts.length - 1);
            expect(shown, isNotEmpty);
            expect(int.parse(tail!.group(1)!), 20 - shown.length);
            // Whole labels, in selection order.
            expect(shown, _first20(locale).take(shown.length).toList());
          },
        );
      }
    }

    testWidgets('a larger text scale shows fewer labels and recomputes N', (
      tester,
    ) async {
      final ids = RecapAnatomyZone.values.take(20).map((z) => z.id).toList();
      final h = _Harness(tester);
      await h.pump(initial: ids);
      final normal = h.text.split(' · ').length;
      await h.pump(
        initial: ids,
        textScaler: const AndroidNonlinearTextScaler(2.0),
      );
      expect(h.text.split(' · ').length, lessThan(normal));
    });

    testWidgets('semantics reads the full list, not the truncated one', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = _Harness(tester);
      await h.pump(initial: _four);
      final node = tester.getSemantics(find.byKey(_summary));
      expect(
        node.label,
        '4 zonas: Hombro izquierdo (delante), Cuádriceps derecho, Lumbar, '
        'Isquio izquierdo',
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);

      final ids = RecapAnatomyZone.values.take(20).map((z) => z.id).toList();
      await h.pump(initial: ids);
      final full = tester.getSemantics(find.byKey(_summary)).label;
      expect(full, startsWith('20 zonas: '));
      expect(full, isNot(contains('más')));
      expect(full, contains(_first20(const Locale('es')).last));
      handle.dispose();
    });

    testWidgets('semantics in English', (tester) async {
      final handle = tester.ensureSemantics();
      final h = _Harness(tester);
      await h.pump(initial: _four, locale: const Locale('en'));
      expect(
        tester.getSemantics(find.byKey(_summary)).label,
        '4 areas: Left shoulder (front), Right quadriceps, Lower back, '
        'Left hamstring',
      );
      handle.dispose();
    });

    testWidgets('zones are deselected on the figure; payload is unchanged', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(initial: _four);
      await h.tapZone('quadriceps_right');
      expect(h.emitted.single, [
        'shoulder_left_front',
        'lower_back',
        'hamstrings_left',
      ]);
      expect(
        h.text,
        startsWith('3 zonas · Hombro izquierdo (delante) · Lumbar'),
      );
    });

    testWidgets('the first selection replaces the placeholder', (tester) async {
      final h = _Harness(tester);
      await h.pump();
      await h.tapZone('quadriceps_right');
      expect(h.emitted.single, ['quadriceps_right']);
      expect(find.text('Sin zonas marcadas'), findsNothing);
      expect(h.text, '1 zona · Cuádriceps derecho');
    });
  });
}
