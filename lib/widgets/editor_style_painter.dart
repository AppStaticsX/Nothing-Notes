import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/editor_style.dart';


class EditorStylePainter extends CustomPainter {
  final EditorStyle style;
  final Color lineColor;

  EditorStylePainter({required this.style, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    switch (style) {
      case EditorStyle.plain:
        break;
      case EditorStyle.notebook:
        _drawNotebookLines(canvas, size, paint);
        break;
      case EditorStyle.cross:
        _drawCrossGrid(canvas, size, paint);
        break;
      case EditorStyle.dotted:
        _drawDottedGrid(canvas, size, paint);
        break;
      case EditorStyle.card:
        _drawCardBorder(canvas, size, paint);
        break;
    }
  }

  void _drawNotebookLines(Canvas canvas, Size size, Paint paint) {
    const spacing = 30.0;
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  void _drawCrossGrid(Canvas canvas, Size size, Paint paint) {
    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  void _drawDottedGrid(Canvas canvas, Size size, Paint paint) {
    const spacing = 20.0;
    paint.strokeCap = StrokeCap.round;
    paint.strokeWidth = 2;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawPoints(PointMode.points, [Offset(x, y)], paint);
      }
    }
  }

  void _drawCardBorder(Canvas canvas, Size size, Paint paint) {
    paint.strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}