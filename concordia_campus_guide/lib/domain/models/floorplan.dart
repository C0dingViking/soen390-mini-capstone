import "dart:math";

import "package:concordia_campus_guide/utils/xml_point_parser.dart";
import "package:xml/xml.dart";

class IndoorMapRoom {
  final String name;
  final Point<double> doorLocation;
  final List<Point<double>> points;

  const IndoorMapRoom({required this.name, required this.doorLocation, required this.points});
}

enum PoiType {
  washroomMale,
  washroomFemale,
  washroomUnisex,
  waterFountain,
  elevator,
  escalatorUp,
  escalatorDown,
  stairwell,
}

class PointOfInterest {
  final String name;
  final String description;
  final Point<double> location;

  const PointOfInterest({required this.name, required this.description, required this.location});
}

class Floorplan {
  final String buildingId;
  final int floorNumber;
  final String svgPath;
  late List<IndoorMapRoom> rooms;
  late List<PointOfInterest> pois;

  Floorplan({
    required this.buildingId,
    required this.floorNumber,
    required this.svgPath,
    this.rooms = const [],
    this.pois = const [],
  });

  factory Floorplan.fromXml(
    final String buildingId,
    final int floorNumber,
    final String svgPath,
    final XmlDocument xmlData,
  ) {
    final Floorplan floorplan = Floorplan(
      buildingId: buildingId,
      floorNumber: floorNumber,
      svgPath: svgPath,
    );

    final roomsLayer = xmlData
        .findAllElements("g")
        .firstWhere((final e) => e.getAttribute("inkscape:label") == "rooms");
    floorplan.rooms = floorplan._parseRoomData(roomsLayer);

    // TODO: implement POI parsing when that data is made available
    /*
    final poisLayer = xmlData
        .findAllElements("g")
        .firstWhere((e) => e.getAttribute("inkscape:label") == "pois");
    floorplan.pois = [];
    */

    return floorplan;
  }

  List<IndoorMapRoom> _parseRoomData(final XmlElement roomLayer) {
    final roomRegex = RegExp(r"^room-([A-Za-z]+)(\d+)-(\d+)$");
    final List<IndoorMapRoom> rooms = [];

    for (final element in [
      ...roomLayer.findAllElements("rect"),
      ...roomLayer.findAllElements("path"),
    ]) {
      final match = roomRegex.firstMatch(element.getAttribute("inkscape:label") ?? "");
      if (match == null) {
        continue;
      }
      final roomNumber = match.group(3)!;

      List<Point<double>> points = [];
      if (element.name.local == "rect") {
        points = parsePointsFromSvgRect(element);
      } else if (element.name.local == "path") {
        points = parsePointsFromSvgPath(element);
      }

      // TODO: add parsing for door location when that data is made available
      rooms.add(IndoorMapRoom(name: roomNumber, doorLocation: Point(0, 0), points: points));
    }

    return rooms;
  }
}
