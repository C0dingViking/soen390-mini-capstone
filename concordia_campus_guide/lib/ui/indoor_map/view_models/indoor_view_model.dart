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

  Map<int, Floorplan>? loadedFloorplans;
  List<int>? availableFloors;
  Floorplan? selectedFloorplan;

  /// The path displayed on the currently selected floor.
  /// For same-floor routes this is the full path.
  /// For inter-floor routes this is the segment for [selectedFloorplan].
  List<Point<double>>? indoorPath;

  /// All segments of a multi-floor route, keyed by floor number.
  /// Null when there is no active inter-floor route.
  List<IndoorFloorPathSegment>? _interFloorSegments;

  /// The index into [_interFloorSegments] currently being viewed.
  int _currentSegmentIndex = 0;

  bool isLoading = false;
  bool loadFailed = false;

  /// Whether the active route spans multiple floors.
  bool get isInterFloorRoute =>
      _interFloorSegments != null && _interFloorSegments!.length > 1;

  /// The total number of floor segments in the current route.
  int get totalSegments => _interFloorSegments?.length ?? 0;

  /// The 0-based index of the segment currently displayed.
  int get currentSegmentIndex => _currentSegmentIndex;

  /// The current segment object, or null if no inter-floor route is active.
  IndoorFloorPathSegment? get currentSegment =>
      _interFloorSegments != null && _currentSegmentIndex < _interFloorSegments!.length
          ? _interFloorSegments![_currentSegmentIndex]
          : null;

  /// Whether there is a next segment the user can advance to.
  bool get hasNextSegment =>
      _interFloorSegments != null &&
      _currentSegmentIndex < _interFloorSegments!.length - 1;

  /// Whether there is a previous segment the user can go back to.
  bool get hasPreviousSegment =>
      _interFloorSegments != null && _currentSegmentIndex > 0;

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
    indoorPath = null;
    _interFloorSegments = null;
    _currentSegmentIndex = 0;
    notifyListeners();
  }

  bool changeFloor(final int floorNumber) {
    if (loadedFloorplans == null || !loadedFloorplans!.containsKey(floorNumber)) {
      return false;
    }

    if (selectedFloorplan!.floorNumber != floorNumber) {
      selectedFloorplan = loadedFloorplans![floorNumber];

      // If an inter-floor route is active, show the segment for this floor.
      if (_interFloorSegments != null) {
        final segmentIndex = _interFloorSegments!
            .indexWhere((final s) => s.floorNumber == floorNumber);
        if (segmentIndex >= 0) {
          _currentSegmentIndex = segmentIndex;
          indoorPath = _interFloorSegments![segmentIndex].path;
        } else {
          // This floor has no segment in the route; clear the path overlay.
          indoorPath = null;
        }
      } else {
        indoorPath = null;
      }

      notifyListeners();
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // Single-floor path (backwards-compatible)
  // -------------------------------------------------------------------------

  void setIndoorPath(final List<Point<double>> path) {
    _interFloorSegments = null;
    _currentSegmentIndex = 0;
    indoorPath = path;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Multi-floor path
  // -------------------------------------------------------------------------

  /// Sets the full inter-floor route and switches to the first segment's floor.
  void setInterFloorPath(final List<IndoorFloorPathSegment> segments) {
    if (segments.isEmpty) {
      clearIndoorPath();
      return;
    }

    _interFloorSegments = segments;
    _currentSegmentIndex = 0;

    final firstSegment = segments.first;
    if (loadedFloorplans != null &&
        loadedFloorplans!.containsKey(firstSegment.floorNumber)) {
      selectedFloorplan = loadedFloorplans![firstSegment.floorNumber];
    }
    indoorPath = firstSegment.path;

    notifyListeners();
  }

  /// Advances to the next floor segment and switches the displayed floor.
  bool advanceToNextSegment() {
    if (!hasNextSegment) {
      return false;
    }

    _currentSegmentIndex++;
    final segment = _interFloorSegments![_currentSegmentIndex];

    if (loadedFloorplans != null &&
        loadedFloorplans!.containsKey(segment.floorNumber)) {
      selectedFloorplan = loadedFloorplans![segment.floorNumber];
    }
    indoorPath = segment.path;

    notifyListeners();
    return true;
  }

  /// Goes back to the previous floor segment and switches the displayed floor.
  bool goToPreviousSegment() {
    if (!hasPreviousSegment) {
      return false;
    }

    _currentSegmentIndex--;
    final segment = _interFloorSegments![_currentSegmentIndex];

    if (loadedFloorplans != null &&
        loadedFloorplans!.containsKey(segment.floorNumber)) {
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
