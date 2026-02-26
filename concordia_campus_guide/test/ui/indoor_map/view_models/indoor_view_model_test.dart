import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
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
      expect(ivm.isLoading, false);
      expect(ivm.loadFailed, false);
    });

    test("resetLoadState resets load state correctly", () {
      ivm.loadFailed = true;
      ivm.isLoading = true;

      ivm.resetLoadState();
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
}
