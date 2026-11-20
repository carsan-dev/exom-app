// Tests for the expectNoLimeInk helper (L5 T0.1, D13).
import 'dart:ui' show PointMode;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'expect_no_lime_ink.dart';

ExomThemePalette get _light => AppTheme.light.extension<ExomThemePalette>()!;

enum _Op { stroke, fill, line, points }

class _LimePainter extends CustomPainter {
  const _LimePainter(this.op);
  final _Op op;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kLimeInk
      ..style = op == _Op.fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2;
    switch (op) {
      case _Op.stroke:
        canvas.drawRect(Offset.zero & size, paint);
      case _Op.fill:
        canvas.drawRect(Offset.zero & size, paint);
      case _Op.line:
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
      case _Op.points:
        canvas.drawPoints(PointMode.points, [Offset.zero], paint);
    }
  }

  @override
  bool shouldRepaint(_LimePainter oldDelegate) => oldDelegate.op != op;
}

Widget _painted(_Op op, {bool foreground = false}) => SizedBox(
  width: 40,
  height: 40,
  child: CustomPaint(
    painter: foreground ? null : _LimePainter(op),
    foregroundPainter: foreground ? _LimePainter(op) : null,
  ),
);

void main() {
  testWidgets('fails on lime text in the light theme', (tester) async {
    await pumpComponent(
      tester,
      const Text('Hecha', style: TextStyle(color: kLimeInk)),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('fails on a lime icon in the light theme', (tester) async {
    await pumpComponent(
      tester,
      const Icon(Icons.check, color: kLimeInk),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('fails on a lime thin line (border) in the light theme', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kLimeInk)),
        ),
        child: SizedBox(width: 40, height: 40),
      ),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('fails on a lime underline (decorationColor)', (tester) async {
    await pumpComponent(
      tester,
      const Text(
        'Hecha',
        style: TextStyle(
          color: Color(0xFF101111),
          decoration: TextDecoration.underline,
          decorationColor: kLimeInk,
        ),
      ),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('fails on a lime BorderDirectional side', (tester) async {
    await pumpComponent(
      tester,
      const DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: kLimeInk)),
        ),
        child: SizedBox(width: 40, height: 40),
      ),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('fails on a ShapeDecoration with a lime side', (tester) async {
    await pumpComponent(
      tester,
      const DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(side: BorderSide(color: kLimeInk)),
        ),
        child: SizedBox(width: 40, height: 40),
      ),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('fails on a Material shape with a lime side', (tester) async {
    await pumpComponent(
      tester,
      const Material(
        shape: RoundedRectangleBorder(side: BorderSide(color: kLimeInk)),
        child: SizedBox(width: 40, height: 40),
      ),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('fails on a CustomPainter lime stroke', (tester) async {
    await pumpComponent(
      tester,
      _painted(_Op.stroke),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('fails on a foregroundPainter lime stroke', (tester) async {
    await pumpComponent(
      tester,
      _painted(_Op.stroke, foreground: true),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('fails on a CustomPainter drawLine in lime', (tester) async {
    await pumpComponent(
      tester,
      _painted(_Op.line),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('fails on a CustomPainter drawPoints in lime', (tester) async {
    await pumpComponent(
      tester,
      _painted(_Op.points),
      brightness: Brightness.light,
    );
    expect(() => expectNoLimeInk(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('a CustomPainter lime fill is allowed', (tester) async {
    await pumpComponent(
      tester,
      _painted(_Op.fill),
      brightness: Brightness.light,
    );
    expectNoLimeInk(tester);
  });

  testWidgets('lime ColoredBox background with #101111 text passes', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const ColoredBox(
        color: kLimeInk,
        child: Text('Hoy', style: TextStyle(color: Color(0xFF101111))),
      ),
      brightness: Brightness.light,
    );
    expectNoLimeInk(tester);
  });

  testWidgets('passes with the light data colour #4F6B00', (tester) async {
    expect(_light.data, const Color(0xFF4F6B00));
    await pumpComponent(
      tester,
      Column(
        children: [
          Text('Hecha', style: TextStyle(color: _light.data)),
          Icon(Icons.check, color: _light.data),
        ],
      ),
      brightness: Brightness.light,
    );
    expectNoLimeInk(tester);
  });

  testWidgets('lime as a fill is allowed in the light theme', (tester) async {
    await pumpComponent(
      tester,
      ColoredBox(
        color: _light.limeFill,
        child: Text('Hoy', style: TextStyle(color: _light.onLimeFill)),
      ),
      brightness: Brightness.light,
    );
    expectNoLimeInk(tester);
  });

  testWidgets('lime text is the data colour in dark: no failure', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const Text('Hecha', style: TextStyle(color: kLimeInk)),
    );
    expectNoLimeInk(tester);
  });
}
