import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:flutter/material.dart";

class IndoorViewModel extends ChangeNotifier {
  final FloorplanInteractor floorplanInteractor;
  String? loadedBuildingId;

  List<String>? loadedRoomNames;
  bool listLoadFailed = false;
  bool listIsLoading = false;

  Map<String, Floorplan>? loadedFloorplans;
  List<String>? availableFloors;
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
      final Map<String, Floorplan> floorplans = await floorplanInteractor.loadFloorplans(
        buildingId,
      );

      if (floorplans.isEmpty) {
        loadFailed = true;
      } else {
        loadedFloorplans = floorplans;
        loadedBuildingId = buildingId;
        selectedFloorplan = loadedFloorplans!.values.first;
        availableFloors = sortFloorplanKeys(
          loadedFloorplans!.keys.map((final k) => k.toUpperCase()).toList(),
        );
        loadFailed = false;
      }
    } catch (e) {
      loadFailed = true;
    }

    isLoading = false;
    notifyListeners();
  }

  // necessary to ensure "S2" comes before "1".. etc
  List<String> sortFloorplanKeys(final List<String> keys) {
    keys.sort((final a, final b) {
      final aIsSub = a.startsWith("S");
      final bIsSub = b.startsWith("S");

      if (aIsSub && !bIsSub) return -1;
      if (!aIsSub && bIsSub) return 1;

      final aNum = int.tryParse(a.replaceAll(RegExp(r"[^0-9]"), ""));
      final bNum = int.tryParse(b.replaceAll(RegExp(r"[^0-9]"), ""));

      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }

      return a.compareTo(b);
    });

    return keys;
  }

  void resetFloorplanLoadState() {
    loadFailed = false;
    isLoading = false;
    notifyListeners();
  }

  bool changeFloor(final String floorNumber) {
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
