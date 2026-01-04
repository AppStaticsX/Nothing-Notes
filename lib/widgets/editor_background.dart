import 'dart:ui';

import 'package:flutter/material.dart';
import '../models/editor_style.dart';

class EditorBackground extends StatelessWidget {
  final EditorStyle style;
  final Color lineColor;
  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
  final double marginLineOffset;

  const EditorBackground({
    super.key,
    required this.style,
    required this.lineColor,
    this.fontSize = 24.0,
    this.lineHeight = 1.5,
    this.fontFamily,
    this.marginLineOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackgroundPainter(
        style: style,
        lineColor: lineColor,
        fontSize: fontSize,
        lineHeight: lineHeight,
        fontFamily: fontFamily,
        marginLineOffset: marginLineOffset,
      ),
      child: Container(),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final EditorStyle style;
  final Color lineColor;
  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
  final double marginLineOffset;

  // Cache for expensive TextPainter calculations
  double? _cachedBaselineOffset;
  double? _cachedLineHeight;
  double? _cachedFontSize;
  double? _cachedLineHeightMultiplier;
  String? _cachedFontFamily;

  _BackgroundPainter({
    required this.style,
    required this.lineColor,
    required this.fontSize,
    required this.lineHeight,
    this.fontFamily,
    required this.marginLineOffset,
  });

  // Calculate the exact baseline position using TextPainter (with caching)
  double _calculateBaselineOffset() {
    // Check if we need to recalculate
    if (_cachedBaselineOffset == null ||
        _cachedFontSize != fontSize ||
        _cachedLineHeightMultiplier != lineHeight ||
        _cachedFontFamily != fontFamily) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Ag',
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: fontFamily,
            height: lineHeight,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Cache the result and parameters
      _cachedBaselineOffset = textPainter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      _cachedFontSize = fontSize;
      _cachedLineHeightMultiplier = lineHeight;
      _cachedFontFamily = fontFamily;
    }

    return _cachedBaselineOffset!;
  }

  // Calculate the actual line height (fontSize * lineHeight multiplier) with caching
  double get _actualLineHeight {
    // Check if we need to recalculate
    if (_cachedLineHeight == null ||
        _cachedFontSize != fontSize ||
        _cachedLineHeightMultiplier != lineHeight ||
        _cachedFontFamily != fontFamily) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Ag',
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: fontFamily,
            height: lineHeight,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Cache the result and parameters
      _cachedLineHeight = textPainter.height;
      _cachedFontSize = fontSize;
      _cachedLineHeightMultiplier = lineHeight;
      _cachedFontFamily = fontFamily;
    }

    return _cachedLineHeight!;
  }

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
    // Calculate exact baseline position
    final baselineOffset = _calculateBaselineOffset();
    final actualLineHeight = _actualLineHeight;

    // Draw horizontal lines at baseline positions
    double y = baselineOffset;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += actualLineHeight;
    }

    // Draw margin line
    final marginPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(marginLineOffset, 0),
      Offset(marginLineOffset, size.height),
      marginPaint,
    );
  }

  void _drawCrossGrid(Canvas canvas, Size size, Paint paint) {
    // Calculate exact baseline position
    final baselineOffset = _calculateBaselineOffset();
    final actualLineHeight = _actualLineHeight;

    // Draw vertical lines
    for (double i = 0; i < size.width; i += actualLineHeight) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    // Draw horizontal lines at baseline positions
    double y = baselineOffset;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += actualLineHeight;
    }

    // Draw margin line
    final marginPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(marginLineOffset, 0),
      Offset(marginLineOffset, size.height),
      marginPaint,
    );
  }

  void _drawDottedGrid(Canvas canvas, Size size, Paint paint) {
    // Calculate exact baseline position
    final baselineOffset = _calculateBaselineOffset();
    final actualLineHeight = _actualLineHeight;

    paint.strokeCap = StrokeCap.round;
    paint.strokeWidth = 3;

    // Draw dots at baseline positions
    for (double x = 0; x < size.width; x += actualLineHeight) {
      double y = baselineOffset;
      while (y < size.height) {
        canvas.drawPoints(PointMode.points, [Offset(x, y)], paint);
        y += actualLineHeight;
      }
    }

    // Draw margin line
    final marginPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(marginLineOffset, 0),
      Offset(marginLineOffset, size.height),
      marginPaint,
    );
  }

  void _drawCardBorder(Canvas canvas, Size size, Paint paint) {
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 10, size.width - 20, size.height - 20),
      const Radius.circular(12),
    );

    canvas.drawRRect(rect, paint);

    // Draw margin line
    final marginPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(marginLineOffset, 0),
      Offset(marginLineOffset, size.height),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.marginLineOffset != marginLineOffset;
  }
}
