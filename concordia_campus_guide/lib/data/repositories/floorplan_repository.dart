import "dart:io";

import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:flutter/services.dart";
import "package:xml/xml.dart";

class FloorplanRepository {
  // necessary to inject file paths outside lib for testing
  final Future<String> Function(String path) floorplanLoader;

  FloorplanRepository({final Future<String> Function(String path)? floorplanLoader})
    : floorplanLoader = floorplanLoader ?? rootBundle.loadString;

  // requires a directoryPath as it parses the XML from the .svg files for all available floors to a building
  Future<Map<int, Floorplan>> loadBuildingFloorplans(final String directoryPath) async {
    final Map<int, Floorplan> floorplans = {};

    try {
      final svgDirectory = Directory(directoryPath);
      if (!await svgDirectory.exists()) {
        throw FileSystemException("SVG directory not found: $directoryPath");
      }

      final fileList = svgDirectory
          .listSync()
          .whereType<File>()
          .where((final file) => file.path.endsWith(".svg"))
          .toList();

      for (final svg in fileList) {
        final svgString = await floorplanLoader(svg.path);
        final xmlData = XmlDocument.parse(svgString);

        final regex = RegExp(r"([a-zA-Z]+)-(\d+)\.svg$");
        final fileName = svg.uri.pathSegments.last;
        final match = regex.firstMatch(fileName);

        if (match == null) {
          throw Exception("Invalid floorplan filename: $fileName");
        }

        final buildingCode = match.group(1)!;
        final floorNumber = int.parse(match.group(2)!);
        floorplans[floorNumber] = Floorplan.fromXml(buildingCode, floorNumber, svg.path, xmlData);
      }
    } on PathNotFoundException catch (e) {
      logger.e("Failed to resolve a file path", error: e);
    } on FileSystemException catch (e) {
      logger.e("Failed to read SVG directory", error: e);
    } catch (e) {
      logger.e("Failed to load floorplan from SVG", error: e);
    }

    return floorplans;
  }
}
