import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:flutter/material.dart";

class IndoorViewModel extends ChangeNotifier {
  final FloorplanInteractor floorplanInteractor;
  String? loadedBuildingId;

  Map<int, Floorplan>? loadedFloorplans;
  List<int>? availableFloors;
  Floorplan? selectedFloorplan;
  bool isLoading = false;
  bool loadFailed = false;

  IndoorViewModel({required this.floorplanInteractor});

  Future<void> initializeBuildingFloorplans(final String buildingId) async {
    if (loadedBuildingId != null &&
        loadedBuildingId == buildingId &&
        buildingId == loadedBuildingId &&
        loadedFloorplans != null &&
        loadedFloorplans!.isNotEmpty) {
      // already loaded this building's floorplans, no need to reload
      return;
    }

    try {
      final Map<int, Floorplan> floorplans = await floorplanInteractor.loadFloorplans(buildingId);

      if (floorplans.isEmpty) {
        loadFailed = true;
      } else {
        loadedFloorplans = floorplans;
        loadedBuildingId = buildingId;
        selectedFloorplan = loadedFloorplans!.values.first;
        availableFloors = loadedFloorplans!.keys.toList()..sort();
      }
    } catch (e) {
      loadFailed = true;
    }

    isLoading = false;
    notifyListeners();
  }

  void resetLoadState() {
    loadFailed = false;
    isLoading = false;
    notifyListeners();
  }

  bool changeFloor(final int floorNumber) {
    if (loadedFloorplans == null || !loadedFloorplans!.containsKey(floorNumber)) {
      return false;
    }

    if (selectedFloorplan!.floorNumber != floorNumber) {
      selectedFloorplan = loadedFloorplans![floorNumber];
      notifyListeners();
    }
    return true;
  }
}
