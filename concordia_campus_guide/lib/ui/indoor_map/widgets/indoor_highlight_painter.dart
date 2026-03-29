import "dart:math";

import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:flutter/material.dart";

class RoomHighlightPainter extends CustomPainter {
  final Floorplan floorplan;
  final String? selectedStartName;
  final String? selectedEndName;

  static const Color startBorderColor = Color.fromARGB(80, 33, 150, 243);
  static const Color startHighlightColor = Color.fromARGB(180, 33, 150, 243);
  static const Color endBorderColor = Color.fromARGB(80, 120, 150, 243);
  static const Color endHighlightColor = Color.fromARGB(180, 120, 150, 243);
  static const double borderWidth = 3.0;

  const RoomHighlightPainter({
    required this.floorplan,
    required this.selectedStartName,
    required this.selectedEndName,
  });

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
    if ((selectedEndName == null && selectedStartName == null) ||
        floorplan.canvasWidth <= 0 ||
        floorplan.canvasHeight <= 0) {
      return;
    }

    if (selectedStartName != null) {
      _prepareRoomForDrawing(
        selectedStartName,
        canvas,
        size,
        startHighlightColor,
        startBorderColor,
      );
    }
    if (selectedEndName != null) {
      _prepareRoomForDrawing(selectedEndName, canvas, size, endHighlightColor, endBorderColor);
    }
  }

  void _prepareRoomForDrawing(
    final String? roomName,
    final Canvas canvas,
    final Size size,
    final Color highlight,
    final Color fill,
  ) {
    final roomList = floorplan.rooms.where((final r) => r.name == roomName).toList();
    if (roomList.isEmpty) {
      return;
    }

    final room = roomList.first;
    if (room.points.isEmpty) {
      return;
    }

    final rect = _destinationRect(size);
    final canvasPoints = room.points
        .map((final p) => _svgToCanvas(p, rect))
        .toList(growable: false);

    _drawRoomHighlight(canvas, canvasPoints, highlight, fill);
  }

  void _drawRoomHighlight(
    final Canvas canvas,
    final List<Offset> points,
    final Color highlight,
    final Color fill,
  ) {
    if (points.length < 3) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(final RoomHighlightPainter oldDelegate) {
    return oldDelegate.selectedEndName != selectedEndName ||
        oldDelegate.selectedStartName != selectedStartName ||
        oldDelegate.floorplan != floorplan;
  }
}
