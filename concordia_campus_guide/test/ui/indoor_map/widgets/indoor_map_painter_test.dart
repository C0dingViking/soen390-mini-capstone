import "dart:math";
import "dart:ui";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_map.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_path_painter.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal [Floorplan] stub – only the fields used by [IndoorPathPainter].
Floorplan _makeFlorplan({
  double canvasWidth = 400,
  double canvasHeight = 300,
}) {
  return Floorplan(
    buildingId: "H",
    floorNumber: 8,
    svgPath: "assets/floorplans/h8.svg",
    canvasWidth: canvasWidth,
    canvasHeight: canvasHeight,
    rooms: [],
    corridors: [],
  );
}

/// Two points that form a simple horizontal path across the canvas.
List<Point<double>> _simplePath() => [
      const Point(0, 150),
      const Point(200, 150),
      const Point(400, 150),
    ];

/// Paints [painter] onto a [Canvas] of the given [size] and returns without
/// throwing – used to verify that [paint()] does not crash.
void _paintOn(final CustomPainter painter, {final Size size = const Size(400, 300)}) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording();
}

// ─────────────────────────────────────────────────────────────────────────────
// IndoorPathPainter – unit tests (no widget tree required)
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group("IndoorPathPainter", () {
    // ── Construction ──────────────────────────────────────────────────────────

    test("can be instantiated with required fields only", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(),
        path: _simplePath(),
      );
      expect(painter, isNotNull);
    });

    test("uses correct default visual parameters", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(),
        path: _simplePath(),
      );
      expect(painter.strokeWidth, 2.0);
      expect(painter.dashLength, 12.0);
      expect(painter.gapLength, 10.0);
      expect(painter.pinRadius, 5.0);
      expect(painter.pinStemHeight, 10.0);
    });

    // ── paint() – no crash guarantees ─────────────────────────────────────────

    test("paint() completes without throwing for a valid path", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(),
        path: _simplePath(),
      );
      expect(() => _paintOn(painter), returnsNormally);
    });

    test("paint() does nothing (no crash) when path has fewer than 2 points", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(),
        path: [const Point(100, 100)], // single point
      );
      expect(() => _paintOn(painter), returnsNormally);
    });

    test("paint() does nothing when path is empty", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(),
        path: [],
      );
      expect(() => _paintOn(painter), returnsNormally);
    });

    test("paint() does nothing when canvasWidth is 0", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(canvasWidth: 0),
        path: _simplePath(),
      );
      expect(() => _paintOn(painter), returnsNormally);
    });

    test("paint() does nothing when canvasHeight is 0", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(canvasHeight: 0),
        path: _simplePath(),
      );
      expect(() => _paintOn(painter), returnsNormally);
    });

    test("paint() handles a path with exactly 2 points", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(),
        path: [const Point(0, 0), const Point(400, 300)],
      );
      expect(() => _paintOn(painter), returnsNormally);
    });

    test("paint() handles a path where start == end (zero-length segment)", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(),
        path: [const Point(100, 100), const Point(100, 100)],
      );
      expect(() => _paintOn(painter), returnsNormally);
    });

    test("paint() handles a vertical path", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(),
        path: [const Point(200, 0), const Point(200, 300)],
      );
      expect(() => _paintOn(painter), returnsNormally);
    });

    test("paint() handles a diagonal path", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(),
        path: [const Point(0, 0), const Point(400, 300)],
      );
      expect(() => _paintOn(painter), returnsNormally);
    });

    test("paint() works on a non-square canvas size", () {
      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(canvasWidth: 1000, canvasHeight: 200),
        path: _simplePath(),
      );
      expect(() => _paintOn(painter, size: const Size(800, 600)), returnsNormally);
    });

    test("paint() works with a custom pulseAnimation value", () {
      // Simulate mid-animation state via a plain double-valued animation stub.
      final controller = AnimationController.unbounded(vsync: const TestVSync());
      controller.value = 0.5;

      final painter = IndoorPathPainter(
        floorplan: _makeFlorplan(),
        path: _simplePath(),
        pulseAnimation: controller,
      );
      expect(() => _paintOn(painter), returnsNormally);
      controller.dispose();
    });

    // ── shouldRepaint ─────────────────────────────────────────────────────────

    test("shouldRepaint returns false when nothing changes", () {
      final fp = _makeFlorplan();
      final p = _simplePath();
      final a = IndoorPathPainter(floorplan: fp, path: p);
      final b = IndoorPathPainter(floorplan: fp, path: p);
      expect(a.shouldRepaint(b), isFalse);
    });

    test("shouldRepaint returns true when path changes", () {
      final fp = _makeFlorplan();
      final a = IndoorPathPainter(floorplan: fp, path: _simplePath());
      final b = IndoorPathPainter(
        floorplan: fp,
        path: [const Point(0, 0), const Point(100, 100)],
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test("shouldRepaint returns true when floorplan changes", () {
      final a = IndoorPathPainter(floorplan: _makeFlorplan(), path: _simplePath());
      final b = IndoorPathPainter(
        floorplan: _makeFlorplan(canvasWidth: 800),
        path: _simplePath(),
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test("shouldRepaint returns true when pathColor changes", () {
      final fp = _makeFlorplan();
      final p = _simplePath();
      final a = IndoorPathPainter(floorplan: fp, path: p, pathColor: Colors.blue);
      final b = IndoorPathPainter(floorplan: fp, path: p, pathColor: Colors.red);
      expect(a.shouldRepaint(b), isTrue);
    });

    test("shouldRepaint returns true when strokeWidth changes", () {
      final fp = _makeFlorplan();
      final p = _simplePath();
      final a = IndoorPathPainter(floorplan: fp, path: p, strokeWidth: 2.0);
      final b = IndoorPathPainter(floorplan: fp, path: p, strokeWidth: 4.0);
      expect(a.shouldRepaint(b), isTrue);
    });

    test("shouldRepaint returns true when dashLength changes", () {
      final fp = _makeFlorplan();
      final p = _simplePath();
      final a = IndoorPathPainter(floorplan: fp, path: p, dashLength: 10.0);
      final b = IndoorPathPainter(floorplan: fp, path: p, dashLength: 20.0);
      expect(a.shouldRepaint(b), isTrue);
    });

    test("shouldRepaint returns true when gapLength changes", () {
      final fp = _makeFlorplan();
      final p = _simplePath();
      final a = IndoorPathPainter(floorplan: fp, path: p, gapLength: 5.0);
      final b = IndoorPathPainter(floorplan: fp, path: p, gapLength: 15.0);
      expect(a.shouldRepaint(b), isTrue);
    });

    test("shouldRepaint returns true when endColor changes", () {
      final fp = _makeFlorplan();
      final p = _simplePath();
      final a = IndoorPathPainter(floorplan: fp, path: p, endColor: Colors.red);
      final b = IndoorPathPainter(floorplan: fp, path: p, endColor: Colors.green);
      expect(a.shouldRepaint(b), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // resolveRoomNameFromTapPosition – unit tests (uses @visibleForTesting export)
  // ─────────────────────────────────────────────────────────────────────────────

  group("resolveRoomNameFromTapPosition", () {
    /// Builds a [Floorplan] with a single rectangular room whose polygon spans
    /// (x: 100–200, y: 100–200) in SVG coordinates.
    Floorplan _floorplanWithRoom() {
      final room = IndoorMapRoom(
      name: "H-820",
      doorLocation: const Point(150, 200),
      points: [
    const Point<double>(100, 100),
    const Point<double>(200, 100),
    const Point<double>(200, 200),
    const Point<double>(100, 200),
  ],
);
      return Floorplan(
        buildingId: "H",
        floorNumber: 8,
        svgPath: "assets/floorplans/h8.svg",
        canvasWidth: 400,
        canvasHeight: 300,
        rooms: [room],
        corridors: [],
      );
    }

    test("returns room name when tap is inside the room polygon", () {
      // SVG point (150, 150) is the centre of the 100–200 square.
      // We need to pass a scene point that maps to SVG (150, 150).
      // With a 400×300 canvas fitted into a 400×300 viewport the mapping is 1:1.
      final floorplan = _floorplanWithRoom();
      const viewportSize = Size(400, 300);
      const scenePoint = Offset(150, 150);

      final result = resolveRoomNameFromTapPosition(scenePoint, viewportSize, floorplan);
      expect(result, "H-820");
    });

    test("returns null when tap is outside every room", () {
      final floorplan = _floorplanWithRoom();
      const viewportSize = Size(400, 300);
      const scenePoint = Offset(10, 10); // far from the 100–200 room square

      final result = resolveRoomNameFromTapPosition(scenePoint, viewportSize, floorplan);
      expect(result, isNull);
    });

    test("returns null when tap is outside the viewport entirely", () {
      final floorplan = _floorplanWithRoom();
      const viewportSize = Size(400, 300);
      const scenePoint = Offset(500, 500); // outside 400×300 viewport

      final result = resolveRoomNameFromTapPosition(scenePoint, viewportSize, floorplan);
      expect(result, isNull);
    });

    test("returns null when viewportSize has zero width", () {
      final floorplan = _floorplanWithRoom();
      const viewportSize = Size(0, 300);
      const scenePoint = Offset(150, 150);

      final result = resolveRoomNameFromTapPosition(scenePoint, viewportSize, floorplan);
      expect(result, isNull);
    });

    test("returns null when viewportSize has zero height", () {
      final floorplan = _floorplanWithRoom();
      const viewportSize = Size(400, 0);
      const scenePoint = Offset(150, 150);

      final result = resolveRoomNameFromTapPosition(scenePoint, viewportSize, floorplan);
      expect(result, isNull);
    });

    test("returns null when floorplan has no rooms", () {
      final floorplan = Floorplan(
        buildingId: "H",
        floorNumber: 8,
        svgPath: "assets/floorplans/h8.svg",
        canvasWidth: 400,
        canvasHeight: 300,
        rooms: [],
        corridors: [],
      );
      const viewportSize = Size(400, 300);
      const scenePoint = Offset(150, 150);

      final result = resolveRoomNameFromTapPosition(scenePoint, viewportSize, floorplan);
      expect(result, isNull);
    });

    test("returns null when floorplan canvasWidth is 0", () {
      final floorplan = Floorplan(
        buildingId: "H",
        floorNumber: 8,
        svgPath: "assets/floorplans/h8.svg",
        canvasWidth: 0,
        canvasHeight: 300,
        rooms: [],
        corridors: [],
      );
      final result = resolveRoomNameFromTapPosition(
        const Offset(150, 150),
        const Size(400, 300),
        floorplan,
      );
      expect(result, isNull);
    });
  });
}
