import "dart:convert";
import "dart:io";

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

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path.length, 2);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("finds a path between every room pair on all manifest floors", () {
      // Verify that indoor pathfinding can find a path
      // between every pair of rooms on each floor.
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

          // Skip floors with fewer than 2 rooms; there is nothing to test.
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
              // This ensures every room pair on every indoor floor is
              // reachable according to the pathfinding logic (including
              // straight-line fallback when corridors are missing).
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
  });
}
