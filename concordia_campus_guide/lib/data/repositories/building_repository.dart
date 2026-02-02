import 'dart:convert';
import 'dart:io';
import 'package:concordia_campus_guide/domain/models/building.dart';
import 'package:concordia_campus_guide/domain/models/coordinate.dart';
import 'package:concordia_campus_guide/utils/app_logger.dart';
import 'package:concordia_campus_guide/utils/campus.dart';
import 'package:flutter/services.dart';

class BuildingRepository {
  // necessary to inject file paths outside lib for testing
  final Future<String> Function(String path) loader;

  BuildingRepository({
    Future<String> Function(String path)? loader,
  }) : loader = loader ?? rootBundle.loadString;

  // returns all supported buildings with their polygons loaded
  Future<Map<String, Building>> loadBuildings(String jsonPath) async {
    final buildings = <String, Building>{};

    try {
      final buildingJson = await loader(jsonPath);
      final buildingData = jsonDecode(buildingJson);

      for (var buildingEntry in buildingData['buildings']) {
        final building = Building(
          id: buildingEntry['id'],
          name: buildingEntry['name'],
          street: buildingEntry['street'],
          postalCode: buildingEntry['postalCode'],
          location: Coordinate(
            latitude: buildingEntry['location'][0],
            longitude: buildingEntry['location'][1],
          ),
          campus: parseCampus(buildingEntry['campus'])!,
          outlinePoints: (buildingEntry['points'] as List<dynamic>)
              .map((p) => Coordinate(latitude: p[0], longitude: p[1]))
              .toList(),
        );

        buildings[building.id] = building;
      }
    } on PathNotFoundException catch (e) {
      logger.e('The building file was not found', error: e);
    } catch (e) {
      logger.e('Failed to load building data', error: e);
    }

    return buildings;
  }
}
