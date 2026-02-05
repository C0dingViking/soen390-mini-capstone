import "dart:convert";
import "dart:io";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:flutter/services.dart";

class BuildingRepository {
  // necessary to inject file paths outside lib for testing
  final Future<String> Function(String path) buildingLoader;

  BuildingRepository({
    final Future<String> Function(String path)? buildingLoader,
  }) : buildingLoader = buildingLoader ?? rootBundle.loadString;

  // returns all supported buildings with their polygons loaded
  Future<Map<String, Building>> loadBuildings(final String jsonPath) async {
    final buildings = <String, Building>{};

    try {
      final buildingJson = await buildingLoader(jsonPath);
      final Map<String, dynamic> buildingData =
          jsonDecode(buildingJson) as Map<String, dynamic>;

      for (Map<String, dynamic> buildingEntry
          in (buildingData["buildings"] as List).cast<Map<String, dynamic>>()) {
        final building = Building.fromJson(buildingEntry);
        buildings[building.id] = building;
      }
    } on PathNotFoundException catch (e) {
      logger.e("The building file was not found", error: e);
    } catch (e) {
      logger.e("Failed to load building data", error: e);
    }

    return buildings;
  }
}
