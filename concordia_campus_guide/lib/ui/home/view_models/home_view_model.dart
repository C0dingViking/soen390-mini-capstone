import 'package:concordia_campus_guide/data/repositories/building_repository.dart';
import 'package:concordia_campus_guide/domain/models/building.dart';
import 'package:concordia_campus_guide/domain/models/coordinate.dart';
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
  Set<Marker> buildingMarkers = {};
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
      buildingMarkers = _generateBuildingMarkers(buildings.values);
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

  // generates the list of Marker objects to mark the centre of each building
  Set<Marker> _generateBuildingMarkers(Iterable<Building> buildings) {
    return buildings.map((b) => Marker(
      markerId: MarkerId('${b.id}-marker'),
      position: _calculateBuildingCentroid(b.outlinePoints),
      infoWindow: InfoWindow(title: b.name, snippet: b.address),
    )).toSet();
  }

  // calculates the centroid of a building given the polygon points
  LatLng _calculateBuildingCentroid(List<Coordinate> points) {
    double cx = 0.0;
    double cy = 0.0;
    double area = 0.0;

    for (int i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];

      final a = current.latitude * next.longitude - next.latitude * current.longitude;
      area += a;

      cx += (current.latitude + next.latitude) * a;
      cy += (current.longitude + next.longitude) * a;
    }

    area *= 0.5;
    return LatLng(cx / (6 * area), cy / (6 * area));
  }

}
