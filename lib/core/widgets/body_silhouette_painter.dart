import 'package:flutter/material.dart';

import 'package:exom_app/core/theme/app_theme.dart';

class BodySilhouettePainter extends CustomPainter {
  final bool isBack;

  const BodySilhouettePainter({this.isBack = false});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ── Head (oval) ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.055),
        width: w * 0.28,
        height: h * 0.07,
      ),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.055),
        width: w * 0.28,
        height: h * 0.07,
      ),
      stroke,
    );

    // Anchor points shared by body and arms
    final lSh = Offset(cx - w * 0.32, h * 0.165);
    final lPit = Offset(cx - w * 0.22, h * 0.20);
    final rSh = Offset(cx + w * 0.32, h * 0.165);
    final rPit = Offset(cx + w * 0.22, h * 0.20);

    // ── Torso + legs ──
    final body = Path()..moveTo(cx - w * 0.08, h * 0.085);
    body.quadraticBezierTo(cx - w * 0.10, h * 0.13, lSh.dx, lSh.dy);
    body.quadraticBezierTo(cx - w * 0.28, h * 0.18, lPit.dx, lPit.dy);
    body.quadraticBezierTo(cx - w * 0.20, h * 0.28, cx - w * 0.17, h * 0.36);
    body.quadraticBezierTo(cx - w * 0.17, h * 0.40, cx - w * 0.22, h * 0.45);
    body.quadraticBezierTo(cx - w * 0.24, h * 0.52, cx - w * 0.20, h * 0.63);
    body.quadraticBezierTo(cx - w * 0.20, h * 0.70, cx - w * 0.18, h * 0.78);
    body.quadraticBezierTo(cx - w * 0.16, h * 0.84, cx - w * 0.14, h * 0.88);
    body.lineTo(cx - w * 0.20, h * 0.91);
    body.lineTo(cx - w * 0.08, h * 0.91);
    body.quadraticBezierTo(cx - w * 0.08, h * 0.82, cx - w * 0.10, h * 0.70);
    body.quadraticBezierTo(cx - w * 0.06, h * 0.55, cx - w * 0.05, h * 0.48);
    body.lineTo(cx + w * 0.05, h * 0.48);
    body.quadraticBezierTo(cx + w * 0.06, h * 0.55, cx + w * 0.10, h * 0.70);
    body.quadraticBezierTo(cx + w * 0.08, h * 0.82, cx + w * 0.08, h * 0.91);
    body.lineTo(cx + w * 0.20, h * 0.91);
    body.lineTo(cx + w * 0.14, h * 0.88);
    body.quadraticBezierTo(cx + w * 0.16, h * 0.84, cx + w * 0.18, h * 0.78);
    body.quadraticBezierTo(cx + w * 0.20, h * 0.70, cx + w * 0.20, h * 0.63);
    body.quadraticBezierTo(cx + w * 0.24, h * 0.52, cx + w * 0.22, h * 0.45);
    body.quadraticBezierTo(cx + w * 0.17, h * 0.40, cx + w * 0.17, h * 0.36);
    body.quadraticBezierTo(cx + w * 0.20, h * 0.28, rPit.dx, rPit.dy);
    body.quadraticBezierTo(cx + w * 0.28, h * 0.18, rSh.dx, rSh.dy);
    body.quadraticBezierTo(cx + w * 0.10, h * 0.13, cx + w * 0.08, h * 0.085);
    body.close();

    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);

    // ── Left arm ──
    final lArm = Path()..moveTo(lSh.dx, lSh.dy);
    lArm.quadraticBezierTo(cx - w * 0.38, h * 0.20, cx - w * 0.40, h * 0.30);
    lArm.quadraticBezierTo(cx - w * 0.42, h * 0.37, cx - w * 0.40, h * 0.43);
    lArm.quadraticBezierTo(cx - w * 0.38, h * 0.46, cx - w * 0.34, h * 0.43);
    lArm.quadraticBezierTo(cx - w * 0.34, h * 0.36, cx - w * 0.32, h * 0.28);
    lArm.quadraticBezierTo(cx - w * 0.28, h * 0.22, lPit.dx, lPit.dy);
    lArm.close();
    canvas.drawPath(lArm, fill);
    canvas.drawPath(lArm, stroke);

    // ── Right arm ──
    final rArm = Path()..moveTo(rSh.dx, rSh.dy);
    rArm.quadraticBezierTo(cx + w * 0.38, h * 0.20, cx + w * 0.40, h * 0.30);
    rArm.quadraticBezierTo(cx + w * 0.42, h * 0.37, cx + w * 0.40, h * 0.43);
    rArm.quadraticBezierTo(cx + w * 0.38, h * 0.46, cx + w * 0.34, h * 0.43);
    rArm.quadraticBezierTo(cx + w * 0.34, h * 0.36, cx + w * 0.32, h * 0.28);
    rArm.quadraticBezierTo(cx + w * 0.28, h * 0.22, rPit.dx, rPit.dy);
    rArm.close();
    canvas.drawPath(rArm, fill);
    canvas.drawPath(rArm, stroke);

    // ── Back view detail: spine + shoulder blade lines ──
    if (isBack) {
      final detail = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx, h * 0.09), Offset(cx, h * 0.44), detail);
      canvas.drawLine(
        Offset(cx - w * 0.12, h * 0.20),
        Offset(cx - w * 0.06, h * 0.28),
        detail,
      );
      canvas.drawLine(
        Offset(cx + w * 0.12, h * 0.20),
        Offset(cx + w * 0.06, h * 0.28),
        detail,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BodySilhouettePainter oldDelegate) =>
      oldDelegate.isBack != isBack;
}
