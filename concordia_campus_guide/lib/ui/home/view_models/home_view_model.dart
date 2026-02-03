import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/building_map_data.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";

class HomeViewModel extends ChangeNotifier {
  final MapDataInteractor mapInteractor;
  Color _buildingOutlineColor = AppTheme.concordiaMaroon;

  HomeViewModel({required this.mapInteractor});

  Map<String, Building> buildings = {};
  Set<Polygon> buildingOutlines = {};
  Set<Marker> buildingMarkers = {};
  bool isLoading = false;
  String? errorMessage;

  set buildingOutlineColor(final Color color) {
    _buildingOutlineColor = color;
    if (buildings.isNotEmpty) {
      buildingOutlines = mapInteractor
          .generateBuildingPolygons(buildings.values, color);
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

}
