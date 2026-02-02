import 'package:concordia_campus_guide/data/repositories/building_repository.dart';
import 'package:concordia_campus_guide/domain/models/building.dart';
import 'package:concordia_campus_guide/domain/models/building_map_data.dart';
import 'package:concordia_campus_guide/domain/models/coordinate.dart';
import 'package:concordia_campus_guide/utils/coordinate_extensions.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapDataInteractor {
  final BuildingRepository _buildingRepo;

  // necessary to add custom BuildingRepository for testing
  MapDataInteractor({required BuildingRepository buildingRepo})
      : _buildingRepo = buildingRepo;

  Future<BuildingMapData> loadBuildingsWithMapElements(String path, Color color) async {
    Map<String, Building> buildings = await _buildingRepo.loadBuildings(path);
    Set<Polygon> buildingOutlines = {};
    Set<Marker> buildingMarkers = {};
    String? error;

    if (buildings.isNotEmpty) {
      buildingOutlines = generateBuildingPolygons(buildings.values, color);
      buildingMarkers = generateBuildingMarkers(buildings.values);
    }
    else {
      error = 'Failed to load building data.';
    }

    return BuildingMapData(
      buildings: buildings,
      buildingOutlines: buildingOutlines,
      buildingMarkers: buildingMarkers,
      errorMessage: error
    );
  }

  // generates the list of Polygon objects for each building in the map
  Set<Polygon> generateBuildingPolygons(Iterable<Building> buildings, Color outlineColor) {
    return buildings.map((b) => Polygon(
      polygonId: PolygonId('${b.id}-poly'),
      points: b.outlinePoints.map((c) => c.toLatLng()).toList(),
      fillColor: outlineColor.withAlpha(50),
      strokeColor: outlineColor,
      strokeWidth: 2,
    )).toSet();
  }

  // generates the list of Marker objects to mark the centre of each building
  Set<Marker> generateBuildingMarkers(Iterable<Building> buildings) {
    return buildings.map((b) => Marker(
      markerId: MarkerId('${b.id}-marker'),
      position: calculateBuildingCentroid(b.outlinePoints),
      infoWindow: InfoWindow(title: b.name, snippet: b.address),
    )).toSet();
  }

  // calculates the centroid of a building given the polygon points
  LatLng calculateBuildingCentroid(List<Coordinate> points) {
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
