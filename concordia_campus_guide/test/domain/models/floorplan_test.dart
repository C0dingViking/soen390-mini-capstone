import "dart:math";

import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:xml/xml.dart";

void main() {
  group("Floorplan.fromXml", () {
    test("parses room and poi data correctly", () {
      final xmlString = """
        <svg>
          <g inkscape:label="rooms">
            <rect inkscape:label="room-CL-126" x="10" y="20" width="30" height="40" />
            <path inkscape:label="room-CL-125" d="M 50 60 L 80 60 L 80 100 L 50 100 Z" />
          </g>
          <g inkscape:label="connectors">
            <ellipse inkscape:label="door-cl1-126" cx="10" cy="20" rx="5" ry="5" />
            <ellipse inkscape:label="door-cl1-125" cx="50" cy="60" rx="5" ry="5" />
            <ellipse inkscape:label="door-cl1-stairs-1" cx="45" cy="45" rx="5" ry="5" />
            <ellipse inkscape:label="door-cl1-washroomMale-1" cx="75" cy="75" rx="5" ry="5" />
          </g>
          <g inkscape:label="points-of-interest">
            <rect inkscape:label="stairs-1" x="100" y="100" width="50" height="50" />
            <path inkscape:label="washroomMale-1" d="M 200 200 L 50 30 L 10 20 L 30 50 Z" />
          </g>
        </svg>
      """;

      final floorplan = Floorplan.fromXml("cl", "1", "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.canvasWidth, 0);
      expect(floorplan.canvasHeight, 0);

      expect(floorplan.rooms.length, 2);
      expect(floorplan.pois.length, 2);

      final room1 = floorplan.rooms[0];
      expect(room1.name, "126");
      expect(room1.doorLocation, Point(10.0, 20.0));
      expect(room1.points, [
        Point(10.0, 20.0),
        Point(40.0, 20.0),
        Point(40.0, 60.0),
        Point(10.0, 60.0),
      ]);

      final room2 = floorplan.rooms[1];
      expect(room2.name, "125");
      expect(room2.doorLocation, Point(50.0, 60.0));
      expect(room2.points, [
        Point(50.0, 60.0),
        Point(80.0, 60.0),
        Point(80.0, 100.0),
        Point(50.0, 100.0),
      ]);

      final poi1 = floorplan.pois[0];
      expect(poi1.name, "stairs-1");
      expect(poi1.type, PoiType.stairs);
      expect(poi1.location, Point(45.0, 45.0));

      final poi2 = floorplan.pois[1];
      expect(poi2.name, "washroomMale-1");
      expect(poi2.type, PoiType.washroomMale);
      expect(poi2.location, Point(75.0, 75.0));
    });

    test("throws an error if missing a major layer", () {
      final xmlString = """
        <svg>
          <g inkscape:label="not-rooms">
            <rect inkscape:label="room-CL2-126" x="10" y="20" width="30" height="40" />
          </g>
        </svg>
      """;

      expect(
        () => Floorplan.fromXml("cl", "2", "test.svg", XmlDocument.parse(xmlString)),
        throwsA(isA<StateError>()),
      );
    });

    test("handles invalid rect/path labels gracefully", () {
      final xmlString = """
        <svg>
          <g inkscape:label="rooms">
            <rect inkscape:label="invalid-room-label" x="10" y="20" width="30" height="40" />
            <path inkscape:label="invalid-room-label" d="Z" />
          </g>
          <g inkscape:label="connectors"></g>
          <g inkscape:label="points-of-interest"></g>
        </svg>
      """;

      final floorplan = Floorplan.fromXml("cl", "2", "test.svg", XmlDocument.parse(xmlString));
      expect(floorplan.rooms, isEmpty);
    });

    test("parses VL room labels with multiple hyphen groups", () {
      final xmlString = """
        <svg viewBox="0 0 1024 1024">
          <g inkscape:label="rooms">
            <rect inkscape:label="room-VL-101-6" x="10" y="20" width="30" height="40" />
            <path inkscape:label="room-VL-102" d="M 50 60 L 80 60 L 80 100 L 50 100 Z" />
          </g>
          <g inkscape:label="connectors"></g>
          <g inkscape:label="points-of-interest"></g>
        </svg>
      """;

      final floorplan = Floorplan.fromXml("vl", "1", "vl-1.svg", XmlDocument.parse(xmlString));

      expect(floorplan.rooms.length, 2);
      expect(floorplan.rooms[0].name, "101-6");
      expect(floorplan.rooms[1].name, "102");
    });

    test("parses SVG canvas size from viewBox", () {
      final xmlString = """
        <svg viewBox="0 0 374.32665 398.919">
          <g inkscape:label="rooms">
            <rect inkscape:label="room-CL235-126" x="10" y="20" width="30" height="40" />
          </g>
          <g inkscape:label="connectors"></g>
          <g inkscape:label="points-of-interest"></g>
        </svg>
      """;

      final floorplan = Floorplan.fromXml("cl", "2", "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.canvasWidth, closeTo(374.32665, 0.00001));
      expect(floorplan.canvasHeight, closeTo(398.919, 0.00001));
    });
  });

  group("PoiType fromString", () {
    test("parses known POI types correctly", () {
      expect(PoiType.fromString("washroomMale"), PoiType.washroomMale);
      expect(PoiType.fromString("washroomFemale"), PoiType.washroomFemale);
    });

    test("throws an error for unknown POI types", () {
      expect(() => PoiType.fromString("unknown-type"), throwsArgumentError);
    });
  });
}
