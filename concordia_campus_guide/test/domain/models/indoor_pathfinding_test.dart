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

    test(
      "finds a path between every room pair on all manifest floors",
      () {
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
      },
      skip:
          "Known failing: some floorplans miss metadata. TODO: Remove the skip when #118 is closed",
    );

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
  });

  // =========================================================================
  // Helpers for inter-floor tests
  // =========================================================================

  Corridor rectCorridor(double x1, double y1, double x2, double y2) {
    return Corridor(bounds: [
      Point<double>(x1, y1),
      Point<double>(x2, y1),
      Point<double>(x2, y2),
      Point<double>(x1, y2),
    ]);
  }

  Floorplan makeFloorplan({
    required int floorNumber,
    required List<Corridor> corridors,
    List<IndoorMapRoom> rooms = const [],
    List<FloorTransition> transitions = const [],
    String buildingId = "h",
  }) {
    return Floorplan(
      buildingId: buildingId,
      floorNumber: floorNumber,
      svgPath: "assets/maps/$buildingId$floorNumber.svg",
      canvasWidth: 1000,
      canvasHeight: 800,
    )
      ..rooms = rooms
      ..corridors = corridors
      ..transitions = transitions
      ..pois = [];
  }

  IndoorMapRoom makeRoom(String name, Point<double> door) {
    return IndoorMapRoom(
      name: name,
      doorLocation: door,
      points: [
        Point<double>(door.x - 10, door.y - 10),
        Point<double>(door.x + 10, door.y - 10),
        Point<double>(door.x + 10, door.y + 10),
        Point<double>(door.x - 10, door.y + 10),
      ],
    );
  }

  // =========================================================================
  // shortestPathToTransition
  // =========================================================================

  group("shortestPathToTransition", () {
    test("finds a path from a point to a transition on the same floor", () {
      final corridor = rectCorridor(0, 0, 200, 50);
      final transition = FloorTransition(
        id: "h1-stairs-1",
        location: const Point<double>(180, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      final floorplan = makeFloorplan(
        floorNumber: 1,
        corridors: [corridor],
        transitions: [transition],
      );

      final path = floorplan.shortestPathToTransition(
        const Point<double>(20, 25),
        transition,
      );

      expect(path, isNotEmpty);
      expect(path.first.x, closeTo(20, 1));
      expect(path.first.y, closeTo(25, 1));
      expect(path.last.x, closeTo(180, 1));
      expect(path.last.y, closeTo(25, 1));
    });

    test("throws StateError when no corridors exist", () {
      final transition = FloorTransition(
        id: "h1-stairs-1",
        location: const Point<double>(100, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      final floorplan = makeFloorplan(
        floorNumber: 1,
        corridors: [],
        transitions: [transition],
      );

      expect(
        () => floorplan.shortestPathToTransition(const Point<double>(10, 25), transition),
        throwsA(isA<StateError>()),
      );
    });
  });

  // =========================================================================
  // computeInterFloorPath
  // =========================================================================

  group("computeInterFloorPath", () {
    late Map<int, Floorplan> twoFloorBuilding;
    late IndoorMapRoom roomOnFloor1;
    late IndoorMapRoom roomOnFloor2;

    setUp(() {
      final corridor1 = rectCorridor(0, 0, 300, 50);
      roomOnFloor1 = makeRoom("101", const Point<double>(20, 25));
      final transition1 = FloorTransition(
        id: "h1-stairs-1",
        location: const Point<double>(280, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      final corridor2 = rectCorridor(0, 0, 300, 50);
      roomOnFloor2 = makeRoom("201", const Point<double>(20, 25));
      final transition2 = FloorTransition(
        id: "h2-stairs-1",
        location: const Point<double>(280, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      twoFloorBuilding = {
        1: makeFloorplan(
          floorNumber: 1,
          corridors: [corridor1],
          rooms: [roomOnFloor1],
          transitions: [transition1],
        ),
        2: makeFloorplan(
          floorNumber: 2,
          corridors: [corridor2],
          rooms: [roomOnFloor2],
          transitions: [transition2],
        ),
      };
    });

    test("returns a single segment for same-floor routes", () {
      final segments = computeInterFloorPath(
        floorplans: twoFloorBuilding,
        startFloor: 1,
        destinationFloor: 1,
        startRoom: roomOnFloor1,
        destinationRoom: roomOnFloor1,
      );

      expect(segments.length, 1);
      expect(segments.first.floorNumber, 1);
      expect(segments.first.entryTransition, isNull);
      expect(segments.first.exitTransition, isNull);
    });

    test("returns two segments for a two-floor route", () {
      final segments = computeInterFloorPath(
        floorplans: twoFloorBuilding,
        startFloor: 1,
        destinationFloor: 2,
        startRoom: roomOnFloor1,
        destinationRoom: roomOnFloor2,
      );

      expect(segments.length, 2);

      expect(segments[0].floorNumber, 1);
      expect(segments[0].path, isNotEmpty);
      expect(segments[0].exitTransition, isNotNull);
      expect(segments[0].exitTransition!.groupTag, "stairs-1");

      expect(segments[1].floorNumber, 2);
      expect(segments[1].path, isNotEmpty);
      expect(segments[1].entryTransition, isNotNull);
      expect(segments[1].entryTransition!.groupTag, "stairs-1");
    });

    test("works in the reverse direction (floor 2 → floor 1)", () {
      final segments = computeInterFloorPath(
        floorplans: twoFloorBuilding,
        startFloor: 2,
        destinationFloor: 1,
        startRoom: roomOnFloor2,
        destinationRoom: roomOnFloor1,
      );

      expect(segments.length, 2);
      expect(segments[0].floorNumber, 2);
      expect(segments[1].floorNumber, 1);
    });

    test("throws when no matching transition exists between floors", () {
      twoFloorBuilding[2] = makeFloorplan(
        floorNumber: 2,
        corridors: twoFloorBuilding[2]!.corridors,
        rooms: [roomOnFloor2],
        transitions: [],
      );

      expect(
        () => computeInterFloorPath(
          floorplans: twoFloorBuilding,
          startFloor: 1,
          destinationFloor: 2,
          startRoom: roomOnFloor1,
          destinationRoom: roomOnFloor2,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test("skips missing intermediate floor and still finds route", () {
      final corridor3 = rectCorridor(0, 0, 300, 50);
      final roomOnFloor3 = makeRoom("301", const Point<double>(20, 25));

      final threeFloorBuilding = {
        1: twoFloorBuilding[1]!,
        3: makeFloorplan(
          floorNumber: 3,
          corridors: [corridor3],
          rooms: [roomOnFloor3],
          transitions: [
            FloorTransition(
              id: "h3-stairs-1",
              location: const Point<double>(280, 25),
              type: TransitionType.stairs,
              groupTag: "stairs-1",
            ),
          ],
        ),
      };

      final segments = computeInterFloorPath(
        floorplans: threeFloorBuilding,
        startFloor: 1,
        destinationFloor: 3,
        startRoom: roomOnFloor1,
        destinationRoom: roomOnFloor3,
      );

      expect(segments.length, 2);
      expect(segments[0].floorNumber, 1);
      expect(segments[1].floorNumber, 3);
    });

    test("uses elevator when it is the only available transition", () {
      // Replace both floors so that only elevator transitions exist.
      // This verifies that preferredTransitionType filters candidates
      // and the algorithm routes through the elevator.
      final elevatorTransition1 = FloorTransition(
        id: "h1-elevator-1",
        location: const Point<double>(280, 25),
        type: TransitionType.elevator,
        groupTag: "elevator-1",
      );
      final elevatorTransition2 = FloorTransition(
        id: "h2-elevator-1",
        location: const Point<double>(280, 25),
        type: TransitionType.elevator,
        groupTag: "elevator-1",
      );

      twoFloorBuilding[1] = makeFloorplan(
        floorNumber: 1,
        corridors: twoFloorBuilding[1]!.corridors,
        rooms: [roomOnFloor1],
        transitions: [elevatorTransition1],
      );
      twoFloorBuilding[2] = makeFloorplan(
        floorNumber: 2,
        corridors: twoFloorBuilding[2]!.corridors,
        rooms: [roomOnFloor2],
        transitions: [elevatorTransition2],
      );

      final segments = computeInterFloorPath(
        floorplans: twoFloorBuilding,
        startFloor: 1,
        destinationFloor: 2,
        startRoom: roomOnFloor1,
        destinationRoom: roomOnFloor2,
        preferredTransitionType: TransitionType.elevator,
      );

      expect(segments.length, 2);
      expect(segments[0].exitTransition!.type, TransitionType.elevator);
      expect(segments[0].exitTransition!.groupTag, "elevator-1");
    });

    test("three-floor route produces three segments", () {
      final corridor3 = rectCorridor(0, 0, 300, 50);
      final roomOnFloor3 = makeRoom("301", const Point<double>(20, 25));

      final threeFloorBuilding = {
        1: twoFloorBuilding[1]!,
        2: makeFloorplan(
          floorNumber: 2,
          corridors: twoFloorBuilding[2]!.corridors,
          rooms: [roomOnFloor2],
          transitions: [
            FloorTransition(
              id: "h2-stairs-1",
              location: const Point<double>(280, 25),
              type: TransitionType.stairs,
              groupTag: "stairs-1",
            ),
            FloorTransition(
              id: "h2-stairs-2",
              location: const Point<double>(280, 25),
              type: TransitionType.stairs,
              groupTag: "stairs-2",
            ),
          ],
        ),
        3: makeFloorplan(
          floorNumber: 3,
          corridors: [corridor3],
          rooms: [roomOnFloor3],
          transitions: [
            FloorTransition(
              id: "h3-stairs-2",
              location: const Point<double>(280, 25),
              type: TransitionType.stairs,
              groupTag: "stairs-2",
            ),
          ],
        ),
      };

      final segments = computeInterFloorPath(
        floorplans: threeFloorBuilding,
        startFloor: 1,
        destinationFloor: 3,
        startRoom: roomOnFloor1,
        destinationRoom: roomOnFloor3,
      );

      expect(segments.length, 3);
      expect(segments[0].floorNumber, 1);
      expect(segments[1].floorNumber, 2);
      expect(segments[2].floorNumber, 3);
    });
  });

  // =========================================================================
  // IndoorFloorPathSegment
  // =========================================================================

  group("IndoorFloorPathSegment", () {
    test("stores all fields correctly", () {
      final exit = FloorTransition(
        id: "t1",
        location: const Point<double>(100, 50),
        type: TransitionType.elevator,
        groupTag: "elevator-1",
      );
      final entry = FloorTransition(
        id: "t2",
        location: const Point<double>(100, 50),
        type: TransitionType.elevator,
        groupTag: "elevator-1",
      );

      final segment = IndoorFloorPathSegment(
        floorNumber: 3,
        path: [const Point<double>(10, 10), const Point<double>(100, 50)],
        exitTransition: exit,
        entryTransition: entry,
      );

      expect(segment.floorNumber, 3);
      expect(segment.path.length, 2);
      expect(segment.exitTransition!.id, "t1");
      expect(segment.entryTransition!.id, "t2");
    });

    test("exit and entry transitions default to null", () {
      final segment = IndoorFloorPathSegment(
        floorNumber: 1,
        path: [const Point<double>(0, 0)],
      );

      expect(segment.exitTransition, isNull);
      expect(segment.entryTransition, isNull);
    });
  });
}
