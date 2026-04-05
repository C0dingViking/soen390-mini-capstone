import "dart:math";

import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/domain/models/indoor_pathfinding.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/indoor_map/view_models/indoor_view_model.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_path_painter.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_search_bar.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_highlight_painter.dart";
import "package:concordia_campus_guide/utils/dialog_helper.dart";
import "package:flutter/material.dart";
import "package:flutter_svg/svg.dart";
import "package:provider/provider.dart";

const bool _showDebugNavigation = false;

@visibleForTesting
String? resolveRoomNameFromTapPosition(
  final Offset scenePoint,
  final Size viewportSize,
  final Floorplan floorplan,
) {
  return _IndoorMapViewState.roomNameFromTapPosition(scenePoint, viewportSize, floorplan);
}

class IndoorMapView extends StatefulWidget {
  final Building building;
  final String? initialStartRoomLabel;
  final String? initialDestinationRoomLabel;
  final String? interBuildingDestinationBuildingId;
  final String? interBuildingDestinationEntryLabel;
  final String? interBuildingDestinationRoomLabel;
  final FloorplanInteractor? floorplanInteractor;

  const IndoorMapView({
    super.key,
    required this.building,
    this.initialStartRoomLabel,
    this.initialDestinationRoomLabel,
    this.interBuildingDestinationBuildingId,
    this.interBuildingDestinationEntryLabel,
    this.interBuildingDestinationRoomLabel,
    this.floorplanInteractor,
  });

  @override
  State<IndoorMapView> createState() => _IndoorMapViewState();
}

class _InterBuildingNavigationPlan {
  final String startBuildingId;
  final String destinationBuildingId;
  final String originStartLabel;
  final String startExitLabel;
  final String destinationEntryLabel;
  final String destinationRoomLabel;

  const _InterBuildingNavigationPlan({
    required this.startBuildingId,
    required this.destinationBuildingId,
    required this.originStartLabel,
    required this.startExitLabel,
    required this.destinationEntryLabel,
    required this.destinationRoomLabel,
  });
}

class _IndoorMapViewState extends State<IndoorMapView> {
  static const String _navigationErrorTitle = "Navigation Error";
  final TransformationController _controller = TransformationController();
  late final FloorplanInteractor _floorplanInteractor;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  final FocusNode _startFocusNode = FocusNode();
  bool _didApplyOutdoorHandoffDefaults = false;
  _InterBuildingNavigationPlan? _pendingInterBuildingPlan;
  bool _autoStartTriggered = false;
  final minMapZoom = 1.0;
  final maxMapZoom = 4.0;
  final floorPickerSpacing = 16.0;
  final searchBarSpacingTop = 8.0;
  final searchBarSpacingLeft = 64.0;
  final searchBarSpacingRight = 16.0;

  late IndoorViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _floorplanInteractor = widget.floorplanInteractor ?? FloorplanInteractor();

    final initialStart = widget.initialStartRoomLabel?.trim();
    if (initialStart != null && initialStart.isNotEmpty) {
      _startController.text = initialStart;
      _startController.selection = TextSelection.collapsed(offset: initialStart.length);
    }

    final initialDestination = widget.initialDestinationRoomLabel?.trim();
    if (initialDestination != null && initialDestination.isNotEmpty) {
      _destinationController.text = initialDestination;
      _destinationController.selection = TextSelection.collapsed(offset: initialDestination.length);
    }

