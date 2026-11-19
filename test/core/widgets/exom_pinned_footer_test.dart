import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<Widget> buttons,
  Size size = const Size(320, 568),
  double textScale = 2.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: const Center(child: Text('content', key: Key('content'))),
        bottomNavigationBar: ExomPinnedFooter(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: buttons),
        ),
      ),
    ),
  );
}

List<Widget> _buttons(int count) => [
  for (var i = 0; i < count; i++)
    SizedBox(
      key: Key('button-$i'),
      height: 120,
      width: double.infinity,
      child: ElevatedButton(onPressed: () {}, child: Text('Action $i')),
    ),
];

void main() {
  testWidgets('keeps its content size when it fits', (tester) async {
    await _pump(tester, buttons: _buttons(1), size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    // 120 of content + 24 of padding (the hairline takes no space).
    expect(tester.getSize(find.byType(ExomPinnedFooter)).height, 144);
  });

  testWidgets('stops at 40 % of the screen and scrolls its content', (
    tester,
  ) async {
    await _pump(tester, buttons: _buttons(4));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(ExomPinnedFooter)).height,
      lessThanOrEqualTo(568 * kExomPinnedFooterMaxHeightFraction),
    );
    expect(find.byKey(const Key('content')).hitTestable(), findsOneWidget);

    final last = find.byKey(const Key('button-3'));
    expect(last.hitTestable(), findsNothing);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(last.hitTestable(), findsOneWidget);
  });
}
