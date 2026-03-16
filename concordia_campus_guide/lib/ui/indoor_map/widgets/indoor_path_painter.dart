import "dart:math";

import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:flutter/material.dart";

/// A [CustomPainter] that renders the indoor navigation path with:
///   • A dashed/dotted line along the computed route
///   • A pulsing origin indicator at the start point
///   • A destination pin marker at the end point
///
/// Drop-in replacement for the old `_IndoorPathPainter` inside `indoor_map.dart`.
/// Pass an [Animation<double>] (0.0 → 1.0, repeating) to drive the pulse on the
/// start indicator. If [pulseAnimation] is null the indicator is drawn statically.
class IndoorPathPainter extends CustomPainter {
  final Floorplan floorplan;
  final List<Point<double>> path;

  // ── Dash line ──────────────────────────────────────────────────────────────
  final Color pathColor;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  // ── Start indicator ────────────────────────────────────────────────────────
  final Color startColor;
  final double startRadius;
  final Animation<double>? pulseAnimation;

  // ── End indicator ──────────────────────────────────────────────────────────
  final Color endColor;
  final double pinRadius;
  final double pinStemHeight;

  const IndoorPathPainter({
    required this.floorplan,
    required this.path,
    this.pathColor = const Color.fromARGB(200, 8, 187, 241), // bright blue
    this.strokeWidth = 3.5,
    this.dashLength = 12.0,
    this.gapLength = 7.0,
    this.startColor = const Color.fromARGB(200, 8, 187, 241), // vivid green
    this.startRadius = 7.0,
    this.pulseAnimation,
    this.endColor = const Color.fromARGB(200, 8, 187, 241), // vivid red
    this.pinRadius = 9.0,
    this.pinStemHeight = 14.0,
  }) : super(repaint: pulseAnimation);

  // ── Coordinate mapping ─────────────────────────────────────────────────────

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

  // ── Paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(final Canvas canvas, final Size size) {
    if (path.length < 2 || floorplan.canvasWidth <= 0 || floorplan.canvasHeight <= 0) return;

    final rect = _destinationRect(size);
    final offsets = path.map((p) => _svgToCanvas(p, rect)).toList(growable: false);

    _drawDashedPath(canvas, offsets);
    _drawStartIndicator(canvas, offsets.first);
    _drawDestinationPin(canvas, offsets.last);
  }

  // ── Dashed path ────────────────────────────────────────────────────────────

  void _drawDashedPath(final Canvas canvas, final List<Offset> offsets) {
    final paint = Paint()
      ..color = pathColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw a subtle drop-shadow first
    final shadowPaint = Paint()
      ..color = pathColor.withOpacity(0.18)
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

  void _drawDashedSegment(
    final Canvas canvas,
    final Offset a,
    final Offset b,
    final Paint paint,
  ) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final segmentLength = sqrt(dx * dx + dy * dy);
    if (segmentLength == 0) return;

    final ux = dx / segmentLength; // unit vector
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

  // ── Start indicator ────────────────────────────────────────────────────────
  //
  //   • Outer pulsing ring (animated when [pulseAnimation] is provided)
  //   • Mid ring
  //   • Inner filled dot

  void _drawStartIndicator(final Canvas canvas, final Offset center) {
    final pulse = pulseAnimation?.value ?? 0.5;

    // Outer pulse ring
    final pulseRadius = startRadius * (1.4 + pulse * 1.1);
    final pulseOpacity = (1.0 - pulse) * 0.45;
    canvas.drawCircle(
      center,
      pulseRadius,
      Paint()
        ..color = startColor.withOpacity(pulseOpacity)
        ..style = PaintingStyle.fill,
    );

    // Mid ring
    canvas.drawCircle(
      center,
      startRadius * 1.55,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Inner dot
    canvas.drawCircle(
      center,
      startRadius,
      Paint()
        ..color = startColor
        ..style = PaintingStyle.fill,
    );

    // White centre dot
    canvas.drawCircle(
      center,
      startRadius * 0.38,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  // ── Destination pin ────────────────────────────────────────────────────────
  //
  //   Classic teardrop map-pin: filled circle on top, pointed stem below,
  //   white inner circle for contrast, drawn so the tip sits at [tip].

  void _drawDestinationPin(final Canvas canvas, final Offset tip) {
    // The circle centre sits `pinStemHeight` above the tip.
    final circleCenter = tip.translate(0, -(pinRadius + pinStemHeight));

    // Drop shadow
    canvas.drawCircle(
      circleCenter.translate(0, 2),
      pinRadius + 1,
      Paint()
        ..color = Colors.black.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..style = PaintingStyle.fill,
    );

    // Stem (triangle from circle bottom to tip)
    final stemPath = Path()
      ..moveTo(circleCenter.dx - pinRadius * 0.45, circleCenter.dy + pinRadius * 0.75)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(circleCenter.dx + pinRadius * 0.45, circleCenter.dy + pinRadius * 0.75)
      ..close();

    canvas.drawPath(stemPath, Paint()..color = endColor);

    // Circle body
    canvas.drawCircle(circleCenter, pinRadius, Paint()..color = endColor);

    // White inner ring
    canvas.drawCircle(
      circleCenter,
      pinRadius * 0.48,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
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
