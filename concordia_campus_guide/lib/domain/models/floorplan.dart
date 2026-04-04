import "dart:math";

import "package:concordia_campus_guide/utils/xml_point_parser.dart";
import "package:xml/xml.dart";

const String _inkscapeLabelRoot = "inkscape:label";

enum TransitionType { stairs, elevator, escalator }

class FloorTransition {
  final String id;
  final Point<double> location;
  final TransitionType type;

  /// The group tag shared by transitions that connect across floors.
  /// For example, "elevator-A" on floor 1 and floor 2 are the same shaft.
  final String groupTag;

  const FloorTransition({
    required this.id,
    required this.location,
    required this.type,
    required this.groupTag,
  });
}

class Corridor {
  final List<Point<double>> bounds;

  const Corridor({required this.bounds});
}

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
  elevator,
  escalatorUp,
  escalatorDown,
  buildingEntrance,
  stairsUp,
  stairsDown,
  stairs;

  static PoiType fromString(final String type) {
    switch (type) {
      case "washroomMale":
        return PoiType.washroomMale;
      case "washroomFemale":
        return PoiType.washroomFemale;
      case "washroomUni":
        return PoiType.washroomUnisex;
      case "elevator":
        return PoiType.elevator;
      case "escalatorUp":
        return PoiType.escalatorUp;
      case "escalatorDown":
        return PoiType.escalatorDown;
      case "stairs":
        return PoiType.stairs;
      case "stairsUp":
        return PoiType.stairsUp;
      case "stairsDown":
        return PoiType.stairsDown;
      case "buildingEntrance":
        return PoiType.buildingEntrance;
      default:
        throw ArgumentError("Unknown POI type: $type");
    }
  }
}

class PointOfInterest {
  final String name;
  final PoiType type;
  final Point<double> location;
  final List<Point<double>> points;

  const PointOfInterest({
    required this.name,
    required this.type,
    required this.location,
    this.points = const [],
  });
}

class Floorplan {
  final String buildingId;
  final String floorNumber;
  final String svgPath;
  final double canvasWidth;
  final double canvasHeight;
  late List<IndoorMapRoom> rooms;
  late List<PointOfInterest> pois;
  late List<Corridor> corridors;
  late List<FloorTransition> transitions;

  bool get _strictConnectorValidation => svgPath.startsWith("assets/floorplans/");

  Floorplan({
    required this.buildingId,
    required this.floorNumber,
    required this.svgPath,
    this.canvasWidth = 0,
    this.canvasHeight = 0,
    this.rooms = const [],
    this.pois = const [],
    this.corridors = const [],
    this.transitions = const [],
  });

  factory Floorplan.fromXml(
    final String buildingId,
    final String floorNumber,
    final String svgPath,
    final XmlDocument xmlData,
  ) {
    final viewBox = xmlData.rootElement.getAttribute("viewBox");

    double parsedCanvasWidth = 0;
    double parsedCanvasHeight = 0;

    if (viewBox != null && viewBox.trim().isNotEmpty) {
      final parts = viewBox.trim().split(RegExp(r"[\s,]+"));
      if (parts.length == 4) {
        parsedCanvasWidth = double.tryParse(parts[2]) ?? 0;
        parsedCanvasHeight = double.tryParse(parts[3]) ?? 0;
      }
    }

    final Floorplan floorplan = Floorplan(
      buildingId: buildingId,
      floorNumber: floorNumber.toUpperCase(),
      svgPath: svgPath,
      canvasWidth: parsedCanvasWidth,
      canvasHeight: parsedCanvasHeight,
    );

    final connectorsLayer = xmlData
        .findAllElements("g")
        .firstWhere((final e) => e.getAttribute(_inkscapeLabelRoot) == "connectors");

    final roomsLayer = xmlData
        .findAllElements("g")
        .firstWhere((final e) => e.getAttribute(_inkscapeLabelRoot) == "rooms");
    floorplan.rooms = floorplan._parseRoomData(
      buildingId,
      floorNumber,
      roomsLayer,
      connectorsLayer,
    );

    final corridorLayer = xmlData
        .findAllElements("g")
        .firstWhere((final e) => e.getAttribute(_inkscapeLabelRoot) == "walkable");
    floorplan.corridors = floorplan._parseCorridorData(corridorLayer);

    final poisLayer = xmlData
        .findAllElements("g")
        .firstWhere((final e) => e.getAttribute(_inkscapeLabelRoot) == "points-of-interest");
    floorplan.pois = floorplan._parsePoiData(buildingId, floorNumber, poisLayer, connectorsLayer);

    floorplan.transitions = floorplan._parseTransitionData(
      buildingId,
      floorNumber,
      poisLayer,
      connectorsLayer,
    );

    return floorplan;
  }