    final destinationBuildingId = widget.interBuildingDestinationBuildingId?.trim();
    final destinationEntryLabel = widget.interBuildingDestinationEntryLabel?.trim();
    final destinationRoomLabel = widget.interBuildingDestinationRoomLabel?.trim();
    if (destinationBuildingId != null &&
        destinationBuildingId.isNotEmpty &&
        destinationEntryLabel != null &&
        destinationEntryLabel.isNotEmpty &&
        destinationRoomLabel != null &&
        destinationRoomLabel.isNotEmpty &&
        initialStart != null &&
        initialStart.isNotEmpty &&
        initialDestination != null &&
        initialDestination.isNotEmpty) {
      _pendingInterBuildingPlan = _InterBuildingNavigationPlan(
        startBuildingId: widget.building.id,
        destinationBuildingId: destinationBuildingId,
        originStartLabel: initialStart,
        startExitLabel: initialDestination,
        destinationEntryLabel: destinationEntryLabel,
        destinationRoomLabel: destinationRoomLabel,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<IndoorViewModel>().initializeRoomNames();
      context.read<IndoorViewModel>().initializeBuildingFloorplans(widget.building.id);
    });
    _destinationFocusNode.addListener(_onDestinationFocusChanged);
    _destinationController.addListener(_onDestinationTextChanged);
    _startController.addListener(_onStartTextChanged);
    _startFocusNode.addListener(_onStartFocusChanged);
  }

  void _onDestinationTextChanged() {
    if (_destinationController.text.isEmpty) {
      _viewModel.clearSelectedEndRoom();
    }
  }

  void _onStartTextChanged() {
    if (_startController.text.isEmpty) {
      _viewModel.clearSelectedStartRoom();
    }
  }

  void _onStartFocusChanged() {
    if (!_startFocusNode.hasFocus) {
      _validateAndSetRoom(
        _startController.text,
        _viewModel.selectStartRoom,
        _viewModel.clearSelectedStartRoom,
      );
    }
  }

  void _onDestinationFocusChanged() {
    if (!_destinationFocusNode.hasFocus) {
      _validateAndSetRoom(
        _destinationController.text,
        _viewModel.selectEndRoom,
        _viewModel.clearSelectedEndRoom,
      );
    }
  }

  void _validateAndSetRoom(
    final String input,
    final void Function(String) onValid,
    final void Function() onInvalid,
  ) {
    final text = input.trim();
    if (text.isEmpty) {
      onInvalid();
      return;
    }

    if (_viewModel.loadedRoomNames?.contains(text) ?? false) {
      final parts = text.split(RegExp(r"\s+"));
      if (parts.length < 2) {
        onInvalid();
        return;
      }

      final roomNumber = text.substring(parts[0].length).trim();
      onValid(roomNumber);
    } else {
      onInvalid();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel = Provider.of<IndoorViewModel>(context, listen: false);
    _viewModel.addListener(_onViewModelChange);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    _destinationFocusNode.removeListener(_onDestinationFocusChanged);
    _destinationController.removeListener(_onDestinationTextChanged);
    _startController.removeListener(_onStartTextChanged);
    _startFocusNode.removeListener(_onStartFocusChanged);
    _startController.dispose();
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    _startFocusNode.dispose();
    super.dispose();
  }

  void _onViewModelChange() {
    if (!mounted) return;

    final loadedFloorplans = _viewModel.loadedFloorplans;
    final isReady =
        !_viewModel.isLoading &&
        loadedFloorplans != null &&
        loadedFloorplans.isNotEmpty &&
        !_autoStartTriggered;

    if (!isReady) {
      return;
    }

    final startText = _startController.text.trim();
    final destinationText = _destinationController.text.trim();

    if (startText.isEmpty || destinationText.isEmpty) {
      return;
    }

    setState(() {
      _autoStartTriggered = true;
    });

    _handleStartNavigation(startText, destinationText, false);
  }

  ({String buildingId, String roomName}) _parseRoomLabel(final String roomLabel) {
    final trimmedLabel = roomLabel.trim();

    final parts = trimmedLabel.split(RegExp(r"\s+"));

    final buildingId = parts.first.toUpperCase();
    final roomName = trimmedLabel.substring(parts.first.length).trim();

    return (buildingId: buildingId, roomName: roomName);
  }

  String _normalizeLocationToken(final String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), "");
  }

  String? _transitionToken(final FloorTransition transition) {
    final separatorIndex = transition.id.indexOf("-");
    if (separatorIndex < 0 || separatorIndex >= transition.id.length - 1) {
      return null;
    }
    return transition.id.substring(separatorIndex + 1);
  }

  bool _locationMatchesToken(final String locationName, final String normalizedLocationToken) {
    final candidate = _normalizeLocationToken(locationName);
    if (candidate == normalizedLocationToken) {
      return true;
    }

    return candidate.contains(normalizedLocationToken) ||
        normalizedLocationToken.contains(candidate);
  }

  String _findFloorForLocationName(
    final String locationName,
    final Map<String, Floorplan> floorplans,
  ) {
    final normalizedLocationToken = _normalizeLocationToken(locationName);

    for (final floorplanEntry in floorplans.entries) {
      final floorplan = floorplanEntry.value;
      final hasRoom = floorplan.rooms.any(
        (final room) => _locationMatchesToken(room.name, normalizedLocationToken),
      );
      if (hasRoom) {
        return floorplanEntry.key;
      }

      final hasPoi = floorplan.pois.any(
        (final poi) => _locationMatchesToken(poi.name, normalizedLocationToken),
      );
      if (hasPoi) {
        return floorplanEntry.key;
      }

      final hasTransition = floorplan.transitions.any((final transition) {
        final transitionToken = _transitionToken(transition);
        if (transitionToken == null) return false;
        return _locationMatchesToken(transitionToken, normalizedLocationToken);
      });
      if (hasTransition) {
        return floorplanEntry.key;
      }
    }

    throw Exception("Floor not found for location: $locationName");
  }

  IndoorMapRoom? _findRoomOnFloor(final String roomName, final Floorplan floorplan) {
    final normalizedName = roomName.trim().toLowerCase();

    String sanitize(final String value) {
      return value
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r"\s+"), "")
          .replaceAll(RegExp(r"[-.]"), "");
    }

    final sanitizedName = sanitize(normalizedName);

    for (final room in floorplan.rooms) {
      final candidate = room.name.trim().toLowerCase();
      if (candidate == normalizedName || sanitize(candidate) == sanitizedName) {
        return room;
      }
    }
    return null;
  }

  PointOfInterest? _findPoiOnFloor(final String locationName, final Floorplan floorplan) {
    final normalizedLocationToken = _normalizeLocationToken(locationName);
    for (final poi in floorplan.pois) {
      if (_locationMatchesToken(poi.name, normalizedLocationToken)) {
        return poi;
      }
    }
    return null;
  }

  FloorTransition? _findTransitionOnFloor(final String locationName, final Floorplan floorplan) {
    final normalizedLocationToken = _normalizeLocationToken(locationName);

    for (final transition in floorplan.transitions) {
      final transitionToken = _transitionToken(transition);
      if (transitionToken == null) {
        continue;
      }

      if (_locationMatchesToken(transitionToken, normalizedLocationToken)) {
        return transition;
      }
    }

    return null;
  }

  IndoorMapRoom? _resolveLocationOnFloor(final String locationName, final Floorplan floorplan) {
    final room = _findRoomOnFloor(locationName, floorplan);
    if (room != null) {
      return room;
    }

    final poi = _findPoiOnFloor(locationName, floorplan);
    if (poi != null) {
      return IndoorMapRoom(name: poi.name, doorLocation: poi.location, points: const []);
    }

    final transition = _findTransitionOnFloor(locationName, floorplan);
    if (transition != null) {
      final transitionName = _transitionToken(transition) ?? transition.id;
      return IndoorMapRoom(
        name: transitionName,
        doorLocation: transition.location,
        points: const [],
      );
    }

    return null;
  }

  Future<void> _handleStartNavigation(
    final String startRoom,
    final String destinationRoom,
    final bool accessibleMode,
  ) async {
    final parsedStartRoom = _parseRoomLabel(startRoom);
    final parsedDestinationRoom = _parseRoomLabel(destinationRoom);

    final floorplans = await _ensureFloorplansLoadedForBuilding(parsedStartRoom.buildingId);
    if (floorplans == null || floorplans.isEmpty) {
      return;
    }

    if (!_isSameBuilding(parsedStartRoom.buildingId, parsedDestinationRoom.buildingId)) {
      await _handleInterBuildingNavigation(
        parsedStartRoom,
        parsedDestinationRoom,
        floorplans,
        accessibleMode,
      );
      return;
    }

    final startFloor = _findFloorForLocationName(parsedStartRoom.roomName, floorplans);
    final destinationFloor = _findFloorForLocationName(parsedDestinationRoom.roomName, floorplans);

    // Switch to the current location's floor immediately
    _viewModel.changeFloor(startFloor);

    if (startFloor == destinationFloor) {
      await _handleSameFloorNavigation(parsedStartRoom, parsedDestinationRoom, startFloor);
    } else {
      await _handleInterFloorNavigation(
        parsedStartRoom,
        parsedDestinationRoom,
        startFloor,
        destinationFloor,
        floorplans,
        accessibleMode,
      );
    }
  }

  void _handleEndNavigation() {
    _viewModel.clearIndoorPath();
  }

  Future<Map<String, Floorplan>?> _ensureFloorplansLoadedForBuilding(
    final String targetBuildingId,
  ) async {
    final targetIdLower = targetBuildingId.toLowerCase();
    final currentBuildingId = (_viewModel.loadedBuildingId ?? widget.building.id).toLowerCase();
    if (targetIdLower != currentBuildingId) {
      await _viewModel.initializeBuildingFloorplans(targetIdLower);
      if (!mounted) {
        return null;
      }
    }

    final floorplans = _viewModel.loadedFloorplans;
    if (floorplans == null || floorplans.isEmpty) {
      await showErrorPopup(
        context,
        "No floor plans available for current location.",
        title: _navigationErrorTitle,
      );
      return null;
    }

    return floorplans;
  }

  bool _isSameBuilding(final String startBuildingId, final String destinationBuildingId) {
    return startBuildingId.trim().toLowerCase() == destinationBuildingId.trim().toLowerCase();
  }

  Future<void> _handleInterBuildingNavigation(
    final ({String buildingId, String roomName}) parsedStartRoom,
    final ({String buildingId, String roomName}) parsedDestinationRoom,
    final Map<String, Floorplan> startBuildingFloorplans,
    final bool accessibleMode,
  ) async {
    final startFloor = _findFloorForLocationName(parsedStartRoom.roomName, startBuildingFloorplans);
    final startExitLabel = _deriveBuildingHandoffLabel(
      startBuildingFloorplans,
      preferredFloor: startFloor,
      accessibleMode: accessibleMode,
    );

    if (startExitLabel == null) {
      if (!mounted) return;
      await showErrorPopup(
        context,
        "No valid exit point found in the starting building.",
        title: _navigationErrorTitle,
      );
      return;
    }

    final parsedExit = _parseRoomLabel(startExitLabel);
    final exitFloor = _findFloorForLocationName(parsedExit.roomName, startBuildingFloorplans);

    _viewModel.changeFloor(startFloor);
    if (startFloor == exitFloor) {
      await _handleSameFloorNavigation(parsedStartRoom, parsedExit, startFloor);
    } else {
      await _handleInterFloorNavigation(
        parsedStartRoom,
        parsedExit,
        startFloor,
        exitFloor,
        startBuildingFloorplans,
        accessibleMode,
      );
    }

    if (!mounted) {
      return;
    }

    final destinationFloorplans = await _floorplanInteractor.loadFloorplans(
      parsedDestinationRoom.buildingId.toLowerCase(),
    );
    if (!mounted) {
      return;
    }

    if (destinationFloorplans.isEmpty) {
      if (!mounted) return;
      await showErrorPopup(
        context,
        "No floor plans available for the destination building.",
        title: _navigationErrorTitle,
      );
      return;
    }

    final destinationEntryLabel = _deriveBuildingHandoffLabel(
      destinationFloorplans,
      accessibleMode: accessibleMode,
    );
    if (destinationEntryLabel == null) {
      if (!mounted) return;
      await showErrorPopup(
        context,
        "No valid entry point found in the destination building.",
        title: _navigationErrorTitle,
      );
      return;
    }

    final destinationRoomLabel =
        "${parsedDestinationRoom.buildingId.toUpperCase()} ${parsedDestinationRoom.roomName}";
    setState(() {
      _pendingInterBuildingPlan = _InterBuildingNavigationPlan(
        startBuildingId: parsedStartRoom.buildingId,
        destinationBuildingId: parsedDestinationRoom.buildingId,
        originStartLabel: "${parsedStartRoom.buildingId.toUpperCase()} ${parsedStartRoom.roomName}",
        startExitLabel: startExitLabel,
        destinationEntryLabel: destinationEntryLabel,
        destinationRoomLabel: destinationRoomLabel,
      );
    });
  }

  String? _deriveBuildingHandoffLabel(
    final Map<String, Floorplan> floorplans, {
    final String? preferredFloor,
    final bool accessibleMode = false,
  }) {
    if (floorplans.isEmpty) {
      return null;
    }

    final floors = _viewModel.sortFloorplanKeys(
      floorplans.keys.map((final floor) => floor.toUpperCase()).toList(),
    );
    final orderedFloors = <String>[];
    if (preferredFloor != null && floorplans.containsKey(preferredFloor)) {
      orderedFloors.add(preferredFloor);
    }
    for (final floor in floors) {
      if (!orderedFloors.contains(floor)) {
        orderedFloors.add(floor);
      }
    }

    for (final floor in orderedFloors) {
      final floorplan = floorplans[floor];
      if (floorplan == null) continue;

      final entrances =
          floorplan.pois
              .where((final poi) => poi.type == PoiType.buildingEntrance)
              .map((final poi) => poi.name)
              .toList()
            ..sort();
      if (entrances.isNotEmpty) {
        return "${floorplan.buildingId.toUpperCase()} ${entrances.first}";
      }
    }

    final lowestFloor = floors.first;
    final lowestFloorplan = floorplans[lowestFloor];
    if (lowestFloorplan == null) {
      return null;
    }

    final elevators =
        lowestFloorplan.pois
            .where((final poi) => poi.type == PoiType.elevator)
            .map((final poi) => poi.name)
            .toList()
          ..sort();
    final stairs =
        lowestFloorplan.pois
            .where(
              (final poi) =>
                  poi.type == PoiType.stairs ||
                  poi.type == PoiType.stairsUp ||
                  poi.type == PoiType.stairsDown,
            )
            .map((final poi) => poi.name)
            .toList()
          ..sort();

    final fallbackCandidates = [...elevators, ...stairs];
    if (fallbackCandidates.isNotEmpty) {
      return "${lowestFloorplan.buildingId.toUpperCase()} ${fallbackCandidates.first}";
    }

    final transitionNames = lowestFloorplan.transitions.map(_transitionToken).whereType<String>();
    final sortedTransitions = transitionNames.toList()..sort();
    if (sortedTransitions.isNotEmpty) {
      return "${lowestFloorplan.buildingId.toUpperCase()} ${sortedTransitions.first}";
    }

    return null;
  }

  Future<void> _continueWithOutdoorNavigation() async {
    final plan = _pendingInterBuildingPlan;
    if (plan == null) {
      return;
    }

    final homeViewModel = context.read<HomeViewModel>();
    final didStart = await homeViewModel.startInterBuildingOutdoorNavigation(
      startBuildingId: plan.startBuildingId,
      destinationBuildingId: plan.destinationBuildingId,
      startRoomLabel: plan.startBuildingId.toUpperCase(),
      destinationRoomLabel: plan.destinationRoomLabel,
      destinationIndoorStartLabel: plan.destinationEntryLabel,
      originIndoorStartRoomLabel: plan.originStartLabel,
      originIndoorDestinationRoomLabel: plan.startExitLabel,
    );

    if (!didStart || !mounted) {
      return;
    }

    // End the current building's indoor leg before handing off to outdoor routing.
    _viewModel.clearIndoorPath();

    Navigator.of(context).popUntil((final route) => route.isFirst);
  }

  Future<void> _handleSameFloorNavigation(
    final ({String buildingId, String roomName}) parsedStartRoom,
    final ({String buildingId, String roomName}) parsedDestinationRoom,
    final String startFloor,
  ) async {
    final changedFloor = _viewModel.changeFloor(startFloor);
    if (!changedFloor) {
      if (!mounted) return;
      await showErrorPopup(
        context,
        "Failed to change floor. Please try again.",
        title: _navigationErrorTitle,
      );
      return;
    }

    final floorplan = _viewModel.selectedFloorplan;
    if (floorplan == null) {
      return;
    }

    final startRoomModel = _resolveLocationOnFloor(parsedStartRoom.roomName, floorplan);
    final destinationRoomModel = _resolveLocationOnFloor(parsedDestinationRoom.roomName, floorplan);

    if (startRoomModel == null || destinationRoomModel == null) {
      if (!mounted) return;
      await showErrorPopup(
        context,
        "Unable to locate one or both locations on this floor.",
        title: _navigationErrorTitle,
      );
      return;
    }

    try {
      await _computeAndSetIndoorPath(
        floorplan: floorplan,
        startRoomModel: startRoomModel,
        destinationRoomModel: destinationRoomModel,
      );
    } on StateError catch (_) {
      _viewModel.clearIndoorPath();
      if (!mounted) return;
      await showErrorPopup(
        context,
        "No indoor route found between the selected rooms.",
        title: _navigationErrorTitle,
      );
    } catch (_) {
      _viewModel.clearIndoorPath();
      if (!mounted) return;
      await showErrorPopup(
        context,
        "Failed to compute indoor route. Please try again.",
        title: _navigationErrorTitle,
      );
    }
  }

  Future<void> _computeAndSetIndoorPath({
    required final Floorplan floorplan,
    required final IndoorMapRoom startRoomModel,
    required final IndoorMapRoom destinationRoomModel,
  }) async {
    if (_showDebugNavigation) {
      final result = floorplan.shortestPathBetweenRoomsWithDebug(
        startRoomModel,
        destinationRoomModel,
      );
      _viewModel.setIndoorPath(result.path, traversedNodes: result.traversedNodes);
    } else {
      final path = floorplan.shortestPathBetweenRooms(startRoomModel, destinationRoomModel);
      _viewModel.setIndoorPath(path);
    }
  }

  Future<void> _handleInterFloorNavigation(
    final ({String buildingId, String roomName}) parsedStartRoom,
    final ({String buildingId, String roomName}) parsedDestinationRoom,
    final String startFloor,
    final String destinationFloor,
    final Map<String, Floorplan> floorplans,
    final bool accessibleMode,
  ) async {
    final startFloorplan = floorplans[startFloor];
    final destFloorplan = floorplans[destinationFloor];
    if (startFloorplan == null || destFloorplan == null) {
      if (!mounted) return;
      await showErrorPopup(
        context,
        "Floor plan data is missing for one of the floors.",
        title: _navigationErrorTitle,
      );
      return;
    }

    final startRoomModel = _resolveLocationOnFloor(parsedStartRoom.roomName, startFloorplan);
    final destinationRoomModel = _resolveLocationOnFloor(
      parsedDestinationRoom.roomName,
      destFloorplan,
    );

    if (startRoomModel == null || destinationRoomModel == null) {
      if (!mounted) return;
      await showErrorPopup(
        context,
        "Unable to locate one or both locations.",
        title: _navigationErrorTitle,
      );
      return;
    }

    try {
      final segments = computeInterFloorPath(
        floorplans: floorplans,
        startFloor: startFloor,
        destinationFloor: destinationFloor,
        startRoom: startRoomModel,
        destinationRoom: destinationRoomModel,
        accessibleMode: accessibleMode,
      );
      _viewModel.setInterFloorPath(segments);
    } on StateError catch (e) {
      _viewModel.clearIndoorPath();
      if (!mounted) return;
      await showErrorPopup(context, e.message, title: _navigationErrorTitle);
    } catch (_) {
      _viewModel.clearIndoorPath();
      if (!mounted) return;
      await showErrorPopup(
        context,
        "Failed to compute inter-floor route. Please try again.",
        title: _navigationErrorTitle,
      );
    }
  }

  static Rect _roomBounds(final IndoorMapRoom room) {
    if (room.points.isEmpty) {
      return Rect.zero;
    }

    var minX = room.points.first.x;
    var minY = room.points.first.y;
    var maxX = room.points.first.x;
    var maxY = room.points.first.y;

    for (final point in room.points.skip(1)) {
      if (point.x < minX) minX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.x > maxX) maxX = point.x;
      if (point.y > maxY) maxY = point.y;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static bool _containsPoint(final IndoorMapRoom room, final Offset point) {
    if (room.points.length < 3) {
      return false;
    }

    final path = Path()..moveTo(room.points.first.x, room.points.first.y);
    for (final roomPoint in room.points.skip(1)) {
      path.lineTo(roomPoint.x, roomPoint.y);
    }
    path.close();

    return path.contains(point);
  }

  static String? roomNameFromTapPosition(
    final Offset scenePoint,
    final Size viewportSize,
    final Floorplan floorplan,
  ) {
    final svgPoint = _scenePointToSvgPoint(scenePoint, viewportSize, floorplan);
    if (svgPoint == null) {
      return null;
    }

    for (final room in floorplan.rooms) {
      final bounds = _roomBounds(room);
      if (!bounds.contains(svgPoint)) {
        continue;
      }

      if (_containsPoint(room, svgPoint)) {
        return room.name;
      }
    }

    return null;
  }

  void _handleTapOnMap(
    final TapUpDetails details,
    final Size viewportSize,
    final Floorplan floorplan,
  ) {
    final scenePoint = _controller.toScene(details.localPosition);
    final roomName = roomNameFromTapPosition(scenePoint, viewportSize, floorplan);

    if (roomName == null) {
      return;
    }

    final destinationLabel = "${floorplan.buildingId.toUpperCase()} $roomName";
    _destinationController.text = destinationLabel;
    _destinationController.selection = TextSelection.collapsed(offset: destinationLabel.length);
    _destinationFocusNode.requestFocus();
    _viewModel.selectEndRoom(roomName);
  }

  static Offset? _scenePointToSvgPoint(
    final Offset scenePoint,
    final Size viewportSize,
    final Floorplan floorplan,
  ) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) {
      return null;
    }

    if (floorplan.canvasWidth <= 0 || floorplan.canvasHeight <= 0) {
      return null;
    }

    final inputSize = Size(floorplan.canvasWidth, floorplan.canvasHeight);
    final fittedSizes = applyBoxFit(BoxFit.contain, inputSize, viewportSize);
    final destinationRect = Alignment.center.inscribe(
      fittedSizes.destination,
      Offset.zero & viewportSize,
    );

    if (!destinationRect.contains(scenePoint)) {
      return null;
    }

    final normalizedX = (scenePoint.dx - destinationRect.left) / destinationRect.width;
    final normalizedY = (scenePoint.dy - destinationRect.top) / destinationRect.height;

    return Offset(normalizedX * floorplan.canvasWidth, normalizedY * floorplan.canvasHeight);
  }

  String _getTransitionLabelFromTransitionType(final FloorTransition transition) {
    switch (transition.type) {
      case TransitionType.elevator:
        return "Elevator";
      case TransitionType.escalator:
        return "Escalator";
      case TransitionType.stairs:
        return "Stairs";
    }
  }

  Widget _buildSegmentNavigationBar(final IndoorViewModel ivm) {
    final segment = ivm.currentSegment;
    if (segment == null) {
      return const SizedBox.shrink();
    }

    String description;
    if (segment.entryTransition != null && segment.exitTransition != null) {
      description =
          "Floor ${segment.floorNumber}: "
          "${_getTransitionLabelFromTransitionType(segment.entryTransition!)} → "
          "${_getTransitionLabelFromTransitionType(segment.exitTransition!)}";
    } else if (segment.exitTransition != null) {
      description =
          "Floor ${segment.floorNumber}: "
          "Start → ${_getTransitionLabelFromTransitionType(segment.exitTransition!)}";
    } else if (segment.entryTransition != null) {
      description =
          "Floor ${segment.floorNumber}: "
          "${_getTransitionLabelFromTransitionType(segment.entryTransition!)} → Destination";
    } else {
      description = "Floor ${segment.floorNumber}";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(200, 8, 187, 241),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Previous button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: ivm.hasPreviousSegment ? () => ivm.goToPreviousSegment() : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Previous floor",
            color: Colors.white,
          ),
          const SizedBox(width: 8),

          // Segment info
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Step ${ivm.currentSegmentIndex + 1} of ${ivm.totalSegments}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Next button
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: ivm.hasNextSegment ? () => ivm.advanceToNextSegment() : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Next floor",
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildInterBuildingHandoffBar(final _InterBuildingNavigationPlan plan) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.concordiaButtonCyan.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Continue outdoors to ${plan.destinationBuildingId.toUpperCase()}.",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            key: const Key("continue_outdoor_navigation_button"),
            onPressed: _continueWithOutdoorNavigation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.concordiaForeground,
            ),
            icon: const Icon(Icons.directions_walk),
            label: const Text("Continue Outdoors"),
          ),
        ],
      ),
    );
  }

  List<String> _queryableLocations(final IndoorViewModel ivm) {
    final labels = <String>{};

    labels.addAll(_locationLabelsFromRoomNames(ivm));
    labels.addAll(_locationLabelsFromLoadedFloorplans(ivm));

    final sorted = labels.toList()..sort();
    return sorted;
  }

  List<String> _locationLabelsFromRoomNames(final IndoorViewModel ivm) {
    return (ivm.loadedRoomNames ?? const <String>[])
        .map((final roomLabel) => roomLabel.trim())
        .where((final roomLabel) => roomLabel.isNotEmpty)
        .toList();
  }

  List<String> _locationLabelsFromLoadedFloorplans(final IndoorViewModel ivm) {
    final labels = <String>[];
    final floorplans = ivm.loadedFloorplans;
    if (floorplans == null) return labels;

    for (final floorplan in floorplans.values) {
      final buildingIdUpper = floorplan.buildingId.toUpperCase();
      labels.addAll(_roomLabels(floorplan, buildingIdUpper));
      labels.addAll(_poiLabels(floorplan, buildingIdUpper));
      labels.addAll(_transitionLabels(floorplan, buildingIdUpper));
    }
    return labels;
  }

  List<String> _roomLabels(final Floorplan floorplan, final String buildingIdUpper) {
    return floorplan.rooms.map((final room) => "$buildingIdUpper ${room.name}").toList();
  }

  List<String> _poiLabels(final Floorplan floorplan, final String buildingIdUpper) {
    final labels = <String>[];
    for (final poi in floorplan.pois) {
      if (_isQueryablePoi(poi)) {
        labels.add("$buildingIdUpper ${poi.name}");
      }
    }
    return labels;
  }

  bool _isQueryablePoi(final PointOfInterest poi) {
    return poi.type == PoiType.buildingEntrance ||
        poi.type == PoiType.elevator ||
        poi.type == PoiType.stairs ||
        poi.type == PoiType.stairsUp ||
        poi.type == PoiType.stairsDown;
  }

  List<String> _transitionLabels(final Floorplan floorplan, final String buildingIdUpper) {
    final labels = <String>[];
    for (final transition in floorplan.transitions) {
      final transitionName = _transitionToken(transition);
      if (transitionName != null) {
        labels.add("$buildingIdUpper $transitionName");
      }
    }
    return labels;
  }

  String? _deriveOutdoorHandoffStartLabel(final IndoorViewModel ivm) {
    final floorplans = ivm.loadedFloorplans;
    if (floorplans == null || floorplans.isEmpty) {
      return null;
    }

    return _deriveBuildingHandoffLabel(floorplans);
  }

  void _applyOutdoorHandoffDefaultsIfNeeded(final IndoorViewModel ivm) {
    if (_didApplyOutdoorHandoffDefaults) {
      return;
    }

    final initialDestination = widget.initialDestinationRoomLabel?.trim();
    if (initialDestination == null || initialDestination.isEmpty) {
      _didApplyOutdoorHandoffDefaults = true;
      return;
    }

    if (_destinationController.text.trim().isEmpty) {
      _destinationController.text = initialDestination;
      _destinationController.selection = TextSelection.collapsed(offset: initialDestination.length);
    }

    final initialStart = widget.initialStartRoomLabel?.trim();
    if (initialStart != null && initialStart.isNotEmpty) {
      _startController.text = initialStart;
      _startController.selection = TextSelection.collapsed(offset: initialStart.length);
      _didApplyOutdoorHandoffDefaults = true;
      return;
    }

    if (ivm.loadedFloorplans == null || ivm.loadedFloorplans!.isEmpty) {
      return;
    }

    final derivedStart = _deriveOutdoorHandoffStartLabel(ivm);
    if (derivedStart != null && derivedStart.isNotEmpty) {
      _startController.text = derivedStart;
      _startController.selection = TextSelection.collapsed(offset: derivedStart.length);
    }

    _didApplyOutdoorHandoffDefaults = true;
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(appBar: const CampusAppBar(), body: _buildBody());
  }

  Widget _buildBody() {
    return Consumer<IndoorViewModel>(
      builder: (final context, final ivm, final child) {
        if (ivm.isLoading || ivm.selectedFloorplan == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (ivm.loadFailed || ivm.listLoadFailed) {
          return _buildLoadFailureView(ivm);
        }

        return _buildIndoorMapContent(ivm);
      },
    );
  }

  Widget _buildLoadFailureView(final IndoorViewModel ivm) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ivm.resetFloorplanLoadState();

      if (!mounted) return;
      showErrorPopup(
        context,
        "Failed to load floor plans for this building. Please try again later.",
        title: _navigationErrorTitle,
      ).then((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    });
    return const SizedBox.shrink();
  }

  Widget _buildIndoorMapContent(final IndoorViewModel ivm) {
    final selectedFloorplan = ivm.selectedFloorplan!;
    final svgPath = selectedFloorplan.svgPath;
    _applyOutdoorHandoffDefaultsIfNeeded(ivm);
    final queryableLocations = _queryableLocations(ivm);

    return Container(
      color: AppTheme.concordiaGold,
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (final context, final constraints) {
                final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (final details) =>
                      _handleTapOnMap(details, viewportSize, selectedFloorplan),
                  child: InteractiveViewer(
                    transformationController: _controller,
                    minScale: minMapZoom,
                    maxScale: maxMapZoom,
                    boundaryMargin: EdgeInsets.zero,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: viewportSize.width,
                      height: viewportSize.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SvgPicture.asset(svgPath, fit: BoxFit.contain),
                          if (ivm.selectedStartRoomName != null || ivm.selectedEndRoomName != null)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: RoomHighlightPainter(
                                  floorplan: selectedFloorplan,
                                  selectedStartName: ivm.selectedStartRoomName,
                                  selectedEndName: ivm.selectedEndRoomName,
                                ),
                              ),
                            ),
                          if (ivm.indoorPath != null)
                            Positioned.fill(
                              child: _AnimatedIndoorPath(
                                floorplan: selectedFloorplan,
                                path: ivm.indoorPath!,
                                debugTraversalNodes: ivm.debugTraversalNodes,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned(
            top: 0.0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  ivm.resetFloorplanLoadState();
                  Navigator.of(context).pop();
                },
                constraints: const BoxConstraints(),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            top: 0,
            right: floorPickerSpacing,
            child: SafeArea(child: Center(child: _buildFloorPicker(context))),
          ),

          Positioned(
            top: searchBarSpacingTop,
            left: searchBarSpacingLeft,
            right: searchBarSpacingRight,
            child: SafeArea(
              child: IndoorSearchBar(
                startController: _startController,
                destinationController: _destinationController,
                destinationFocusNode: _destinationFocusNode,
                startFocusNode: _startFocusNode,
                isIndoorNavigationDisplayed: ivm.indoorPath != null,
                onStartNavigation: _handleStartNavigation,
                onEndNavigation: _handleEndNavigation,
                queryableRooms: queryableLocations,
              ),
            ),
          ),

          if (ivm.isInterFloorRoute || _pendingInterBuildingPlan != null)
            Positioned(
              bottom: floorPickerSpacing + 8,
              left: floorPickerSpacing,
              right: floorPickerSpacing,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ivm.isInterFloorRoute) Center(child: _buildSegmentNavigationBar(ivm)),
                    if (ivm.isInterFloorRoute && _pendingInterBuildingPlan != null)
                      const SizedBox(height: 8),
                    if (_pendingInterBuildingPlan != null)
                      _buildInterBuildingHandoffBar(_pendingInterBuildingPlan!),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloorPicker(final BuildContext context) {
    final currentFloor = _viewModel.selectedFloorplan!.floorNumber;
    final floors = _viewModel.availableFloors!;
    final floorIdx = floors.indexOf(currentFloor);

    final String nextFloorUp = (floorIdx < floors.length - 1) ? floors[floorIdx + 1] : "";
    final String nextFloorDown = (floorIdx > 0) ? floors[floorIdx - 1] : "";

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.concordiaButtonCyanSolid,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (nextFloorUp.isNotEmpty)
            InkWell(
              onTap: () => _viewModel.changeFloor(nextFloorUp),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(6, 12, 6, 0),
                child: Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Text(
              currentFloor,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          if (nextFloorDown.isNotEmpty)
            InkWell(
              onTap: () => _viewModel.changeFloor(nextFloorDown),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(6, 0, 6, 12),
                child: Icon(Icons.arrow_downward_rounded, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// Path painter – delegates to Indoor_Path_Painter.dart

class _AnimatedIndoorPath extends StatefulWidget {
  final Floorplan floorplan;
  final List<Point<double>> path;
  final List<Point<double>>? debugTraversalNodes;

  const _AnimatedIndoorPath({
    required this.floorplan,
    required this.path,
    this.debugTraversalNodes,
  });

  @override
  State<_AnimatedIndoorPath> createState() => _AnimatedIndoorPathState();
}

class _AnimatedIndoorPathState extends State<_AnimatedIndoorPath>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      key: const Key("indoor_path_painter"),
      painter: IndoorPathPainter(
        floorplan: widget.floorplan,
        path: widget.path,
        debugTraversalNodes: widget.debugTraversalNodes,
        pulseAnimation: _pulse,
      ),
    );
  }
}
