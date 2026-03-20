import "package:concordia_campus_guide/data/repositories/floorplan_repository.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";

class FloorplanInteractor {
  final FloorplanRepository _floorplanRepo;

  FloorplanInteractor({final FloorplanRepository? floorplanRepo})
    : _floorplanRepo = floorplanRepo ?? FloorplanRepository();

  Future<Map<String, Floorplan>> loadFloorplans(final String directoryId) async {
    return _floorplanRepo.loadBuildingFloorplans(directoryId);
  }

  Future<List<String>> loadRoomNames() async {
    return _floorplanRepo.loadRoomNames();
  }
}
