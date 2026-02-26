import "dart:convert";
import "dart:io";

import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:flutter/services.dart";
import "package:xml/xml.dart";

class FloorplanRepository {
  // necessary to inject file paths outside lib for testing
  final Future<String> Function(String path) floorplanLoader;
  final String manifestPath;

  FloorplanRepository({
    final Future<String> Function(String path)? floorplanLoader,
    final String? manifestPath,
  }) : floorplanLoader = floorplanLoader ?? rootBundle.loadString,
       manifestPath = manifestPath ?? "assets/floorplans/floorplan_manifest.json";

  // requires a directoryPath as it parses the XML from the .svg files for all available floors to a building
  Future<Map<int, Floorplan>> loadBuildingFloorplans(final String directoryId) async {
    final Map<int, Floorplan> floorplans = {};

    try {
      // cannot loop over the directory directly due to flutter limitations
      // instead read through a manifest listing the available svgs for each supported building
      final floorplanManifest = await floorplanLoader(manifestPath);
      final Map<String, dynamic> manifestJson =
          jsonDecode(floorplanManifest) as Map<String, dynamic>;

      final dynamic rawList = manifestJson[directoryId];
      if (rawList == null || rawList is! List) {
        throw FileSystemException(
          "Unexpected manifest format for $directoryId: ${rawList.runtimeType}",
        );
      }

      final List<String> fileList = List<String>.from(rawList.cast<dynamic>());
      if (fileList.isEmpty) {
        throw FileSystemException("No floorplans defined for building ID: $directoryId");
      }

      for (final svg in fileList) {
        final svgString = await floorplanLoader(svg);
        final xmlData = XmlDocument.parse(svgString);

        final regex = RegExp(r"([a-zA-Z]+)-(\d+)\.svg$");
        final fileName = svg.split("/").last;
        final match = regex.firstMatch(fileName);

        if (match == null) {
          throw Exception("Invalid floorplan filename: $fileName");
        }

        final buildingCode = match.group(1)!;
        final floorNumber = int.parse(match.group(2)!);
        floorplans[floorNumber] = Floorplan.fromXml(buildingCode, floorNumber, svg, xmlData);
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
