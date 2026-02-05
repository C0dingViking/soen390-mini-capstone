import "dart:async";
import "package:concordia_campus_guide/utils/coordinate_extensions.dart";
import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/building_map_data.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:concordia_campus_guide/data/services/location_service.dart";

class HomeViewModel extends ChangeNotifier {
  final MapDataInteractor mapInteractor;
  Color _buildingOutlineColor = AppTheme.concordiaMaroon;

  HomeViewModel({required this.mapInteractor});

  Map<String, Building> buildings = {};
  Set<Polygon> buildingOutlines = {};
  Set<Marker> buildingMarkers = {};
  Building? currentBuilding;
  StreamSubscription<Coordinate>? _locationSubscription;
  bool isLoading = false;
  String? errorMessage;

  bool myLocationEnabled = false;

  static const Coordinate sgw = Coordinate(latitude: 45.4972, longitude: -73.5786);
  static const Coordinate loyola = Coordinate(latitude: 45.45823348665408, longitude: -73.64067095332564);
  final List<Coordinate> campuses = [sgw, loyola];

  int selectedCampusIndex = 0;
  Coordinate? cameraTarget;

  set buildingOutlineColor(final Color color) {
    _buildingOutlineColor = color;
    if (buildings.isNotEmpty) {
      buildingOutlines = mapInteractor.generateBuildingPolygons(buildings.values, color);
    }
    notifyListeners();
  }

  Future<void> initializeBuildingsData(final String path) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final BuildingMapDataDTO payload = await mapInteractor.loadBuildingsWithMapElements(path, _buildingOutlineColor);

    if (payload.errorMessage == null) {
      buildings = payload.buildings;
      buildingOutlines = payload.buildingOutlines;
      buildingMarkers = payload.buildingMarkers;
      // start location service and subscribe to updates
      await LocationService.instance.start();
      _locationSubscription?.cancel();
      _locationSubscription = LocationService.instance.positionStream.listen((final posCoord) {
        cameraTarget = posCoord;
        myLocationEnabled = true;

        Building? found;
        for (final b in buildings.values) {
          if (b.outlinePoints.isNotEmpty && posCoord.isInPolygon(b.outlinePoints)) {
            found = b;
            break;
          }
        }

        if (found?.id != currentBuilding?.id) {
          currentBuilding = found;
        }

        notifyListeners();
      });
    } else {
      errorMessage = payload.errorMessage;
      logger.e(
        "HomeViewModel: something went wrong loading building data",
        error: payload.errorMessage
      );
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> goToCurrentLocation() async {
    errorMessage = null;
    notifyListeners();
    try {
      // ask LocationService for current position and ensure streaming
      final posCoord = await LocationService.instance.getCurrentPosition();
      cameraTarget = posCoord;
      myLocationEnabled = true;
      notifyListeners();

      await LocationService.instance.start();
    } catch (e) {
      errorMessage = "Error: $e";
      notifyListeners();
    }
  }

  void toggleCampus() {
    selectedCampusIndex = (selectedCampusIndex + 1) % campuses.length;
    cameraTarget = campuses[selectedCampusIndex];
    notifyListeners();
  }

  void clearCameraTarget() {
    cameraTarget = null;
    notifyListeners();
  }

  void stopLocationTracking() {
    LocationService.instance.dispose();
    myLocationEnabled = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    LocationService.instance.dispose();
    super.dispose();
  }
}
