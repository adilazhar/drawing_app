import 'package:flutter/material.dart';

class EraserIndicatorPainter extends CustomPainter {
  final Offset position;
  final double eraserSize;

  EraserIndicatorPainter(this.position, this.eraserSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(position, eraserSize / 2, paint);
    canvas.drawCircle(position, eraserSize / 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
