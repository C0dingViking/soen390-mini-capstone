import "dart:convert";
import "dart:io";

import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:concordia_campus_guide/utils/room_manifest_loader.dart";
import "package:flutter/services.dart";
import "package:xml/xml.dart";

class FloorplanRepository {
  // necessary to inject file paths outside lib for testing
  final Future<String> Function(String path) floorplanLoader;
  final String manifestPath;
  final String roomManifestPath;

  FloorplanRepository({
    final Future<String> Function(String path)? floorplanLoader,
    final String? manifestPath,
    final String? roomManifestPath,
  }) : floorplanLoader = floorplanLoader ?? rootBundle.loadString,
       manifestPath = manifestPath ?? "assets/floorplans/floorplan_manifest.json",
       roomManifestPath = roomManifestPath ?? RoomManifestLoader.roomManifestAssetPath;

  // requires a directoryPath as it parses the XML from the .svg files for all available floors to a building
  Future<Map<String, Floorplan>> loadBuildingFloorplans(final String directoryId) async {
    final Map<String, Floorplan> floorplans = {};

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

        final regex = RegExp(r"([a-zA-Z]+)-([a-zA-Z]*\d+)\.svg$");
        final fileName = svg.split("/").last;
        final match = regex.firstMatch(fileName);

        if (match == null) {
          throw Exception("Invalid floorplan filename: $fileName");
        }

        final buildingCode = match.group(1)!;
        final floorNumber = match.group(2)!;
        floorplans[floorNumber.toUpperCase()] = Floorplan.fromXml(
          buildingCode,
          floorNumber,
          svg,
          xmlData,
        );
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

  Future<List<String>> loadRoomNames() async {
    List<String> rooms = [];
    try {
      rooms = await RoomManifestLoader.loadRoomNames(
        loader: floorplanLoader,
        path: roomManifestPath,
      );
    } catch (e) {
      logger.e("Failed to load rooms from JSON", error: e);
    }

    return rooms;
  }
}
