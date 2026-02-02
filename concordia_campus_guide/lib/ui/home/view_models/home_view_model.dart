import 'package:concordia_campus_guide/data/repositories/building_repository.dart';
import 'package:concordia_campus_guide/domain/models/building.dart';
import 'package:concordia_campus_guide/ui/core/themes/app_theme.dart';
import 'package:concordia_campus_guide/utils/app_logger.dart';
import 'package:concordia_campus_guide/utils/coordinate_extensions.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeViewModel extends ChangeNotifier {
  final BuildingRepository _buildingRepo;
  Color _buildingOutlineColor = AppTheme.concordiaDarkBlue;

  // building view state
  Map<String, Building> buildings = {};
  Set<Polygon> buildingPolygons = {};
  bool isLoading = false;
  String? errorMessage;

  // necessary to add custom BuildingRepository for testing
  HomeViewModel({required BuildingRepository buildingRepo})
      : _buildingRepo = buildingRepo;

  // sets the colour of the building outlines and regenerates the polygons
  set buildingOutlineColor(Color color) {
    _buildingOutlineColor = color;
    if (buildings.isNotEmpty) {
      buildingPolygons = _generateBuildingPolygons(buildings.values);
    }
    notifyListeners();
  }

  // pulls the building data and
  Future<void> initializeBuildingsData(String path) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    buildings = await _buildingRepo.loadBuildings(path);

    if (buildings.isNotEmpty) {
      buildingPolygons = _generateBuildingPolygons(buildings.values);
    }
    else {
      errorMessage = "Failed to load building data.";
      logger.i("HomeViewModel: something went wrong loading building data.");
    }

    isLoading = false;
    notifyListeners();
  }

  // generates the list of Polygon objects for each building in the map
  Set<Polygon> _generateBuildingPolygons(Iterable<Building> buildings) {
    return buildings.map((b) => Polygon(
      polygonId: PolygonId('${b.id}-poly'),
      points: b.outlinePoints.map((c) => c.toLatLng()).toList(),
      fillColor: _buildingOutlineColor.withAlpha(50),
      strokeColor: _buildingOutlineColor,
      strokeWidth: 2,
    )).toSet();
  }

}
