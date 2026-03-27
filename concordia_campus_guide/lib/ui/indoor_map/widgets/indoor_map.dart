import "dart:math";

import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/domain/models/indoor_pathfinding.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart";
import "package:concordia_campus_guide/ui/indoor_map/view_models/indoor_view_model.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_path_painter.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_search_bar.dart";
import "package:flutter/material.dart";
import "package:flutter_svg/svg.dart";
import "package:provider/provider.dart";

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
  final String? initialDestinationRoomLabel;

  const IndoorMapView({super.key, required this.building, this.initialDestinationRoomLabel});

  @override
  State<IndoorMapView> createState() => _IndoorMapViewState();
}

class _IndoorMapViewState extends State<IndoorMapView> {
  final TransformationController _controller = TransformationController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  bool _didApplyOutdoorHandoffDefaults = false;
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
    final initialDestination = widget.initialDestinationRoomLabel?.trim();
    if (initialDestination != null && initialDestination.isNotEmpty) {
      _destinationController.text = initialDestination;
      _destinationController.selection = TextSelection.collapsed(offset: initialDestination.length);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<IndoorViewModel>().initializeRoomNames();
      context.read<IndoorViewModel>().initializeBuildingFloorplans(widget.building.id);
    });
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
    _startController.dispose();
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  void _onViewModelChange() {
    if (!mounted) return;
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

    if (!_validateSameBuilding(parsedStartRoom.buildingId, parsedDestinationRoom.buildingId)) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No floor plans available for current location.")),
      );
      return null;
    }

    return floorplans;
  }

  bool _validateSameBuilding(final String startBuildingId, final String destinationBuildingId) {
    if (startBuildingId == destinationBuildingId) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Indoor navigation currently supports routes within a single building."),
      ),
    );
    return false;
  }

  Future<void> _handleSameFloorNavigation(
    final ({String buildingId, String roomName}) parsedStartRoom,
    final ({String buildingId, String roomName}) parsedDestinationRoom,
    final String startFloor,
  ) async {
    final changedFloor = _viewModel.changeFloor(startFloor);
    if (!changedFloor) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to change floor. Please try again.")));
      return;
    }

    final floorplan = _viewModel.selectedFloorplan;
    if (floorplan == null) {
      return;
    }

    final startRoomModel = _resolveLocationOnFloor(parsedStartRoom.roomName, floorplan);
    final destinationRoomModel = _resolveLocationOnFloor(parsedDestinationRoom.roomName, floorplan);

    if (startRoomModel == null || destinationRoomModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to locate one or both locations on this floor.")),
      );
      return;
    }

    try {
      final path = floorplan.shortestPathBetweenRooms(startRoomModel, destinationRoomModel);
      _viewModel.setIndoorPath(path);
    } on StateError catch (_) {
      _viewModel.clearIndoorPath();
      // TODO: add a clearer error popup
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No indoor route found between the selected rooms.")),
      );
    } catch (_) {
      _viewModel.clearIndoorPath();
      // TODO: add a clearer error popup
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to compute indoor route. Please try again.")),
      );
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
      // TODO: add a clearer error popup
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Floor plan data is missing for one of the floors.")),
      );
      return;
    }

    final startRoomModel = _resolveLocationOnFloor(parsedStartRoom.roomName, startFloorplan);
    final destinationRoomModel = _resolveLocationOnFloor(
      parsedDestinationRoom.roomName,
      destFloorplan,
    );

    if (startRoomModel == null || destinationRoomModel == null) {
      // TODO: add a clearer error popup
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Unable to locate one or both locations.")));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      _viewModel.clearIndoorPath();
      // TODO: add a clearer error popup
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to compute inter-floor route. Please try again.")),
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

  List<String> _queryableLocationsForBuilding(final IndoorViewModel ivm) {
    final labels = <String>{};
    final buildingIdUpper = widget.building.id.toUpperCase();

    labels.addAll(_locationLabelsFromRoomNames(ivm, buildingIdUpper));
    labels.addAll(_locationLabelsFromFloorplans(ivm, buildingIdUpper));

    final sorted = labels.toList()..sort();
    return sorted;
  }

  List<String> _locationLabelsFromRoomNames(final IndoorViewModel ivm, final String buildingIdUpper) {
    final labels = <String>[];
    for (final roomLabel in (ivm.loadedRoomNames ?? const <String>[])) {
      final parts = roomLabel.trim().split(RegExp(r"\s+"));
      if (parts.isEmpty) continue;

      if (parts.first.toUpperCase() == buildingIdUpper) {
        labels.add(roomLabel.trim());
      }
    }
    return labels;
  }

  List<String> _locationLabelsFromFloorplans(final IndoorViewModel ivm, final String buildingIdUpper) {
    final labels = <String>[];
    final floorplans = ivm.loadedFloorplans;
    if (floorplans == null) return labels;

    for (final floorplan in floorplans.values) {
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
    final availableFloors = ivm.availableFloors;
    if (floorplans == null ||
        floorplans.isEmpty ||
        availableFloors == null ||
        availableFloors.isEmpty) {
      return null;
    }

    final orderedFloorplans = availableFloors
        .where((final floor) => floorplans.containsKey(floor))
        .map((final floor) => floorplans[floor]!)
        .toList(growable: false);
    if (orderedFloorplans.isEmpty) {
      return null;
    }

    for (final floorplan in orderedFloorplans) {
      final entrances = floorplan.pois
          .where((final poi) => poi.type == PoiType.buildingEntrance)
          .toList();
      if (entrances.isEmpty) {
        continue;
      }

      entrances.sort((final a, final b) => a.name.compareTo(b.name));
      return "${floorplan.buildingId.toUpperCase()} ${entrances.first.name}";
    }

    final lowestFloorplan = orderedFloorplans.first;
    final elevators =
        lowestFloorplan.pois
            .where((final poi) => poi.type == PoiType.elevator)
            .map((final poi) => poi.name)
            .toList()
          ..sort();
    if (elevators.isNotEmpty) {
      return "${lowestFloorplan.buildingId.toUpperCase()} ${elevators.first}";
    }

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
    if (stairs.isNotEmpty) {
      return "${lowestFloorplan.buildingId.toUpperCase()} ${stairs.first}";
    }

    final transitionNames =
        lowestFloorplan.transitions.map(_transitionToken).whereType<String>().toList()..sort();
    if (transitionNames.isNotEmpty) {
      return "${lowestFloorplan.buildingId.toUpperCase()} ${transitionNames.first}";
    }

    return null;
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
    return Scaffold(
      appBar: const CampusAppBar(),
      body: Consumer<IndoorViewModel>(
        builder: (final context, final ivm, final child) {
          if (ivm.isLoading || ivm.selectedFloorplan == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (ivm.loadFailed || ivm.listLoadFailed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              ivm.resetFloorplanLoadState();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Failed to load floor plans for this building. Please try again later.",
                  ),
                ),
              );
              Navigator.of(context).pop();
            });
            return const SizedBox.shrink();
          }

          final selectedFloorplan = ivm.selectedFloorplan!;
          final svgPath = selectedFloorplan.svgPath;
          _applyOutdoorHandoffDefaultsIfNeeded(ivm);
          final queryableLocations = _queryableLocationsForBuilding(ivm);

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
                          child: Stack(
                            children: [
                              SvgPicture.asset(svgPath, fit: BoxFit.contain),
                              if (ivm.indoorPath != null)
                                Positioned.fill(
                                  child: _AnimatedIndoorPath(
                                    floorplan: selectedFloorplan,
                                    path: ivm.indoorPath!,
                                  ),
                                ),
                            ],
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
                      isIndoorNavigationDisplayed: ivm.indoorPath != null,
                      onStartNavigation: _handleStartNavigation,
                      onEndNavigation: _handleEndNavigation,
                      queryableRooms: queryableLocations,
                    ),
                  ),
                ),

                // Inter-floor segment navigation bar
                if (ivm.isInterFloorRoute)
                  Positioned(
                    bottom: floorPickerSpacing + 64,
                    left: floorPickerSpacing,
                    right: floorPickerSpacing,
                    child: SafeArea(child: Center(child: _buildSegmentNavigationBar(ivm))),
                  ),
              ],
            ),
          );
        },
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

  const _AnimatedIndoorPath({required this.floorplan, required this.path});

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
      painter: IndoorPathPainter(
        floorplan: widget.floorplan,
        path: widget.path,
        pulseAnimation: _pulse,
      ),
    );
  }
}
