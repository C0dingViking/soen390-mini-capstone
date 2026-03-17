import "dart:math";

import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/domain/models/indoor_pathfinding.dart";
import "package:concordia_campus_guide/ui/indoor_map/view_models/indoor_view_model.dart";
import "package:flutter_test/flutter_test.dart";
import "package:logger/logger.dart";

class _FakeFloorplanInteractor extends FloorplanInteractor {
  bool returnEmpty = false;
  int executionCount = 0;

  @override
  Future<Map<int, Floorplan>> loadFloorplans(final String buildingId) async {
    executionCount += 1;

    return (returnEmpty)
        ? {}
        : {1: Floorplan(buildingId: "T", floorNumber: 1, svgPath: "test.svg", rooms: [], pois: [])};
  }

  @override
  Future<List<String>> loadRoomNames() async {
    return (returnEmpty) ? [] : ["T 1", "T 2", "T 3"];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IndoorViewModel ivm;
  late _FakeFloorplanInteractor floorplanInteractor;

  setUp(() {
    Logger.level = Level.off;
    floorplanInteractor = _FakeFloorplanInteractor();
    ivm = IndoorViewModel(floorplanInteractor: floorplanInteractor);
  });

  group("State Management", () {
    test("initial state is correct", () {
      expect(ivm.loadedBuildingId, null);
      expect(ivm.loadedFloorplans, null);
      expect(ivm.selectedFloorplan, null);
      expect(ivm.availableFloors, null);
      expect(ivm.isLoading, false);
      expect(ivm.loadFailed, false);
    });

    test("resetFloorplanLoadState resets load state correctly", () {
      ivm.loadFailed = true;
      ivm.isLoading = true;

      ivm.resetFloorplanLoadState();
      expect(ivm.loadFailed, false);
      expect(ivm.isLoading, false);
    });
  });

  group("initializeBuildingFloorplans", () {
    test("initializeBuildingFloorplans loads floorplans successfully", () async {
      await ivm.initializeBuildingFloorplans("T");
      expect(ivm.loadedBuildingId, "T");
      expect(ivm.loadedFloorplans, isNotNull);
      expect(ivm.loadedFloorplans!.length, 1);
      expect(ivm.selectedFloorplan, isNotNull);
      expect(ivm.selectedFloorplan!.buildingId, "T");
      expect(ivm.availableFloors, isNotNull);
      expect(ivm.availableFloors!.length, 1);
      expect(ivm.availableFloors!.first, 1);
      expect(ivm.isLoading, false);
      expect(ivm.loadFailed, false);
    });

    test(
      "initializeBuildingFloorplans does not reload if same building is already loaded",
      () async {
        await ivm.initializeBuildingFloorplans("T");
        final initialLoadedFloorplans = ivm.loadedFloorplans;

        await ivm.initializeBuildingFloorplans("T");
        expect(ivm.loadedFloorplans, initialLoadedFloorplans);
        expect(floorplanInteractor.executionCount, 1);
      },
    );

    test("initializeBuildingFloorplans handles empty floorplans", () async {
      floorplanInteractor.returnEmpty = true;

      await ivm.initializeBuildingFloorplans("T");
      expect(ivm.loadFailed, true);
    });
  });

  group("changeFloor", () {
    test("changeFloor changes selected floorplan successfully", () async {
      ivm.loadedFloorplans = {
        1: Floorplan(buildingId: "T", floorNumber: 1, svgPath: "floor1.svg", rooms: [], pois: []),
        2: Floorplan(buildingId: "T", floorNumber: 2, svgPath: "floor2.svg", rooms: [], pois: []),
      };
      ivm.selectedFloorplan = ivm.loadedFloorplans![1];

      final success = ivm.changeFloor(1);
      expect(success, true);
      expect(ivm.selectedFloorplan, isNotNull);
      expect(ivm.selectedFloorplan!.floorNumber, 1);

      final success2 = ivm.changeFloor(2);
      expect(success2, true);
      expect(ivm.selectedFloorplan, isNotNull);
      expect(ivm.selectedFloorplan!.floorNumber, 2);
    });

    test("changeFloor returns false for invalid floor number", () async {
      await ivm.initializeBuildingFloorplans("T");
      final success = ivm.changeFloor(2);

      expect(success, false);
      expect(ivm.selectedFloorplan, isNotNull);
      expect(ivm.selectedFloorplan!.floorNumber, 1);
    });
  });

  group("initializeRoomNames", () {
    test("initializeRoomNames loads roomNames successfully", () async {
      await ivm.initializeRoomNames();
      final List<String>? results = ivm.loadedRoomNames;

      expect(results, isNotNull);
      expect(results!, isNotEmpty);
      expect(results.length, 3);
      expect(results[0], "T 1");
      expect(results[1], "T 2");
      expect(results[2], "T 3");
    });

    test("initializeRoomNames handles empty returns", () async {
      floorplanInteractor.returnEmpty = true;

      await ivm.initializeRoomNames();
      expect(ivm.listLoadFailed, true);
    });
  });

  // =========================================================================
  // Inter-floor path segment helpers
  // =========================================================================

  List<IndoorFloorPathSegment> twoFloorSegments() {
    return [
      IndoorFloorPathSegment(
        floorNumber: 1,
        path: [const Point(10, 10), const Point(100, 50)],
        exitTransition: const FloorTransition(
          id: "h1-stairs-1",
          location: Point(100, 50),
          type: TransitionType.stairs,
          groupTag: "stairs-1",
        ),
      ),
      IndoorFloorPathSegment(
        floorNumber: 2,
        path: [const Point(100, 50), const Point(20, 30)],
        entryTransition: const FloorTransition(
          id: "h2-stairs-1",
          location: Point(100, 50),
          type: TransitionType.stairs,
          groupTag: "stairs-1",
        ),
      ),
    ];
  }

  List<IndoorFloorPathSegment> threeFloorSegments() {
    return [
      IndoorFloorPathSegment(
        floorNumber: 1,
        path: [const Point(10, 10), const Point(100, 50)],
        exitTransition: const FloorTransition(
          id: "h1-stairs-1",
          location: Point(100, 50),
          type: TransitionType.stairs,
          groupTag: "stairs-1",
        ),
      ),
      IndoorFloorPathSegment(
        floorNumber: 2,
        path: [const Point(100, 50), const Point(200, 50)],
        entryTransition: const FloorTransition(
          id: "h2-stairs-1",
          location: Point(100, 50),
          type: TransitionType.stairs,
          groupTag: "stairs-1",
        ),
        exitTransition: const FloorTransition(
          id: "h2-stairs-2",
          location: Point(200, 50),
          type: TransitionType.stairs,
          groupTag: "stairs-2",
        ),
      ),
      IndoorFloorPathSegment(
        floorNumber: 3,
        path: [const Point(200, 50), const Point(20, 30)],
        entryTransition: const FloorTransition(
          id: "h3-stairs-2",
          location: Point(200, 50),
          type: TransitionType.stairs,
          groupTag: "stairs-2",
        ),
      ),
    ];
  }

  // =========================================================================
  // Inter-floor route state
  // =========================================================================

  group("isInterFloorRoute", () {
    test("returns false when no route is set", () {
      expect(ivm.isInterFloorRoute, isFalse);
    });

    test("returns false for a single-floor path set via setIndoorPath", () {
      ivm.setIndoorPath([const Point(0, 0), const Point(100, 100)]);
      expect(ivm.isInterFloorRoute, isFalse);
    });

    test("returns true after setInterFloorPath with multiple segments", () {
      ivm.loadedFloorplans = {
        1: Floorplan(buildingId: "T", floorNumber: 1, svgPath: "f1.svg", rooms: [], pois: []),
        2: Floorplan(buildingId: "T", floorNumber: 2, svgPath: "f2.svg", rooms: [], pois: []),
      };
      ivm.selectedFloorplan = ivm.loadedFloorplans![1];

      ivm.setInterFloorPath(twoFloorSegments());
      expect(ivm.isInterFloorRoute, isTrue);
    });

    test("returns false after setInterFloorPath with a single segment", () {
      ivm.setInterFloorPath([
        IndoorFloorPathSegment(floorNumber: 1, path: [const Point(0, 0), const Point(50, 50)]),
      ]);
      expect(ivm.isInterFloorRoute, isFalse);
    });
  });

  // =========================================================================
  // setInterFloorPath
  // =========================================================================

  group("setInterFloorPath", () {
    setUp(() {
      ivm.loadedFloorplans = {
        1: Floorplan(buildingId: "T", floorNumber: 1, svgPath: "f1.svg", rooms: [], pois: []),
        2: Floorplan(buildingId: "T", floorNumber: 2, svgPath: "f2.svg", rooms: [], pois: []),
        3: Floorplan(buildingId: "T", floorNumber: 3, svgPath: "f3.svg", rooms: [], pois: []),
      };
      ivm.selectedFloorplan = ivm.loadedFloorplans![1];
    });

    test("sets indoorPath to the first segment's path", () {
      final segments = twoFloorSegments();
      ivm.setInterFloorPath(segments);

      expect(ivm.indoorPath, equals(segments[0].path));
    });

    test("switches selectedFloorplan to the first segment's floor", () {
      ivm.selectedFloorplan = ivm.loadedFloorplans![2];
      ivm.setInterFloorPath(twoFloorSegments());

      expect(ivm.selectedFloorplan!.floorNumber, 1);
    });

    test("resets segment index to 0 on new route", () {
      ivm.setInterFloorPath(twoFloorSegments());
      ivm.advanceToNextSegment();
      expect(ivm.currentSegmentIndex, 1);

      ivm.setInterFloorPath(twoFloorSegments());
      expect(ivm.currentSegmentIndex, 0);
    });

    test("clears everything when called with empty segments", () {
      ivm.setInterFloorPath(twoFloorSegments());
      ivm.setInterFloorPath([]);

      expect(ivm.indoorPath, isNull);
      expect(ivm.isInterFloorRoute, isFalse);
    });

    test("notifies listeners", () {
      int notifyCount = 0;
      ivm.addListener(() => notifyCount++);

      ivm.setInterFloorPath(twoFloorSegments());
      expect(notifyCount, 1);
    });
  });

  // =========================================================================
  // Segment navigation (advanceToNextSegment / goToPreviousSegment)
  // =========================================================================

  group("segment navigation", () {
    setUp(() {
      ivm.loadedFloorplans = {
        1: Floorplan(buildingId: "T", floorNumber: 1, svgPath: "f1.svg", rooms: [], pois: []),
        2: Floorplan(buildingId: "T", floorNumber: 2, svgPath: "f2.svg", rooms: [], pois: []),
        3: Floorplan(buildingId: "T", floorNumber: 3, svgPath: "f3.svg", rooms: [], pois: []),
      };
      ivm.selectedFloorplan = ivm.loadedFloorplans![1];
    });

    test("advanceToNextSegment moves to segment index 1", () {
      ivm.setInterFloorPath(twoFloorSegments());
      final result = ivm.advanceToNextSegment();

      expect(result, isTrue);
      expect(ivm.currentSegmentIndex, 1);
      expect(ivm.selectedFloorplan!.floorNumber, 2);
      expect(ivm.indoorPath, equals(twoFloorSegments()[1].path));
    });

    test("advanceToNextSegment returns false at last segment", () {
      ivm.setInterFloorPath(twoFloorSegments());
      ivm.advanceToNextSegment();

      final result = ivm.advanceToNextSegment();
      expect(result, isFalse);
      expect(ivm.currentSegmentIndex, 1);
    });

    test("goToPreviousSegment moves back to segment index 0", () {
      ivm.setInterFloorPath(twoFloorSegments());
      ivm.advanceToNextSegment();

      final result = ivm.goToPreviousSegment();
      expect(result, isTrue);
      expect(ivm.currentSegmentIndex, 0);
      expect(ivm.selectedFloorplan!.floorNumber, 1);
    });

    test("goToPreviousSegment returns false at first segment", () {
      ivm.setInterFloorPath(twoFloorSegments());

      final result = ivm.goToPreviousSegment();
      expect(result, isFalse);
      expect(ivm.currentSegmentIndex, 0);
    });

    test("three-segment navigation walks forward and backward", () {
      ivm.setInterFloorPath(threeFloorSegments());

      expect(ivm.totalSegments, 3);
      expect(ivm.currentSegmentIndex, 0);
      expect(ivm.hasNextSegment, isTrue);
      expect(ivm.hasPreviousSegment, isFalse);

      ivm.advanceToNextSegment();
      expect(ivm.currentSegmentIndex, 1);
      expect(ivm.selectedFloorplan!.floorNumber, 2);
      expect(ivm.hasNextSegment, isTrue);
      expect(ivm.hasPreviousSegment, isTrue);

      ivm.advanceToNextSegment();
      expect(ivm.currentSegmentIndex, 2);
      expect(ivm.selectedFloorplan!.floorNumber, 3);
      expect(ivm.hasNextSegment, isFalse);
      expect(ivm.hasPreviousSegment, isTrue);

      ivm.goToPreviousSegment();
      expect(ivm.currentSegmentIndex, 1);
      expect(ivm.selectedFloorplan!.floorNumber, 2);
    });

    test("each navigation step notifies listeners", () {
      ivm.setInterFloorPath(threeFloorSegments());

      int notifyCount = 0;
      ivm.addListener(() => notifyCount++);

      ivm.advanceToNextSegment();
      expect(notifyCount, 1);

      ivm.advanceToNextSegment();
      expect(notifyCount, 2);

      ivm.goToPreviousSegment();
      expect(notifyCount, 3);
    });
  });

  // =========================================================================
  // currentSegment
  // =========================================================================

  group("currentSegment", () {
    setUp(() {
      ivm.loadedFloorplans = {
        1: Floorplan(buildingId: "T", floorNumber: 1, svgPath: "f1.svg", rooms: [], pois: []),
        2: Floorplan(buildingId: "T", floorNumber: 2, svgPath: "f2.svg", rooms: [], pois: []),
        3: Floorplan(buildingId: "T", floorNumber: 3, svgPath: "f3.svg", rooms: [], pois: []),
      };
      ivm.selectedFloorplan = ivm.loadedFloorplans![1];
    });

    test("returns null when no route is active", () {
      expect(ivm.currentSegment, isNull);
    });

    test("returns the correct segment after navigation", () {
      final segments = threeFloorSegments();
      ivm.setInterFloorPath(segments);

      expect(ivm.currentSegment!.floorNumber, segments[0].floorNumber);

      ivm.advanceToNextSegment();
      expect(ivm.currentSegment!.floorNumber, segments[1].floorNumber);
    });
  });

  // =========================================================================
  // changeFloor interaction with inter-floor route
  // =========================================================================

  group("changeFloor with active inter-floor route", () {
    setUp(() {
      ivm.loadedFloorplans = {
        1: Floorplan(buildingId: "T", floorNumber: 1, svgPath: "f1.svg", rooms: [], pois: []),
        2: Floorplan(buildingId: "T", floorNumber: 2, svgPath: "f2.svg", rooms: [], pois: []),
        3: Floorplan(buildingId: "T", floorNumber: 3, svgPath: "f3.svg", rooms: [], pois: []),
      };
      ivm.selectedFloorplan = ivm.loadedFloorplans![1];
    });

    test("syncs indoorPath to the segment for the selected floor", () {
      final segments = threeFloorSegments();
      ivm.setInterFloorPath(segments);

      ivm.changeFloor(3);

      expect(ivm.indoorPath, equals(segments[2].path));
      expect(ivm.currentSegmentIndex, 2);
    });

    test("clears indoorPath if the selected floor has no segment", () {
      ivm.setInterFloorPath(twoFloorSegments());

      ivm.changeFloor(3);

      expect(ivm.indoorPath, isNull);
    });

    test("does not affect path when no inter-floor route is active", () {
      ivm.setIndoorPath([const Point(0, 0), const Point(50, 50)]);
      ivm.changeFloor(2);

      expect(ivm.indoorPath, isNull);
    });
  });

  // =========================================================================
  // clearIndoorPath with inter-floor state
  // =========================================================================

  group("clearIndoorPath with inter-floor state", () {
    setUp(() {
      ivm.loadedFloorplans = {
        1: Floorplan(buildingId: "T", floorNumber: 1, svgPath: "f1.svg", rooms: [], pois: []),
        2: Floorplan(buildingId: "T", floorNumber: 2, svgPath: "f2.svg", rooms: [], pois: []),
      };
      ivm.selectedFloorplan = ivm.loadedFloorplans![1];
    });

    test("clears inter-floor segments and resets index", () {
      ivm.setInterFloorPath(twoFloorSegments());
      ivm.advanceToNextSegment();

      ivm.clearIndoorPath();

      expect(ivm.indoorPath, isNull);
      expect(ivm.isInterFloorRoute, isFalse);
      expect(ivm.currentSegmentIndex, 0);
      expect(ivm.totalSegments, 0);
    });

    test("does not notify when already clear", () {
      int notifyCount = 0;
      ivm.addListener(() => notifyCount++);

      ivm.clearIndoorPath();
      expect(notifyCount, 0);
    });
  });

  // =========================================================================
  // resetFloorplanLoadState with inter-floor state
  // =========================================================================

  group("resetFloorplanLoadState with inter-floor state", () {
    setUp(() {
      ivm.loadedFloorplans = {
        1: Floorplan(buildingId: "T", floorNumber: 1, svgPath: "f1.svg", rooms: [], pois: []),
        2: Floorplan(buildingId: "T", floorNumber: 2, svgPath: "f2.svg", rooms: [], pois: []),
      };
      ivm.selectedFloorplan = ivm.loadedFloorplans![1];
    });

    test("clears inter-floor route state", () {
      ivm.setInterFloorPath(twoFloorSegments());
      ivm.advanceToNextSegment();

      ivm.resetFloorplanLoadState();

      expect(ivm.indoorPath, isNull);
      expect(ivm.isInterFloorRoute, isFalse);
      expect(ivm.currentSegmentIndex, 0);
      expect(ivm.loadFailed, isFalse);
      expect(ivm.isLoading, isFalse);
    });
  });

  // =========================================================================
  // setIndoorPath clears inter-floor state
  // =========================================================================

  group("setIndoorPath clears inter-floor state", () {
    setUp(() {
      ivm.loadedFloorplans = {
        1: Floorplan(buildingId: "T", floorNumber: 1, svgPath: "f1.svg", rooms: [], pois: []),
        2: Floorplan(buildingId: "T", floorNumber: 2, svgPath: "f2.svg", rooms: [], pois: []),
      };
      ivm.selectedFloorplan = ivm.loadedFloorplans![1];
    });

    test("clears any active inter-floor route", () {
      ivm.setInterFloorPath(twoFloorSegments());
      expect(ivm.isInterFloorRoute, isTrue);

      ivm.setIndoorPath([const Point(0, 0), const Point(100, 100)]);

      expect(ivm.isInterFloorRoute, isFalse);
      expect(ivm.currentSegmentIndex, 0);
      expect(ivm.indoorPath, isNotNull);
    });
  });
}
