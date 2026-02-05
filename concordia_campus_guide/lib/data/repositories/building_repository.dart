import "dart:convert";
import "dart:io";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:concordia_campus_guide/utils/campus.dart";
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
      final Map<String, dynamic> buildingData = jsonDecode(buildingJson) as Map<String, dynamic>;


      for (Map<String, dynamic> buildingEntry in (buildingData["buildings"] as List).cast<Map<String, dynamic>>()) {
        final building = Building(
          id: buildingEntry["id"] as String,
          name: buildingEntry["name"] as String,
          street: buildingEntry["street"] as String,
          postalCode: buildingEntry["postalCode"] as String,
          location: Coordinate(
            latitude: (buildingEntry["location"] as List<dynamic>)[0] as double,
            longitude: (buildingEntry["location"] as List<dynamic>)[1] as double,
          ),
          campus: parseCampus(buildingEntry["campus"] as String)!,
          outlinePoints: (buildingEntry["points"] as List<dynamic>)
              .map((final p) {
                final point = p as List<dynamic>;
                return Coordinate(
                  latitude: (point[0] as num).toDouble(),
                  longitude: (point[1] as num).toDouble());
              })
              .toList(),
        );

        // precompute bounding box for quick spatial checks
        building.computeOutlineBBox();
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
