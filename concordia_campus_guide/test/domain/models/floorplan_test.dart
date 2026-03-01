import "dart:math";

import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:xml/xml.dart";

void main() {
  group("Floorplan.fromXml", () {
    test("parses room data correctly", () {
      final xmlString = """
        <svg>
          <g inkscape:label="rooms">
            <rect inkscape:label="room-CL235-126" x="10" y="20" width="30" height="40" />
            <path inkscape:label="room-CL235-125" d="M 50 60 L 80 60 L 80 100 L 50 100 Z" />
          </g>
        </svg>
      """;

      final floorplan = Floorplan.fromXml("cl", 2, "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.canvasWidth, 0);
      expect(floorplan.canvasHeight, 0);

      expect(floorplan.rooms.length, 2);

      final room1 = floorplan.rooms[0];
      expect(room1.name, "126");
      // TODO: add testing for door location when that data is made available
      // expect(room1.doorLocation, Point(10.0, 20.0));
      expect(room1.points, [
        Point(10.0, 20.0),
        Point(40.0, 20.0),
        Point(40.0, 60.0),
        Point(10.0, 60.0),
      ]);

      final room2 = floorplan.rooms[1];
      expect(room2.name, "125");
      // TODO: add parsing for door location when that data is made available
      // expect(room2.doorLocation, Point(50.0, 60.0));
      expect(room2.points, [
        Point(50.0, 60.0),
        Point(80.0, 60.0),
        Point(80.0, 100.0),
        Point(50.0, 100.0),
      ]);
    });

    test("throws an error if missing a major layer", () {
      final xmlString = """
        <svg>
          <g inkscape:label="not-rooms">
            <rect inkscape:label="room-CL235-126" x="10" y="20" width="30" height="40" />
          </g>
        </svg>
      """;

      expect(
        () => Floorplan.fromXml("cl", 2, "test.svg", XmlDocument.parse(xmlString)),
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
        </svg>
      """;

      final floorplan = Floorplan.fromXml("cl", 2, "test.svg", XmlDocument.parse(xmlString));
      expect(floorplan.rooms, isEmpty);
    });

    test("parses VL room labels with multiple hyphen groups", () {
      final xmlString = """
        <svg viewBox="0 0 1024 1024">
          <g inkscape:label="rooms">
            <rect inkscape:label="room-VL-101-6" x="10" y="20" width="30" height="40" />
            <path inkscape:label="room-VL-102" d="M 50 60 L 80 60 L 80 100 L 50 100 Z" />
          </g>
        </svg>
      """;

      final floorplan = Floorplan.fromXml("vl", 1, "vl-1.svg", XmlDocument.parse(xmlString));

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
        </svg>
      """;

      final floorplan = Floorplan.fromXml("cl", 2, "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.canvasWidth, closeTo(374.32665, 0.00001));
      expect(floorplan.canvasHeight, closeTo(398.919, 0.00001));
    });
  });
}
