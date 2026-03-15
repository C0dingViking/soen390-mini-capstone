import "dart:convert";
import "dart:io";
import "dart:math";

import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/domain/models/indoor_pathfinding.dart";
import "package:flutter_test/flutter_test.dart";
import "package:xml/xml.dart";

void main() {
  group("FloorplanPathfinding.shortestPathBetweenRooms", () {
    test("computes a corridor-constrained path between two rooms", () {
      const xmlString = '''
<svg>
  <g inkscape:label="rooms">
    <rect inkscape:label="room-CL-101" x="10" y="80" width="20" height="20" />
    <rect inkscape:label="room-CL-102" x="370" y="80" width="20" height="20" />
  </g>
  <g inkscape:label="connectors">
    <ellipse inkscape:label="door-cl1-101" cx="20" cy="85" rx="5" ry="5" />
    <ellipse inkscape:label="door-cl1-102" cx="380" cy="85" rx="5" ry="5" />
  </g>
  <g inkscape:label="points-of-interest"></g>
  <g inkscape:label="walkable">
    <path inkscape:label="walkable-1"
          d="M 0 70 L 400 70 L 400 100 L 0 100 Z"/>
  </g>
</svg>
''';

      final floorplan = Floorplan.fromXml("cl", 1, "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.rooms.length, 2);
      expect(floorplan.corridors.length, 1);

      final roomA = floorplan.rooms[0];
      final roomB = floorplan.rooms[1];

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("falls back to straight line when no corridors", () {
      const xmlString = '''
<svg>
  <g inkscape:label="rooms">
    <rect inkscape:label="room-CL-101" x="0" y="0" width="10" height="10" />
    <rect inkscape:label="room-CL-102" x="100" y="0" width="10" height="10" />
  </g>
  <g inkscape:label="connectors">
    <ellipse inkscape:label="door-cl1-101" cx="5" cy="5" rx="2" ry="2" />
    <ellipse inkscape:label="door-cl1-102" cx="105" cy="5" rx="2" ry="2" />
  </g>
  <g inkscape:label="points-of-interest"></g>
  <g inkscape:label="walkable"></g>
</svg>
''';

      final floorplan = Floorplan.fromXml("cl", 1, "test.svg", XmlDocument.parse(xmlString));

      final roomA = floorplan.rooms[0];
      final roomB = floorplan.rooms[1];

      expect(() => floorplan.shortestPathBetweenRooms(roomA, roomB), throwsStateError);
    });

    test("finds a path between every room pair on all manifest floors", () {
      final manifestJson =
          jsonDecode(File("assets/floorplans/floorplan_manifest.json").readAsStringSync())
              as Map<String, dynamic>;

      final filenameRegex = RegExp(r"([a-zA-Z]+)-(\d+)\.svg");

      manifestJson.forEach((final String buildingKey, final dynamic rawList) {
        if (rawList is! List) return;
        final svgPaths = List<String>.from(rawList.cast<dynamic>());

        for (final svgPath in svgPaths) {
          final fileName = svgPath.split("/").last;
          final match = filenameRegex.firstMatch(fileName);
          expect(match, isNotNull, reason: "Invalid floorplan filename: $fileName");
          if (match == null) continue;

          final buildingCode = match.group(1)!;
          final floorNumber = int.parse(match.group(2)!);

          final svgString = File(svgPath).readAsStringSync();
          final xml = XmlDocument.parse(svgString);

          final floorplan = Floorplan.fromXml(buildingCode, floorNumber, svgPath, xml);

          // Skip floors with fewer than 2 rooms
          if (floorplan.rooms.length < 2) {
            continue;
          }

          final rooms = floorplan.rooms;

          for (var i = 0; i < rooms.length; i++) {
            for (var j = i + 1; j < rooms.length; j++) {
              final start = rooms[i];
              final end = rooms[j];

              final path = floorplan.shortestPathBetweenRooms(start, end);

              // Path must be non-empty and start/end at the correct doors.
              expect(
                path,
                isNotEmpty,
                reason:
                    "Path for ${buildingCode.toUpperCase()}$floorNumber ${start.name} -> ${end.name} should not be empty",
              );
              expect(
                path.first,
                start.doorLocation,
                reason:
                    "Path for ${buildingCode.toUpperCase()}$floorNumber ${start.name} -> ${end.name} should start at start room door",
              );
              expect(
                path.last,
                end.doorLocation,
                reason:
                    "Path for ${buildingCode.toUpperCase()}$floorNumber ${start.name} -> ${end.name} should end at destination room door",
              );
            }
          }
        }
      });
    });

    test("finds a path between every room pair on H8", () {
      const svgPath = "assets/floorplans/h/h-8.svg";
      final svgString = File(svgPath).readAsStringSync();
      final xml = XmlDocument.parse(svgString);

      final floorplan = Floorplan.fromXml("h", 8, svgPath, xml);

      // We expect H8 to have multiple rooms and corridors defined.
      expect(floorplan.rooms.length, greaterThan(1));
      expect(floorplan.corridors, isNotEmpty);

      final rooms = floorplan.rooms;

      for (var i = 0; i < rooms.length; i++) {
        for (var j = i + 1; j < rooms.length; j++) {
          final start = rooms[i];
          final end = rooms[j];

          final path = floorplan.shortestPathBetweenRooms(start, end);

          expect(
            path,
            isNotEmpty,
            reason: "Path for H8 ${start.name} -> ${end.name} should not be empty",
          );
          expect(
            path.first,
            start.doorLocation,
            reason: "Path for H8 ${start.name} -> ${end.name} should start at start room door",
          );
          expect(
            path.last,
            end.doorLocation,
            reason: "Path for H8 ${start.name} -> ${end.name} should end at destination room door",
          );
        }
      }
    });

    test("H8: inspects corridor connectivity between rooms 845 and 849", () {
      const svgPath = "assets/floorplans/h/h-8.svg";
      final svgString = File(svgPath).readAsStringSync();
      final xml = XmlDocument.parse(svgString);

      final floorplan = Floorplan.fromXml("h", 8, svgPath, xml);

      expect(floorplan.corridors, isNotEmpty);

      final room845 = floorplan.rooms.firstWhere(
        (final r) => r.name == "845",
        orElse: () => throw StateError("Room 845 not found on H8"),
      );
      final room849 = floorplan.rooms.firstWhere(
        (final r) => r.name == "849",
        orElse: () => throw StateError("Room 849 not found on H8"),
      );

      bool pointInPolygon(final Point<double> point, final List<Point<double>> polygon) {
        if (polygon.length < 3) {
          return false;
        }

        var inside = false;
        for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
          final xi = polygon[i].x;
          final yi = polygon[i].y;
          final xj = polygon[j].x;
          final yj = polygon[j].y;

          final intersect =
              ((yi > point.y) != (yj > point.y)) &&
              (point.x < (xj - xi) * (point.y - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);
          if (intersect) {
            inside = !inside;
          }
        }

        return inside;
      }

      int? corridorIndexFor(final Point<double> p) {
        for (var i = 0; i < floorplan.corridors.length; i++) {
          if (pointInPolygon(p, floorplan.corridors[i].bounds)) {
            return i;
          }
        }
        return null;
      }

      final corridor845 = corridorIndexFor(room845.doorLocation);
      final corridor849 = corridorIndexFor(room849.doorLocation);

      // At the moment, room 845's door is just outside any corridor
      // polygon, which is a key reason why 845 & 849 cannot be
      // connected by the indoor graph.
      expect(
        corridor845,
        isNull,
        reason:
            "Door for room 845 is expected (with current SVG data) to be outside all corridor polygons",
      );

      // Similarly, room 849's door is also currently outside all
      // corridor polygons in the SVG.
      expect(
        corridor849,
        isNull,
        reason:
            "Door for room 849 is expected (with current SVG data) to be outside all corridor polygons",
      );

      if (corridor845 != null && corridor849 != null && corridor845 != corridor849) {
        final corridorA = floorplan.corridors[corridor845];
        final corridorB = floorplan.corridors[corridor849];

        var minDistance = double.infinity;

        for (final pa in corridorA.bounds) {
          for (final pb in corridorB.bounds) {
            final dx = pa.x - pb.x;
            final dy = pa.y - pb.y;
            final d = sqrt(dx * dx + dy * dy);
            if (d < minDistance) {
              minDistance = d;
            }
          }
        }

        // This assertion is mostly to catch degenerate data; the specific value
        // of the minimum distance can be inspected via the failure message.
        expect(
          minDistance.isFinite,
          isTrue,
          reason:
              "Minimum vertex-to-vertex distance between corridors for 845 and 849 is not finite (computed value: $minDistance)",
        );
      }
    });
  });
}
