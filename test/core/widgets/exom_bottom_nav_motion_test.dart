// T0.5 M2: the active bar of the bottom navigation slides 200 ms between
// tabs; with reduced motion it cuts. The tab callback is never delayed.
import 'package:exom_app/core/widgets/exom_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

const _labels = ['Retos', 'Entrenar', 'Inicio', 'Dietas', 'Calendario'];

class _Host extends StatefulWidget {
  const _Host({required this.taps});

  final List<int> taps;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: ExomBottomNav(
        selectedIndex: _selected,
        onTap: (i) {
          widget.taps.add(i);
          setState(() => _selected = i);
        },
      ),
    );
  }
}

Finder get _indicator => find.descendant(
  of: find.byType(ExomBottomNav),
  matching: find.byType(ColoredBox),
);

/// Centre of tab slot [i] (the edge labels are inset, the bar is not).
double _labelCenter(WidgetTester tester, int i) {
  final nav = tester.getRect(find.byType(ExomBottomNav));
  final slot = nav.width / 5;
  return nav.left + slot * i + slot / 2;
}

void main() {
  testWidgets('the active bar slides 200 ms to the new tab', (tester) async {
    final taps = <int>[];
    await pumpComponent(tester, _Host(taps: taps), wrapInScaffold: false);
    expect(
      tester.getCenter(_indicator).dx,
      closeTo(_labelCenter(tester, 0), 0.5),
    );

    await tester.tap(find.text(_labels[3]));
    // The tap acts at once.
    expect(taps, [3]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = tester.getCenter(_indicator).dx;
    expect(mid, greaterThan(_labelCenter(tester, 0) + 1));
    expect(mid, lessThan(_labelCenter(tester, 3) - 1));
    expect(_indicator, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getCenter(_indicator).dx,
      closeTo(_labelCenter(tester, 3), 0.5),
    );
    expect(tester.getSize(_indicator).height, 2);
  });

  testWidgets('a second tap mid-slide retargets at once (interruptible)', (
    tester,
  ) async {
    final taps = <int>[];
    await pumpComponent(tester, _Host(taps: taps), wrapInScaffold: false);
    await tester.tap(find.text(_labels[4]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text(_labels[1]));
    expect(taps, [4, 1]);
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(_indicator).dx,
      closeTo(_labelCenter(tester, 1), 0.5),
    );
  });

  testWidgets('right-to-left: the bar sits above the selected tab', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      Directionality(
        textDirection: TextDirection.rtl,
        child: _Host(taps: <int>[]),
      ),
      wrapInScaffold: false,
    );
    // Slot 0 is the rightmost one in right-to-left.
    expect(
      tester.getCenter(_indicator).dx,
      closeTo(_labelCenter(tester, 4), 0.5),
    );
  });

  testWidgets('reduced motion: the bar cuts to the new tab', (tester) async {
    await pumpComponent(
      tester,
      _Host(taps: <int>[]),
      wrapInScaffold: false,
      disableAnimations: true,
    );
    await tester.tap(find.text(_labels[3]));
    await tester.pump();
    expect(
      tester.getCenter(_indicator).dx,
      closeTo(_labelCenter(tester, 3), 0.5),
    );
  });
}
