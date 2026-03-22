import "dart:math";

import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/domain/models/indoor_pathfinding.dart";
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

  /// The path displayed on the currently selected floor.

  List<Point<double>>? indoorPath;

  List<IndoorFloorPathSegment>? _interFloorSegments;

  int _currentSegmentIndex = 0;

  bool isLoading = false;
  bool loadFailed = false;

  /// checks Whether the active route spans multiple floors.
  bool get isInterFloorRoute => _interFloorSegments != null && _interFloorSegments!.length > 1;

  int get totalSegments => _interFloorSegments?.length ?? 0;

  int get currentSegmentIndex => _currentSegmentIndex;

  IndoorFloorPathSegment? get currentSegment =>
      _interFloorSegments != null && _currentSegmentIndex < _interFloorSegments!.length
      ? _interFloorSegments![_currentSegmentIndex]
      : null;

  bool get hasNextSegment =>
      _interFloorSegments != null && _currentSegmentIndex < _interFloorSegments!.length - 1;

  bool get hasPreviousSegment => _interFloorSegments != null && _currentSegmentIndex > 0;

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

  /// Necessary to ensure S2 comes before 1 and other specifications
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
    indoorPath = null;
    _interFloorSegments = null;
    _currentSegmentIndex = 0;
    notifyListeners();
  }

  bool changeFloor(final String floorNumber) {
    if (loadedFloorplans == null || !loadedFloorplans!.containsKey(floorNumber)) {
      return false;
    }

    if (selectedFloorplan!.floorNumber != floorNumber) {
      selectedFloorplan = loadedFloorplans![floorNumber];

      // show segment for this floor.
      if (_interFloorSegments != null) {
        final segmentIndex = _interFloorSegments!.indexWhere(
          (final s) => s.floorNumber == floorNumber,
        );
        if (segmentIndex >= 0) {
          _currentSegmentIndex = segmentIndex;
          indoorPath = _interFloorSegments![segmentIndex].path;
        } else {
          indoorPath = null;
        }
      } else {
        indoorPath = null;
      }

      notifyListeners();
    }
    return true;
  }

  /// Single-floor path
  void setIndoorPath(final List<Point<double>> path) {
    _interFloorSegments = null;
    _currentSegmentIndex = 0;
    indoorPath = path;
    notifyListeners();
  }

  /// Multi-floor path
  void setInterFloorPath(final List<IndoorFloorPathSegment> segments) {
    if (segments.isEmpty) {
      clearIndoorPath();
      return;
    }

    _interFloorSegments = segments;
    _currentSegmentIndex = 0;

    final firstSegment = segments.first;
    if (loadedFloorplans != null && loadedFloorplans!.containsKey(firstSegment.floorNumber)) {
      selectedFloorplan = loadedFloorplans![firstSegment.floorNumber];
    }
    indoorPath = firstSegment.path;

    notifyListeners();
  }

  bool advanceToNextSegment() {
    if (!hasNextSegment) {
      return false;
    }

    _currentSegmentIndex++;
    final segment = _interFloorSegments![_currentSegmentIndex];

    if (loadedFloorplans != null && loadedFloorplans!.containsKey(segment.floorNumber)) {
      selectedFloorplan = loadedFloorplans![segment.floorNumber];
    }
    indoorPath = segment.path;

    notifyListeners();
    return true;
  }

  // Goes back to the previous floor segment and switches displayed floor
  bool goToPreviousSegment() {
    if (!hasPreviousSegment) {
      return false;
    }

    _currentSegmentIndex--;
    final segment = _interFloorSegments![_currentSegmentIndex];

    if (loadedFloorplans != null && loadedFloorplans!.containsKey(segment.floorNumber)) {
      selectedFloorplan = loadedFloorplans![segment.floorNumber];
    }
    indoorPath = segment.path;

    notifyListeners();
    return true;
  }

  void clearIndoorPath() {
    if (indoorPath == null && _interFloorSegments == null) {
      return;
    }
    indoorPath = null;
    _interFloorSegments = null;
    _currentSegmentIndex = 0;
    notifyListeners();
  }
}
