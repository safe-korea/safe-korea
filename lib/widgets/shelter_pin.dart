import 'package:flutter/material.dart';

import 'common.dart';

/// A code-drawn shelter symbol shared by Flutter and native map markers.
class ShelterPin extends StatelessWidget {
  const ShelterPin({super.key, this.selected = false});
  final bool selected;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: ShelterPinPainter(selected: selected),
    size: const Size(44, 56),
  );
}

class ShelterPinPainter extends CustomPainter {
  const ShelterPinPainter({this.selected = false});
  final bool selected;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 44, size.height / 56);
    final pin = Path()
      ..moveTo(22, 54)
      ..cubicTo(17, 46, 3, 34, 3, 23)
      ..cubicTo(3, -3, 41, -3, 41, 23)
      ..cubicTo(41, 34, 27, 46, 22, 54)
      ..close();
    canvas.drawShadow(pin, Colors.black, 4, true);
    canvas.drawPath(
      pin,
      Paint()..color = selected ? const Color(0xFFC95B1C) : teal,
    );
    canvas.drawPath(
      pin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(11, 23)
        ..lineTo(22, 14)
        ..lineTo(33, 23),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(14, 23)
        ..lineTo(14, 32)
        ..lineTo(30, 32)
        ..lineTo(30, 23),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(20, 32)
        ..lineTo(20, 26)
        ..lineTo(24, 26)
        ..lineTo(24, 32),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShelterPinPainter oldDelegate) =>
      oldDelegate.selected != selected;
}
