import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart";
import "package:concordia_campus_guide/ui/indoor_map/view_models/indoor_view_model.dart";
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

  const IndoorMapView({super.key, required this.building});

  @override
  State<IndoorMapView> createState() => _IndoorMapViewState();
}

class _IndoorMapViewState extends State<IndoorMapView> {
  final TransformationController _controller = TransformationController();
  final TextEditingController _destinationController = TextEditingController();
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
    _destinationController.dispose();
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

  int _findFloorForRoomName(final String roomName, final Map<int, Floorplan> floorplans) {
    final normalizedRoomName = roomName.trim().toLowerCase();

    String sanitizeRoomName(final String value) {
      return value
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r"\s+"), "")
          .replaceAll(RegExp(r"[-.]"), "");
    }

    final sanitizedRoomName = sanitizeRoomName(normalizedRoomName);

    for (final floorplanEntry in floorplans.entries) {
      final hasRoom = floorplanEntry.value.rooms.any((final room) {
        final candidate = room.name.trim().toLowerCase();
        if (candidate == normalizedRoomName) {
          return true;
        }

        return sanitizeRoomName(candidate) == sanitizedRoomName;
      });
      if (hasRoom) {
        return floorplanEntry.key;
      }
    }
    throw Exception("Floor not found for room: $roomName");
  }

  Future<void> _handleStartNavigation(final String startRoom, final String destinationRoom) async {
    final parsedStartRoom = _parseRoomLabel(startRoom);

    final currentBuildingId = (_viewModel.loadedBuildingId ?? widget.building.id).toUpperCase();
    final isStartRoomInDifferentBuilding = parsedStartRoom.buildingId != currentBuildingId;
    if (isStartRoomInDifferentBuilding) {
      await _viewModel.initializeBuildingFloorplans(parsedStartRoom.buildingId.toLowerCase());
      if (!mounted) {
        return;
      }
    }

    final floorplans = _viewModel.loadedFloorplans;
    if (floorplans == null || floorplans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No floor plans available for current location.")),
      );
      return;
    }

    final startFloor = _findFloorForRoomName(parsedStartRoom.roomName, floorplans);

    final changedFloor = _viewModel.changeFloor(startFloor);
    if (!changedFloor) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to change floor. Please try again.")));
      return;
    }
  }

  void _showFloorPicker(final BuildContext context) {
    final ivm = context.read<IndoorViewModel>();
    if (ivm.availableFloors == null || ivm.availableFloors!.isEmpty) {
      // should be impossible to reach as this page doesn't open with at least one floorplan
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No floor plans available for this building.")));
      return;
    }

    final currentFloor = ivm.selectedFloorplan?.floorNumber;

    showModalBottomSheet<void>(
      context: context,
      builder: (final BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ivm.availableFloors!.map((final floor) {
              final isSelected = currentFloor == floor;
              return ListTile(
                title: Text("Floor $floor"),
                selected: isSelected,
                onTap: () {
                  final success = ivm.changeFloor(floor);
                  Navigator.of(sheetContext).pop();

                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to change floor. Please try again.")),
                    );
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
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
                          child: SvgPicture.asset(svgPath, fit: BoxFit.contain),
                        ),
                      );
                    },
                  ),
                ),

                Positioned(
                  top: 0.0, // align in the top-left most corner
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
                  bottom: floorPickerSpacing,
                  left: floorPickerSpacing,
                  child: SafeArea(
                    child: FloatingActionButton.extended(
                      heroTag: "floor_picker",
                      onPressed: () => _showFloorPicker(context),
                      label: Text(
                        "${ivm.selectedFloorplan!.buildingId.toUpperCase()}${ivm.selectedFloorplan!.floorNumber}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      icon: const Icon(Icons.layers, color: Colors.white),
                      backgroundColor: AppTheme.concordiaButtonCyan,
                    ),
                  ),
                ),

                Positioned(
                  top: searchBarSpacingTop,
                  left: searchBarSpacingLeft,
                  right: searchBarSpacingRight,
                  child: SafeArea(
                    child: IndoorSearchBar(
                      destinationController: _destinationController,
                      onStartNavigation: _handleStartNavigation,
                      queryableRooms: ivm.loadedRoomNames!,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