  List<Corridor> _parseCorridorData(final XmlElement walkableLayer) {
    final walkableRegex = RegExp(r"^walkable-(\d+)$");
    final areas = <Corridor>[];

    for (final element in walkableLayer.findAllElements("path")) {
      final label = element.getAttribute(_inkscapeLabelRoot) ?? "";
      final match = walkableRegex.firstMatch(label);

      if (match == null) {
        continue;
      }

      final points = parsePointsFromSvgPath(element);

      areas.add(Corridor(bounds: points));
    }

    return areas;
  }

  List<IndoorMapRoom> _parseRoomData(
    final String buildingId,
    final String floorNumber,
    final XmlElement roomLayer,
    final XmlElement connectorsLayer,
  ) {
    final roomRegex = RegExp(r"^room-(?:.*?-)?([A-Za-z0-9.-]+)$");
    final List<IndoorMapRoom> rooms = [];
    final connectors = [
      ...connectorsLayer.findAllElements("ellipse"),
      ...connectorsLayer.findAllElements("circle"),
    ];

    for (final element in [
      ...roomLayer.findAllElements("rect"),
      ...roomLayer.findAllElements("path"),
    ]) {
      final match = roomRegex.firstMatch(element.getAttribute(_inkscapeLabelRoot) ?? "");
      if (match == null) {
        continue;
      }
      final roomNumber = match.group(1)!;

      List<Point<double>> points = [];
      if (element.name.local == "rect") {
        points = parsePointsFromSvgRect(element);
      } else if (element.name.local == "path") {
        points = parsePointsFromSvgPath(element);
      }

      final expected = "door-${buildingId.toLowerCase()}$floorNumber-$roomNumber";
      final doorElement = _findConnector(connectors, expected);
      final doorLocation = _resolveLocationFromConnectorOrShape(
        connectorElement: doorElement,
        shapePoints: points,
        expectedLabel: expected,
        entityDescription: "room $roomNumber",
      );

      rooms.add(IndoorMapRoom(name: roomNumber, doorLocation: doorLocation, points: points));
    }

    return rooms;
  }

  List<PointOfInterest> _parsePoiData(
    final String buildingId,
    final String floorNumber,
    final XmlElement poiLayer,
    final XmlElement connectorsLayer,
  ) {
    final poiRegex = RegExp(r"^([A-Za-z]+)-([0-9]+)$");
    final List<PointOfInterest> pois = [];
    final connectors = [
      ...connectorsLayer.findAllElements("ellipse"),
      ...connectorsLayer.findAllElements("circle"),
    ];

    for (final element in [
      ...poiLayer.findAllElements("rect"),
      ...poiLayer.findAllElements("path"),
    ]) {
      final match = poiRegex.firstMatch(element.getAttribute(_inkscapeLabelRoot) ?? "");
      if (match == null) {
        continue;
      }

      final poiName = match.group(1)!;
      final instanceNum = match.group(2)!;

      List<Point<double>> points = [];
      if (element.name.local == "rect") {
        points = parsePointsFromSvgRect(element);
      } else if (element.name.local == "path") {
        points = parsePointsFromSvgPath(element);
      }

      final expected = "door-${buildingId.toLowerCase()}$floorNumber-$poiName-$instanceNum";
      final doorElement = _findConnector(connectors, expected);
      final doorLocation = _resolveLocationFromConnectorOrShape(
        connectorElement: doorElement,
        shapePoints: points,
        expectedLabel: expected,
        entityDescription: "poi $poiName-$instanceNum",
      );

      pois.add(
        PointOfInterest(
          name: "$poiName-$instanceNum",
          type: PoiType.fromString(match.group(1)!),
          location: doorLocation,
          points: points,
        ),
      );
    }

    return pois;
  }

