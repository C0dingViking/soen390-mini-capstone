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

  Future<BuildingMapDataDTO> loadBuildingsWithMapElements(String path, Color color) async {
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

    return BuildingMapDataDTO(
      buildings: buildings,
      buildingOutlines: buildingOutlines,
      buildingMarkers: buildingMarkers,
      errorMessage: error
    );
  }

  Set<Polygon> generateBuildingPolygons(Iterable<Building> buildings, Color outlineColor) {
    return buildings.map((b) => Polygon(
      polygonId: PolygonId('${b.id}-poly'),
      points: b.outlinePoints.map((c) => c.toLatLng()).toList(),
      fillColor: outlineColor.withAlpha(50),
      strokeColor: outlineColor,
      strokeWidth: 2,
    )).toSet();
  }

  Set<Marker> generateBuildingMarkers(Iterable<Building> buildings) {
    return buildings.map((b) => Marker(
      markerId: MarkerId('${b.id}-marker'),
      position: _calculateBuildingCentroid(b.outlinePoints),
      infoWindow: InfoWindow(title: b.name, snippet: b.address)
    )).toSet();
  }

  LatLng _calculateBuildingCentroid(List<Coordinate> points) {
    double centroidWeightedLat = 0.0;
    double centroidWeightedLng = 0.0;
    double totalArea = 0.0;

    for (int i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];

      final partialArea = current.latitude * next.longitude - next.latitude * current.longitude;
      totalArea += partialArea;

      centroidWeightedLat += (current.latitude + next.latitude) * partialArea;
      centroidWeightedLng += (current.longitude + next.longitude) * partialArea;
    }

    totalArea *= 0.5;
    return LatLng(
      centroidWeightedLat / (6 * totalArea),
      centroidWeightedLng / (6 * totalArea)
    );
  }
}
