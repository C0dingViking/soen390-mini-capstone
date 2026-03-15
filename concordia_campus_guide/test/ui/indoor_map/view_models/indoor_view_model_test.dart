import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/ui/indoor_map/view_models/indoor_view_model.dart";
import "package:flutter_test/flutter_test.dart";
import "package:logger/logger.dart";

class _FakeFloorplanInteractor extends FloorplanInteractor {
  bool returnEmpty = false;
  int executionCount = 0;

  @override
  Future<Map<String, Floorplan>> loadFloorplans(final String buildingId) async {
    executionCount += 1;

    return (returnEmpty)
        ? {}
        : {
            "1": Floorplan(
              buildingId: "T",
              floorNumber: "1",
              svgPath: "test.svg",
              rooms: [],
              pois: [],
            ),
          };
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
      expect(ivm.availableFloors!.first, "1");
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
        "1": Floorplan(
          buildingId: "T",
          floorNumber: "1",
          svgPath: "floor1.svg",
          rooms: [],
          pois: [],
        ),
        "2": Floorplan(
          buildingId: "T",
          floorNumber: "2",
          svgPath: "floor2.svg",
          rooms: [],
          pois: [],
        ),
      };
      ivm.selectedFloorplan = ivm.loadedFloorplans!["1"];

      final success = ivm.changeFloor("1");
      expect(success, true);
      expect(ivm.selectedFloorplan, isNotNull);
      expect(ivm.selectedFloorplan!.floorNumber, "1");

      final success2 = ivm.changeFloor("2");
      expect(success2, true);
      expect(ivm.selectedFloorplan, isNotNull);
      expect(ivm.selectedFloorplan!.floorNumber, "2");
    });

    test("changeFloor returns false for invalid floor number", () async {
      await ivm.initializeBuildingFloorplans("T");
      final success = ivm.changeFloor("2");

      expect(success, false);
      expect(ivm.selectedFloorplan, isNotNull);
      expect(ivm.selectedFloorplan!.floorNumber, "1");
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
}