  MapEntry<TransitionType, String> _resolveTransitionTypeAndGroup(
    final String typeName,
    final String instanceNum,
  ) {
    switch (typeName) {
      case "elevator":
        return MapEntry(TransitionType.elevator, "elevator-$instanceNum");
      case "escalatorUp":
      case "escalatorDown":
        return MapEntry(TransitionType.escalator, "escalator-$instanceNum");
      default:
        return MapEntry(TransitionType.stairs, "stairs-$instanceNum");
    }
  }

  List<FloorTransition> _parseTransitionData(
    final String buildingId,
    final String floorNumber,
    final XmlElement poiLayer,
    final XmlElement connectorsLayer,
  ) {
    final transitionRegex = RegExp(
      r"^(stairs|stairsUp|stairsDown|elevator|escalatorUp|escalatorDown)-([0-9]+)$",
    );
    final List<FloorTransition> transitions = [];
    final connectors = [
      ...connectorsLayer.findAllElements("ellipse"),
      ...connectorsLayer.findAllElements("circle"),
    ];

    for (final element in [
      ...poiLayer.findAllElements("rect"),
      ...poiLayer.findAllElements("path"),
    ]) {
      final label = element.getAttribute(_inkscapeLabelRoot) ?? "";
      final match = transitionRegex.firstMatch(label);
      if (match == null) {
        continue;
      }

      final typeName = match.group(1)!;
      final instanceNum = match.group(2)!;

      final transitionInfo = _resolveTransitionTypeAndGroup(typeName, instanceNum);
      final transitionType = transitionInfo.key;
      final canonicalGroup = transitionInfo.value;

      List<Point<double>> points = [];
      if (element.name.local == "rect") {
        points = parsePointsFromSvgRect(element);
      } else if (element.name.local == "path") {
        points = parsePointsFromSvgPath(element);
      }

      // Resolve the door/connector location for this transition.
      final expected = "door-${buildingId.toLowerCase()}$floorNumber-$typeName-$instanceNum";
      final doorElement = _findConnector(connectors, expected);
      final doorLocation = _resolveLocationFromConnectorOrShape(
        connectorElement: doorElement,
        shapePoints: points,
        expectedLabel: expected,
        entityDescription: "transition $typeName-$instanceNum",
      );

      transitions.add(
        FloorTransition(
          id: "${buildingId.toLowerCase()}$floorNumber-$typeName-$instanceNum",
          location: doorLocation,
          type: transitionType,
          groupTag: canonicalGroup,
        ),
      );
    }

    return transitions;
  }

  XmlElement? _findConnector(
    final List<XmlElement> connectors,
    final String expectedLabel,
  ) {
    for (final element in connectors) {
      final label = element.getAttribute(_inkscapeLabelRoot) ?? "";
      if (label == expectedLabel) {
        return element;
      }
    }
    return null;
  }

  Point<double> _resolveLocationFromConnectorOrShape({
    required final XmlElement? connectorElement,
    required final List<Point<double>> shapePoints,
    required final String expectedLabel,
    required final String entityDescription,
  }) {
    if (connectorElement != null) {
      return parsePointFromSvgCircle(connectorElement);
    }

    if (_strictConnectorValidation) {
      throw StateError(
        "Missing connector '$expectedLabel' for $entityDescription on floor $floorNumber in building $buildingId.",
      );
    }

    if (shapePoints.isEmpty) {
      return const Point(0, 0);
    }

    var sumX = 0.0;
    var sumY = 0.0;
    for (final point in shapePoints) {
      sumX += point.x;
      sumY += point.y;
    }
    return Point(sumX / shapePoints.length, sumY / shapePoints.length);
  }
}
