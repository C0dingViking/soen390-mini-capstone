import "dart:math";

import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:flutter/material.dart";

class IndoorPathPainter extends CustomPainter {
  final Floorplan floorplan;
  final List<Point<double>> path;

  final Color pathColor;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  final Color startColor;
  final double startRadius;
  final Animation<double>? pulseAnimation;

  final Color endColor;
  final double pinRadius;
  final double pinStemHeight;

  const IndoorPathPainter({
    required this.floorplan,
    required this.path,
    this.pathColor = const Color.fromARGB(200, 8, 187, 241),
    this.strokeWidth = 2.0,
    this.dashLength = 12.0,
    this.gapLength = 10.0,
    this.startColor = const Color.fromARGB(200, 8, 187, 241),
    this.startRadius = 7.0,
    this.pulseAnimation,
    this.endColor = const Color.fromARGB(200, 8, 187, 241),
    this.pinRadius = 5.0,
    this.pinStemHeight = 10.0,
  }) : super(repaint: pulseAnimation);

  // Coordinate mapping

  Rect _destinationRect(final Size size) {
    final inputSize = Size(floorplan.canvasWidth, floorplan.canvasHeight);
    final fittedSizes = applyBoxFit(BoxFit.contain, inputSize, size);
    return Alignment.center.inscribe(fittedSizes.destination, Offset.zero & size);
  }

  Offset _svgToCanvas(final Point<double> p, final Rect rect) {
    return Offset(
      rect.left + (p.x / floorplan.canvasWidth) * rect.width,
      rect.top + (p.y / floorplan.canvasHeight) * rect.height,
    );
  }


  @override
  void paint(final Canvas canvas, final Size size) {
    if (path.length < 2 || floorplan.canvasWidth <= 0 || floorplan.canvasHeight <= 0) return;

    final rect = _destinationRect(size);
    final offsets = path.map((final p) => _svgToCanvas(p, rect)).toList(growable: false);

    _drawDashedPath(canvas, offsets);
    _drawStartIndicator(canvas, offsets.first);
    _drawDestinationPin(canvas, offsets.last);
  }


  void _drawDashedPath(final Canvas canvas, final List<Offset> offsets) {
    final paint = Paint()
      ..color = pathColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = pathColor.withValues(alpha: .18)
      ..strokeWidth = strokeWidth + 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (var i = 0; i < offsets.length - 1; i++) {
      _drawDashedSegment(canvas, offsets[i], offsets[i + 1], shadowPaint);
    }
    for (var i = 0; i < offsets.length - 1; i++) {
      _drawDashedSegment(canvas, offsets[i], offsets[i + 1], paint);
    }
  }

  void _drawDashedSegment(final Canvas canvas, final Offset a, final Offset b, final Paint paint) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final segmentLength = sqrt(dx * dx + dy * dy);
    if (segmentLength == 0) return;

    final ux = dx / segmentLength;
    final uy = dy / segmentLength;

    var drawn = 0.0;
    var onDash = true;

    while (drawn < segmentLength) {
      final stepLength = onDash ? dashLength : gapLength;
      final end = min(drawn + stepLength, segmentLength);

      if (onDash) {
        canvas.drawLine(
          Offset(a.dx + ux * drawn, a.dy + uy * drawn),
          Offset(a.dx + ux * end, a.dy + uy * end),
          paint,
        );
      }

      drawn = end;
      onDash = !onDash;
    }
  }


  void _drawStartIndicator(final Canvas canvas, final Offset center) {
    const Color iconColor = Color.fromARGB(200, 8, 187, 241);

    const double outerRingRadius = 6.0;
    const double innerDotRadius = 3.5;
    const double strokeW = 1.6;
    const double tickLength = 2.5;
    const double tickGap = 1.0;

    // Outer ring
    canvas.drawCircle(
      center,
      outerRingRadius,
      Paint()
        ..color = iconColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // Inner filled dot
    canvas.drawCircle(
      center,
      innerDotRadius,
      Paint()
        ..color = iconColor
        ..style = PaintingStyle.fill,
    );

    // Four crosshair ticks (top, bottom, left, right)
    final tickPaint = Paint()
      ..color = iconColor
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.square;

    final tickStart = outerRingRadius + tickGap;
    final tickEnd = tickStart + tickLength;

    // Top
    canvas.drawLine(
      Offset(center.dx, center.dy - tickStart),
      Offset(center.dx, center.dy - tickEnd),
      tickPaint,
    );
    // Bottom
    canvas.drawLine(
      Offset(center.dx, center.dy + tickStart),
      Offset(center.dx, center.dy + tickEnd),
      tickPaint,
    );
    // Left
    canvas.drawLine(
      Offset(center.dx - tickStart, center.dy),
      Offset(center.dx - tickEnd, center.dy),
      tickPaint,
    );
    // Right
    canvas.drawLine(
      Offset(center.dx + tickStart, center.dy),
      Offset(center.dx + tickEnd, center.dy),
      tickPaint,
    );
  }


  void _drawDestinationPin(final Canvas canvas, final Offset tip) {
    final circleCenter = tip.translate(0, -(pinRadius + pinStemHeight));

    // Triangle Part
    final stemPath = Path()
      ..moveTo(circleCenter.dx - pinRadius * 0.45, circleCenter.dy + pinRadius * 0.75)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(circleCenter.dx + pinRadius * 0.45, circleCenter.dy + pinRadius * 0.75)
      ..close();

    canvas.drawPath(stemPath, Paint()..color = endColor);

    canvas.drawCircle(circleCenter, pinRadius, Paint()..color = endColor);
  }

  @override
  bool shouldRepaint(final IndoorPathPainter old) {
    return old.floorplan != floorplan ||
        old.path != path ||
        old.pathColor != pathColor ||
        old.strokeWidth != strokeWidth ||
        old.dashLength != dashLength ||
        old.gapLength != gapLength ||
        old.startColor != startColor ||
        old.endColor != endColor;
  }
}
