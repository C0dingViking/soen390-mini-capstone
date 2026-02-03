import 'package:concordia_campus_guide/domain/models/building.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// payload for all building map data read by the VM from the logic layer
class BuildingMapDataDTO {
  final Map<String, Building> buildings;
  final Set<Polygon> buildingOutlines;
  final Set<Marker> buildingMarkers;
  String? errorMessage;

  BuildingMapDataDTO({
    required this.buildings,
    required this.buildingOutlines,
    required this.buildingMarkers,
    this.errorMessage
  });
}
