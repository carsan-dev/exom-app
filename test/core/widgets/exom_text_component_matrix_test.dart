import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

void main() {
  const long = 'Un texto largo que no cabe en una sola línea de ancho 120';

  Future<void> pump(WidgetTester tester, Text text) =>
      pumpComponent(tester, SizedBox(width: 120, child: text), width: 200);

  testWidgets('expectNoEllipsis accepts text that wraps and shows everything', (
    tester,
  ) async {
    await pump(tester, const Text(long));
    expectNoEllipsis(tester);
  });

  testWidgets('expectNoEllipsis accepts a non-wrapping visible paragraph', (
    tester,
  ) async {
    await pump(
      tester,
      const Text('12', softWrap: false, overflow: TextOverflow.visible),
    );
    expectNoEllipsis(tester);
  });

  testWidgets('expectNoEllipsis fails on ellipsis with maxLines', (
    tester,
  ) async {
    await pump(
      tester,
      const Text(long, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    expect(() => expectNoEllipsis(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('expectNoEllipsis fails on ellipsis without maxLines', (
    tester,
  ) async {
    await pump(tester, const Text(long, overflow: TextOverflow.ellipsis));
    expect(() => expectNoEllipsis(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('expectNoEllipsis fails on softWrap false with clip', (
    tester,
  ) async {
    await pump(tester, const Text(long, softWrap: false));
    expect(() => expectNoEllipsis(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('expectNoEllipsis fails when maxLines dropped lines', (
    tester,
  ) async {
    await pump(
      tester,
      const Text(long, maxLines: 1, overflow: TextOverflow.visible),
    );
    expect(() => expectNoEllipsis(tester), throwsA(isA<TestFailure>()));
  });
}
