import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:flutter/material.dart";

class IndoorViewModel extends ChangeNotifier {
  final FloorplanInteractor floorplanInteractor;
  String? loadedBuildingId;

  List<String>? loadedRoomNames;
  bool listLoadFailed = false;
  bool listIsLoading = false;

  Map<int, Floorplan>? loadedFloorplans;
  List<int>? availableFloors;
  Floorplan? selectedFloorplan;
  bool isLoading = false;
  bool loadFailed = false;

  IndoorViewModel({required this.floorplanInteractor});

  Future<void> initializeRoomNames() async {
    listIsLoading = true;
    notifyListeners();

    try {
      final List<String> roomNames = await floorplanInteractor.loadRoomNames();

      if (roomNames.isEmpty) {
        listLoadFailed = true;
      } else {
        loadedRoomNames = roomNames;
      }
    } catch (e) {
      listLoadFailed = true;
    }

    listIsLoading = false;
    notifyListeners();
  }

  Future<void> initializeBuildingFloorplans(final String buildingId) async {
    if (loadedBuildingId != null &&
        loadedBuildingId == buildingId &&
        loadedFloorplans != null &&
        loadedFloorplans!.isNotEmpty &&
        selectedFloorplan != null) {
      // already loaded this building's floorplans, no need to reload
      return;
    }

    isLoading = true;
    loadFailed = false;
    notifyListeners();

    try {
      final Map<int, Floorplan> floorplans = await floorplanInteractor.loadFloorplans(buildingId);

      if (floorplans.isEmpty) {
        loadFailed = true;
      } else {
        loadedFloorplans = floorplans;
        loadedBuildingId = buildingId;
        selectedFloorplan = loadedFloorplans!.values.first;
        availableFloors = loadedFloorplans!.keys.toList()..sort();
        loadFailed = false;
      }
    } catch (e) {
      loadFailed = true;
    }

    isLoading = false;
    notifyListeners();
  }

  void resetFloorplanLoadState() {
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
