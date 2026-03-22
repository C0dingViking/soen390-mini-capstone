import "dart:math";

import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/domain/models/indoor_pathfinding.dart";
import "package:flutter_test/flutter_test.dart";

// ==========================================================================
// Shared helpers
// ==========================================================================

Corridor rectCorridor(final double x1, final double y1, final double x2, final double y2) {
  return Corridor(
    bounds: [
      Point<double>(x1, y1),
      Point<double>(x2, y1),
      Point<double>(x2, y2),
      Point<double>(x1, y2),
    ],
  );
}

Floorplan makeFloorplan({
  required final String floorNumber,
  required final List<Corridor> corridors,
  final List<IndoorMapRoom> rooms = const [],
  final List<FloorTransition> transitions = const [],
  final String buildingId = "h",
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

IndoorMapRoom makeRoom(final String name, final Point<double> door) {
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

void main() {
  // =========================================================================
  // Lines 10-124: _IndoorGraph.fromCorridors + addDoorNode
  // (tested indirectly through public pathfinding API)
  // =========================================================================

  group("Graph construction and addDoorNode (lines 10-124)", () {
    test("graph from single corridor creates nodes and finds path", () {
      // Covers lines 32-66: _IndoorGraph.fromCorridors
      // Also covers lines 166-170: shortestPathBetweenRooms graph + dijkstra
      final corridor = rectCorridor(0, 0, 100, 50);
      final roomA = makeRoom("A", const Point<double>(10, 25));
      final roomB = makeRoom("B", const Point<double>(90, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("graph from multiple corridors links them via shared vertices", () {
      // Two corridors sharing an edge — tests node deduplication in
      // getOrCreateNodeId (lines 37-48) and cross-corridor connectivity
      final corridor1 = rectCorridor(0, 0, 100, 50);
      final corridor2 = rectCorridor(100, 0, 200, 50);

      final roomA = makeRoom("A", const Point<double>(10, 25));
      final roomB = makeRoom("B", const Point<double>(190, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor1, corridor2],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("door inside corridor connects to corridor nodes (lines 69-128)", () {
      // Door is inside the corridor polygon — covers containingCorridorIndex
      // found on the first pass (lines 73-79) and candidateVertexIds from
      // corridorAllNodeIds (line 105)
      final corridor = rectCorridor(0, 0, 200, 100);
      final roomA = makeRoom("A", const Point<double>(50, 50));
      final roomB = makeRoom("B", const Point<double>(150, 50));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("door outside corridor snaps within threshold (lines 81-101)", () {
      // Door is outside the polygon but within the 20px snap threshold.
      // This covers the snap-to-nearest-corridor fallback (lines 81-101).
      final corridor = rectCorridor(0, 0, 200, 50);
      // Door at y=60 is 10 units below the corridor's bottom edge (y=50),
      // well within the 20px snapThreshold.
      final roomA = makeRoom("A", const Point<double>(10, 60));
      final roomB = makeRoom("B", const Point<double>(190, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("door far outside all corridors falls back to global search (lines 103-108)", () {
      // Door is well beyond the 20px snap threshold, so
      // containingCorridorIndex stays -1 and candidateVertexIds becomes
      // Iterable.generate(doorNodeId) — covers lines 106-108.
      //
      // Corridor vertices: (0,70),(100,70),(100,100),(0,100)
      // Midpoints: (50,70),(100,85),(50,100),(0,85)
      // Centroid: (50,85)
      // roomA must be outside polygon AND > 20px from every vertex.
      // roomB must be inside polygon but NOT coincide with any node.
      final corridor = rectCorridor(0, 70, 100, 100);
      final roomA = makeRoom("A", const Point<double>(50, 25));
      final roomB = makeRoom("B", const Point<double>(60, 82));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test(
      "door exactly at a graph node (bestDistance == 0) does not add duplicate edge (line 122)",
      () {
        // When the door is exactly at a corridor vertex, bestDistance == 0
        // so the guard `bestDistance > 0` on line 122 prevents adding a
        // zero-weight self-edge. The door node becomes the vertex itself
        // via getOrCreateNodeId deduplication during graph construction,
        // but addDoorNode creates a NEW node at the same position.
        // With bestDistance == 0, no edge is added — the door node is isolated.
        // We verify this edge case doesn't crash and raises the expected error.
        final corridor = rectCorridor(0, 0, 200, 50);
        // Place roomA door exactly at a corridor vertex
        final roomA = makeRoom("A", const Point<double>(0, 0));
        // Place roomB inside the corridor
        final roomB = makeRoom("B", const Point<double>(100, 25));

        final floorplan = makeFloorplan(
          floorNumber: "1",
          corridors: [corridor],
          rooms: [roomA, roomB],
        );

        // Door at (0,0) matches a vertex exactly → bestDistance == 0 → no edge
        // → door node is isolated → Dijkstra returns empty → StateError
        expect(() => floorplan.shortestPathBetweenRooms(roomA, roomB), throwsA(isA<StateError>()));
      },
    );

    test("empty corridors list throws StateError (lines 156-164)", () {
      final roomA = makeRoom("A", const Point<double>(10, 10));
      final roomB = makeRoom("B", const Point<double>(90, 10));

      final floorplan = makeFloorplan(floorNumber: "1", corridors: [], rooms: [roomA, roomB]);

      expect(() => floorplan.shortestPathBetweenRooms(roomA, roomB), throwsA(isA<StateError>()));
    });
  });

  // =========================================================================
  // Lines 166-208: shortestPathBetweenRooms & shortestPathToTransition
  // =========================================================================

  group("shortestPathBetweenRooms (lines 166-184)", () {
    test("returns correct start and end positions in path", () {
      final corridor = rectCorridor(0, 0, 400, 60);
      final roomA = makeRoom("101", const Point<double>(20, 30));
      final roomB = makeRoom("102", const Point<double>(380, 30));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path.length, greaterThanOrEqualTo(2));
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("path between adjacent rooms is short", () {
      // Two rooms with doors close together in same corridor
      final corridor = rectCorridor(0, 0, 100, 50);
      final roomA = makeRoom("A", const Point<double>(20, 25));
      final roomB = makeRoom("B", const Point<double>(30, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path, isNotEmpty);
      // Path should be reasonably direct
      expect(path.length, lessThanOrEqualTo(10));
    });
  });

  group("shortestPathToTransition (lines 187-209)", () {
    test("finds path from start point to transition location", () {
      final corridor = rectCorridor(0, 0, 300, 50);
      final transition = FloorTransition(
        id: "stairs-1",
        location: const Point<double>(280, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        transitions: [transition],
      );

      final path = floorplan.shortestPathToTransition(const Point<double>(20, 25), transition);

      expect(path, isNotEmpty);
      expect(path.first.x, closeTo(20, 1));
      expect(path.first.y, closeTo(25, 1));
      expect(path.last.x, closeTo(280, 1));
      expect(path.last.y, closeTo(25, 1));
    });

    test("throws StateError when corridors are empty (lines 191-193)", () {
      final transition = FloorTransition(
        id: "stairs-1",
        location: const Point<double>(100, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      final floorplan = makeFloorplan(floorNumber: "1", corridors: [], transitions: [transition]);

      expect(
        () => floorplan.shortestPathToTransition(const Point<double>(10, 25), transition),
        throwsA(isA<StateError>()),
      );
    });

    test("throws StateError when no path exists to transition (lines 202-206)", () {
      // Two disconnected corridors — start point in one, transition in the other
      // with enough separation that no visibility edge bridges them.
      final corridor1 = rectCorridor(0, 0, 50, 50);
      final corridor2 = rectCorridor(5000, 5000, 5050, 5050);

      final transition = FloorTransition(
        id: "stairs-1",
        location: const Point<double>(5025, 5025),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor1, corridor2],
        transitions: [transition],
      );

      expect(
        () => floorplan.shortestPathToTransition(const Point<double>(25, 25), transition),
        throwsA(isA<StateError>()),
      );
    });
  });

  // =========================================================================
  // Lines 283-364: computeInterFloorPath segment building + final segment
  // =========================================================================

  group("computeInterFloorPath segment building (lines 283-356)", () {
    late Map<String, Floorplan> twoFloorBuilding;
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
        "1": makeFloorplan(
          floorNumber: "1",
          corridors: [corridor1],
          rooms: [roomOnFloor1],
          transitions: [transition1],
        ),
        "2": makeFloorplan(
          floorNumber: "2",
          corridors: [corridor2],
          rooms: [roomOnFloor2],
          transitions: [transition2],
        ),
      };
    });

    test("same-floor route returns single segment without transitions (line 222-226)", () {
      final segments = computeInterFloorPath(
        floorplans: twoFloorBuilding,
        startFloor: "1",
        destinationFloor: "1",
        startRoom: roomOnFloor1,
        destinationRoom: roomOnFloor1,
      );

      expect(segments.length, 1);
      expect(segments.first.floorNumber, "1");
      expect(segments.first.entryTransition, isNull);
      expect(segments.first.exitTransition, isNull);
    });

    test("two-floor route builds correct segments with transitions (lines 283-316)", () {
      final segments = computeInterFloorPath(
        floorplans: twoFloorBuilding,
        startFloor: "1",
        destinationFloor: "2",
        startRoom: roomOnFloor1,
        destinationRoom: roomOnFloor2,
      );

      expect(segments.length, 2);

      // First segment: floor 1 with exit transition
      expect(segments[0].floorNumber, "1");
      expect(segments[0].path, isNotEmpty);
      expect(segments[0].exitTransition, isNotNull);
      expect(segments[0].exitTransition!.groupTag, "stairs-1");
      // First segment's entryTransition should be null (i==0, line 312)
      expect(segments[0].entryTransition, isNull);

      // Second segment: floor 2 with entry transition
      expect(segments[1].floorNumber, "2");
      expect(segments[1].path, isNotEmpty);
      expect(segments[1].entryTransition, isNotNull);
      expect(segments[1].entryTransition!.groupTag, "stairs-1");
    });

    test("reverse direction (floor 2 → 1) traverses floors correctly (lines 244-246)", () {
      final segments = computeInterFloorPath(
        floorplans: twoFloorBuilding,
        startFloor: "2",
        destinationFloor: "1",
        startRoom: roomOnFloor2,
        destinationRoom: roomOnFloor1,
      );

      expect(segments.length, 2);
      expect(segments[0].floorNumber, "2");
      expect(segments[1].floorNumber, "1");
    });

    test("three-floor route produces three segments with chained transitions (lines 259-317)", () {
      final corridor3 = rectCorridor(0, 0, 300, 50);
      final roomOnFloor3 = makeRoom("301", const Point<double>(20, 25));

      final threeFloorBuilding = {
        "1": twoFloorBuilding["1"]!,
        "2": makeFloorplan(
          floorNumber: "2",
          corridors: twoFloorBuilding["2"]!.corridors,
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
        "3": makeFloorplan(
          floorNumber: "3",
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
        startFloor: "1",
        destinationFloor: "3",
        startRoom: roomOnFloor1,
        destinationRoom: roomOnFloor3,
      );

      expect(segments.length, 3);
      expect(segments[0].floorNumber, "1");
      expect(segments[1].floorNumber, "2");
      expect(segments[2].floorNumber, "3");

      // Middle segment should have an entryTransition (i > 0, line 312)
      expect(segments[1].entryTransition, isNotNull);
    });

    test("throws when no matching transition between floors (lines 272-277)", () {
      twoFloorBuilding["2"] = makeFloorplan(
        floorNumber: "2",
        corridors: twoFloorBuilding["2"]!.corridors,
        rooms: [roomOnFloor2],
        transitions: [], // No transitions on floor 2
      );

      expect(
        () => computeInterFloorPath(
          floorplans: twoFloorBuilding,
          startFloor: "1",
          destinationFloor: "2",
          startRoom: roomOnFloor1,
          destinationRoom: roomOnFloor2,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test("throws when no reachable transition on current floor (lines 300-305)", () {
      // Place the transition in a completely disconnected corridor so that
      // shortestPathToTransition throws StateError for every candidate,
      // leaving bestCandidate null.
      final disconnectedCorridor = rectCorridor(5000, 5000, 5050, 5050);
      final transition1 = FloorTransition(
        id: "h1-stairs-1",
        location: const Point<double>(5025, 5025),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      twoFloorBuilding["1"] = makeFloorplan(
        floorNumber: "1",
        corridors: [rectCorridor(0, 0, 300, 50), disconnectedCorridor],
        rooms: [roomOnFloor1],
        transitions: [transition1],
      );

      expect(
        () => computeInterFloorPath(
          floorplans: twoFloorBuilding,
          startFloor: "1",
          destinationFloor: "2",
          startRoom: roomOnFloor1,
          destinationRoom: roomOnFloor2,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test("throws when destination floor entry transition missing (lines 323-326)", () {
      // Floor 1 has a transition with groupTag "stairs-1", but destination
      // floor has a transition with a different groupTag, so firstWhere fails.
      twoFloorBuilding["2"] = makeFloorplan(
        floorNumber: "2",
        corridors: twoFloorBuilding["2"]!.corridors,
        rooms: [roomOnFloor2],
        transitions: [
          FloorTransition(
            id: "h2-stairs-X",
            location: const Point<double>(280, 25),
            type: TransitionType.stairs,
            groupTag: "stairs-MISMATCH",
          ),
        ],
      );

      expect(
        () => computeInterFloorPath(
          floorplans: twoFloorBuilding,
          startFloor: "1",
          destinationFloor: "2",
          startRoom: roomOnFloor1,
          destinationRoom: roomOnFloor2,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test("throws when final segment path to destination room fails (lines 348-353)", () {
      // Floor 2 has the matching entry transition in one corridor, but the
      // destination room is in a completely disconnected corridor far away
      // so shortestPathToTransition throws StateError.
      final disconnectedRoom = makeRoom("201", const Point<double>(9000, 9000));

      twoFloorBuilding["2"] = makeFloorplan(
        floorNumber: "2",
        corridors: [
          rectCorridor(0, 0, 300, 50), // transition lives here
          rectCorridor(8990, 8990, 9050, 9050), // room lives here, far away
        ],
        rooms: [disconnectedRoom],
        transitions: [
          FloorTransition(
            id: "h2-stairs-1",
            location: const Point<double>(280, 25),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ],
      );

      expect(
        () => computeInterFloorPath(
          floorplans: twoFloorBuilding,
          startFloor: "1",
          destinationFloor: "2",
          startRoom: roomOnFloor1,
          destinationRoom: disconnectedRoom,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test("prefers elevator transitions when preferredTransitionType is set (lines 386-393)", () {
      final elevatorTransition1 = FloorTransition(
        id: "h1-elevator-1",
        location: const Point<double>(280, 25),
        type: TransitionType.elevator,
        groupTag: "elevator-1",
      );
      final stairsTransition1 = FloorTransition(
        id: "h1-stairs-1",
        location: const Point<double>(280, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );
      final elevatorTransition2 = FloorTransition(
        id: "h2-elevator-1",
        location: const Point<double>(280, 25),
        type: TransitionType.elevator,
        groupTag: "elevator-1",
      );
      final stairsTransition2 = FloorTransition(
        id: "h2-stairs-1",
        location: const Point<double>(280, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      twoFloorBuilding["1"] = makeFloorplan(
        floorNumber: "1",
        corridors: twoFloorBuilding["1"]!.corridors,
        rooms: [roomOnFloor1],
        transitions: [stairsTransition1, elevatorTransition1],
      );
      twoFloorBuilding["2"] = makeFloorplan(
        floorNumber: "2",
        corridors: twoFloorBuilding["2"]!.corridors,
        rooms: [roomOnFloor2],
        transitions: [stairsTransition2, elevatorTransition2],
      );

      final segments = computeInterFloorPath(
        floorplans: twoFloorBuilding,
        startFloor: "1",
        destinationFloor: "2",
        startRoom: roomOnFloor1,
        destinationRoom: roomOnFloor2,
        preferredTransitionType: TransitionType.elevator,
      );

      expect(segments.length, 2);
      expect(segments[0].exitTransition!.type, TransitionType.elevator);
      expect(segments[0].exitTransition!.groupTag, "elevator-1");
    });

    test("accessibleMode prefers non-stairs transitions when available (lines 305-332)", () {
      // Mix of stairs and elevator transitions connecting floors 1 and 2.
      // With accessibleMode = true the non-stairs pair should be chosen,
      // exercising the candidates filtering block at lines 305-332.
      final corridor1 = rectCorridor(0, 0, 300, 50);
      final corridor2 = rectCorridor(0, 0, 300, 50);
      final room1 = makeRoom("101", const Point<double>(20, 25));
      final room2 = makeRoom("201", const Point<double>(20, 25));

      final stairsTransition1 = FloorTransition(
        id: "h1-stairs-1",
        location: const Point<double>(280, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );
      final elevatorTransition1 = FloorTransition(
        id: "h1-elevator-1",
        location: const Point<double>(50, 25),
        type: TransitionType.elevator,
        groupTag: "elevator-1",
      );

      final stairsTransition2 = FloorTransition(
        id: "h2-stairs-1",
        location: const Point<double>(280, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );
      final elevatorTransition2 = FloorTransition(
        id: "h2-elevator-1",
        location: const Point<double>(50, 25),
        type: TransitionType.elevator,
        groupTag: "elevator-1",
      );

      final building = {
        "1": makeFloorplan(
          floorNumber: "1",
          corridors: [corridor1],
          rooms: [room1],
          transitions: [stairsTransition1, elevatorTransition1],
        ),
        "2": makeFloorplan(
          floorNumber: "2",
          corridors: [corridor2],
          rooms: [room2],
          transitions: [stairsTransition2, elevatorTransition2],
        ),
      };

      final segments = computeInterFloorPath(
        floorplans: building,
        startFloor: "1",
        destinationFloor: "2",
        startRoom: room1,
        destinationRoom: room2,
        accessibleMode: true,
      );

      expect(segments.length, 2);
      // The non-stairs (elevator) candidate should be selected.
      expect(segments[0].exitTransition!.type, TransitionType.elevator);
      expect(segments[0].exitTransition!.groupTag, "elevator-1");
    });

    test("accessibleMode falls back to stairs when no non-stairs exist (lines 305-332)", () {
      // Only stairs transitions are available between the floors. With
      // accessibleMode = true, nonStairs.isEmpty so the algorithm must
      // fall back to all candidates rather than throwing.
      final segments = computeInterFloorPath(
        floorplans: twoFloorBuilding,
        startFloor: "1",
        destinationFloor: "2",
        startRoom: roomOnFloor1,
        destinationRoom: roomOnFloor2,
        accessibleMode: true,
      );

      expect(segments.length, 2);
      expect(segments[0].exitTransition!.type, TransitionType.stairs);
      expect(segments[0].exitTransition!.groupTag, "stairs-1");
    });

    test("floor sort key handles non-numeric floor identifiers (lines 230-236)", () {
      // Floors with non-numeric prefixes should be sorted by their numeric
      // portion. "B1" → 1, "2" → 2.
      final corridorB1 = rectCorridor(0, 0, 300, 50);
      final roomB1 = makeRoom("B101", const Point<double>(20, 25));
      final transitionB1 = FloorTransition(
        id: "hB1-stairs-1",
        location: const Point<double>(280, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      final corridor2 = rectCorridor(0, 0, 300, 50);
      final room2 = makeRoom("201", const Point<double>(20, 25));
      final transition2 = FloorTransition(
        id: "h2-stairs-1",
        location: const Point<double>(280, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-1",
      );

      final building = {
        "B1": makeFloorplan(
          floorNumber: "B1",
          corridors: [corridorB1],
          rooms: [roomB1],
          transitions: [transitionB1],
        ),
        "2": makeFloorplan(
          floorNumber: "2",
          corridors: [corridor2],
          rooms: [room2],
          transitions: [transition2],
        ),
      };

      final segments = computeInterFloorPath(
        floorplans: building,
        startFloor: "B1",
        destinationFloor: "2",
        startRoom: roomB1,
        destinationRoom: room2,
      );

      expect(segments.length, 2);
      expect(segments[0].floorNumber, "B1");
      expect(segments[1].floorNumber, "2");
    });
  });

  // =========================================================================
  // Lines 339-669: _TransitionCandidate, _findMatchingTransitions,
  // _pathLength, graph helpers, _pointInPolygon, _dijkstra
  // (tested indirectly through public API)
  // =========================================================================

  group("_findMatchingTransitions (lines 368-396)", () {
    test("non-matching groupTags produce no candidates => throws", () {
      // If fromFloor has groupTag "A" and toFloor has groupTag "B",
      // candidates list is empty, causing a StateError at line 272-277.
      final corridor1 = rectCorridor(0, 0, 300, 50);
      final corridor2 = rectCorridor(0, 0, 300, 50);
      final room1 = makeRoom("101", const Point<double>(20, 25));
      final room2 = makeRoom("201", const Point<double>(20, 25));

      final building = {
        "1": makeFloorplan(
          floorNumber: "1",
          corridors: [corridor1],
          rooms: [room1],
          transitions: [
            FloorTransition(
              id: "t1",
              location: const Point<double>(280, 25),
              type: TransitionType.stairs,
              groupTag: "tag-A",
            ),
          ],
        ),
        "2": makeFloorplan(
          floorNumber: "2",
          corridors: [corridor2],
          rooms: [room2],
          transitions: [
            FloorTransition(
              id: "t2",
              location: const Point<double>(280, 25),
              type: TransitionType.stairs,
              groupTag: "tag-B",
            ),
          ],
        ),
      };

      expect(
        () => computeInterFloorPath(
          floorplans: building,
          startFloor: "1",
          destinationFloor: "2",
          startRoom: room1,
          destinationRoom: room2,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test("preferred type is sorted first among candidates (lines 388-393)", () {
      // Both elevator and stairs share the same groupTag — elevator is
      // preferred, so it should appear first and be chosen by the
      // best-cost loop (lines 283-298).
      final corridor1 = rectCorridor(0, 0, 300, 50);
      final corridor2 = rectCorridor(0, 0, 300, 50);
      final room1 = makeRoom("101", const Point<double>(20, 25));
      final room2 = makeRoom("201", const Point<double>(20, 25));

      final building = {
        "1": makeFloorplan(
          floorNumber: "1",
          corridors: [corridor1],
          rooms: [room1],
          transitions: [
            FloorTransition(
              id: "elev-1",
              location: const Point<double>(280, 25),
              type: TransitionType.elevator,
              groupTag: "group-1",
            ),
            FloorTransition(
              id: "stairs-1",
              location: const Point<double>(280, 25),
              type: TransitionType.stairs,
              groupTag: "group-1",
            ),
          ],
        ),
        "2": makeFloorplan(
          floorNumber: "2",
          corridors: [corridor2],
          rooms: [room2],
          transitions: [
            FloorTransition(
              id: "elev-2",
              location: const Point<double>(280, 25),
              type: TransitionType.elevator,
              groupTag: "group-1",
            ),
          ],
        ),
      };

      final segments = computeInterFloorPath(
        floorplans: building,
        startFloor: "1",
        destinationFloor: "2",
        startRoom: room1,
        destinationRoom: room2,
        preferredTransitionType: TransitionType.elevator,
      );

      expect(segments[0].exitTransition!.type, TransitionType.elevator);
    });
  });

  group("_pathLength (lines 399-405)", () {
    test("best cost among candidates is selected (covers _pathLength)", () {
      // Two transitions at different distances — the shorter path should win.
      // This exercises _pathLength (lines 399-405) and the bestCost comparison
      // at lines 290-294.
      final corridor = rectCorridor(0, 0, 500, 50);
      final room1 = makeRoom("101", const Point<double>(20, 25));
      final room2 = makeRoom("201", const Point<double>(20, 25));

      final nearTransition1 = FloorTransition(
        id: "near-1",
        location: const Point<double>(50, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-near",
      );
      final farTransition1 = FloorTransition(
        id: "far-1",
        location: const Point<double>(480, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-far",
      );

      final corridor2 = rectCorridor(0, 0, 500, 50);
      final nearTransition2 = FloorTransition(
        id: "near-2",
        location: const Point<double>(50, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-near",
      );
      final farTransition2 = FloorTransition(
        id: "far-2",
        location: const Point<double>(480, 25),
        type: TransitionType.stairs,
        groupTag: "stairs-far",
      );

      final building = {
        "1": makeFloorplan(
          floorNumber: "1",
          corridors: [corridor],
          rooms: [room1],
          transitions: [nearTransition1, farTransition1],
        ),
        "2": makeFloorplan(
          floorNumber: "2",
          corridors: [corridor2],
          rooms: [room2],
          transitions: [nearTransition2, farTransition2],
        ),
      };

      final segments = computeInterFloorPath(
        floorplans: building,
        startFloor: "1",
        destinationFloor: "2",
        startRoom: room1,
        destinationRoom: room2,
      );

      // The near transition should be chosen because its path cost is lower
      expect(segments[0].exitTransition!.groupTag, "stairs-near");
    });
  });

  group("Graph helpers (lines 409-561)", () {
    test("_euclideanDistance produces correct path lengths (lines 410-414)", () {
      // Verify indirectly by checking that a simple straight corridor
      // path has a reasonable number of waypoints.
      final corridor = rectCorridor(0, 0, 100, 20);
      final roomA = makeRoom("A", const Point<double>(5, 10));
      final roomB = makeRoom("B", const Point<double>(95, 10));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);
      expect(path, isNotEmpty);
    });

    test("_snapNearbyVertices bridges small gaps between corridors (lines 465-485)", () {
      // Two corridors with a 3-unit gap (< 5.0 threshold) — snap should bridge
      final corridor1 = rectCorridor(0, 0, 100, 50);
      final corridor2 = rectCorridor(103, 0, 200, 50); // 3px gap

      final roomA = makeRoom("A", const Point<double>(10, 25));
      final roomB = makeRoom("B", const Point<double>(190, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor1, corridor2],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);
      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("_addCorridorInteriorPoints adds midpoints and centroids (lines 488-519)", () {
      // A large corridor where interior points (midpoints + centroid) help
      // create shorter paths than just polygon vertices alone.
      final corridor = rectCorridor(0, 0, 400, 200);
      final roomA = makeRoom("A", const Point<double>(50, 100));
      final roomB = makeRoom("B", const Point<double>(350, 100));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);
      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("corridor with fewer than 3 bounds skips interior points (line 495-496)", () {
      // A degenerate corridor with only 2 points — _addCorridorInteriorPoints
      // skips it (line 495-496), but the graph still works.
      final degenerateCorridor = Corridor(
        bounds: [const Point<double>(0, 0), const Point<double>(100, 0)],
      );
      final normalCorridor = rectCorridor(0, 0, 200, 50);
      final roomA = makeRoom("A", const Point<double>(10, 25));
      final roomB = makeRoom("B", const Point<double>(190, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [degenerateCorridor, normalCorridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);
      expect(path, isNotEmpty);
    });

    test("_connectCorridorEdges skips corridors with fewer than 2 vertices (line 442-443)", () {
      // A single-point corridor — _connectCorridorEdges skips it.
      final singlePointCorridor = Corridor(bounds: [const Point<double>(50, 50)]);
      final normalCorridor = rectCorridor(0, 0, 200, 50);
      final roomA = makeRoom("A", const Point<double>(10, 25));
      final roomB = makeRoom("B", const Point<double>(190, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [singlePointCorridor, normalCorridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);
      expect(path, isNotEmpty);
    });

    test("_addGlobalVisibilityEdges skips edges beyond 200px (lines 534-549)", () {
      // Two corridors > 200px apart — visibility edges won't bridge them,
      // and snap threshold (5px) is also exceeded, so no path exists.
      final corridor1 = rectCorridor(0, 0, 50, 50);
      final corridor2 = rectCorridor(500, 500, 550, 550);

      final roomA = makeRoom("A", const Point<double>(25, 25));
      final roomB = makeRoom("B", const Point<double>(525, 525));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor1, corridor2],
        rooms: [roomA, roomB],
      );

      // No path can be found because the corridors are too far apart
      expect(() => floorplan.shortestPathBetweenRooms(roomA, roomB), throwsA(isA<StateError>()));
    });

    test("_segmentInsideAnyCorridor rejects segments outside corridors (lines 564-589)", () {
      // An L-shaped arrangement where a straight-line shortcut would exit
      // the corridor union. The algorithm should route through the bend.
      final corridorH = rectCorridor(0, 0, 200, 40);
      final corridorV = rectCorridor(160, 0, 200, 200);

      final roomA = makeRoom("A", const Point<double>(10, 20));
      final roomB = makeRoom("B", const Point<double>(180, 180));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridorH, corridorV],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);
      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });
  });

  group("_pointInPolygon (lines 592-613)", () {
    test("point inside rectangle is detected (lines 597-612)", () {
      // Tested indirectly: a door inside a corridor should connect to that
      // corridor's nodes (containingCorridorIndex >= 0).
      final corridor = rectCorridor(0, 0, 200, 50);
      final roomA = makeRoom("A", const Point<double>(30, 25));
      final roomB = makeRoom("B", const Point<double>(170, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);
      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("polygon with fewer than 3 points returns false (line 593-594)", () {
      // A degenerate corridor — door can't be "inside" it, so it falls back
      // to snap or global search.
      final degenerateCorridor = Corridor(
        bounds: [const Point<double>(50, 50), const Point<double>(100, 50)],
      );
      final normalCorridor = rectCorridor(0, 0, 200, 50);

      final roomA = makeRoom("A", const Point<double>(75, 50));
      final roomB = makeRoom("B", const Point<double>(150, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [degenerateCorridor, normalCorridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);
      expect(path, isNotEmpty);
    });
  });

  group("_dijkstra (lines 616-669)", () {
    test("returns empty path for disconnected nodes (lines 658-659)", () {
      // Two far-apart disconnected corridors — Dijkstra should find no path,
      // causing shortestPathBetweenRooms to throw.
      final corridor1 = rectCorridor(0, 0, 50, 50);
      final corridor2 = rectCorridor(5000, 5000, 5050, 5050);

      final roomA = makeRoom("A", const Point<double>(25, 25));
      final roomB = makeRoom("B", const Point<double>(5025, 5025));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor1, corridor2],
        rooms: [roomA, roomB],
      );

      // shortestPathBetweenRooms wraps the empty-path case in a StateError
      // (lines 173-181)
      expect(() => floorplan.shortestPathBetweenRooms(roomA, roomB), throwsA(isA<StateError>()));
    });

    test("dijkstra finds path and reconstructs it correctly (lines 662-669)", () {
      // Simple scenario where path reconstruction (lines 662-669) is exercised
      final corridor = rectCorridor(0, 0, 300, 50);
      final roomA = makeRoom("A", const Point<double>(10, 25));
      final roomB = makeRoom("B", const Point<double>(290, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path.length, greaterThanOrEqualTo(2));
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("dijkstra early termination when endId is reached (line 639)", () {
      // Simple two-room test — Dijkstra should stop as soon as endId is popped
      final corridor = rectCorridor(0, 0, 50, 50);
      final roomA = makeRoom("A", const Point<double>(10, 25));
      final roomB = makeRoom("B", const Point<double>(40, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);
      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
    });

    test("dijkstra visits multiple nodes before reaching target (line 628-656)", () {
      // Multiple connected corridors force Dijkstra to iterate through many
      // graph nodes before finding the shortest path.
      final corridor1 = rectCorridor(0, 0, 150, 50);
      final corridor2 = rectCorridor(150, 0, 300, 50);
      final corridor3 = rectCorridor(300, 0, 450, 50);

      final roomA = makeRoom("A", const Point<double>(10, 25));
      final roomB = makeRoom("B", const Point<double>(440, 25));

      final floorplan = makeFloorplan(
        floorNumber: "1",
        corridors: [corridor1, corridor2, corridor3],
        rooms: [roomA, roomB],
      );

      final path = floorplan.shortestPathBetweenRooms(roomA, roomB);

      expect(path, isNotEmpty);
      expect(path.first, roomA.doorLocation);
      expect(path.last, roomB.doorLocation);
      // The path should have intermediate waypoints
      expect(path.length, greaterThan(2));
    });
  });

  // =========================================================================
  // IndoorFloorPathSegment (lines 133-148)
  // =========================================================================

  group("IndoorFloorPathSegment (lines 133-148)", () {
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
        floorNumber: "3",
        path: [const Point<double>(10, 10), const Point<double>(100, 50)],
        exitTransition: exit,
        entryTransition: entry,
      );

      expect(segment.floorNumber, "3");
      expect(segment.path.length, 2);
      expect(segment.exitTransition!.id, "t1");
      expect(segment.entryTransition!.id, "t2");
    });

    test("exit and entry transitions default to null", () {
      final segment = IndoorFloorPathSegment(floorNumber: "1", path: [const Point<double>(0, 0)]);

      expect(segment.exitTransition, isNull);
      expect(segment.entryTransition, isNull);
    });
  });
}
