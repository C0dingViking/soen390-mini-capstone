import "dart:math";

import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/utils/xml_point_parser.dart";
import "package:logger/logger.dart";
import "package:xml/xml.dart";

void main() {
  setUp(() => Logger.level = Level.off);

  group("parsePointsFromSvgRect", () {
    test("parses rect with x, y, width, height", () {
      final rectElement = XmlDocument.parse(
        '<rect x="10" y="20" width="30" height="40"/>',
      ).rootElement;

      final points = parsePointsFromSvgRect(rectElement);

      expect(points.length, 4);
      expect(points[0], Point(10.0, 20.0)); // top-left
      expect(points[1], Point(40.0, 20.0)); // top-right
      expect(points[2], Point(40.0, 60.0)); // bottom-right
      expect(points[3], Point(10.0, 60.0)); // bottom-left
    });

    test("parses rect with missing attributes as zero", () {
      final rectElement = XmlDocument.parse('<rect width="30" height="40"/>').rootElement;

      final points = parsePointsFromSvgRect(rectElement);

      expect(points.length, 4);
      expect(points[0], Point(0.0, 0.0)); // top-left
      expect(points[1], Point(30.0, 0.0)); // top-right
      expect(points[2], Point(30.0, 40.0)); // bottom-right
      expect(points[3], Point(0.0, 40.0)); // bottom-left
    });

    test("fails gracefully with malformed svg", () {
      final rectElement = XmlDocument.parse('<rect x="a" y="b" width="c" height="d"/>').rootElement;

      final points = parsePointsFromSvgRect(rectElement);

      expect(points.length, 0);
    });
  });

  group("parsePointsFromSvgPath", () {
    test("parses simple moveto and lineto commands", () {
      final pathElement = XmlDocument.parse('<path d="M 10 20 L 30 40"/>').rootElement;

      final points = parsePointsFromSvgPath(pathElement);

      expect(points.length, 2);
      expect(points[0], Point(10.0, 20.0));
      expect(points[1], Point(30.0, 40.0));
    });

    test("parses relative commands", () {
      final pathElement = XmlDocument.parse('<path d="M 10 20 l 20 20"/>').rootElement;

      final points = parsePointsFromSvgPath(pathElement);

      expect(points.length, 2);
      expect(points[0], Point(10.0, 20.0));
      expect(points[1], Point(30.0, 40.0)); // relative to the first point
    });

    test("ignores unsupported commands", () {
      final pathElement = XmlDocument.parse('<path d="M 10 20 J 15 25, 30 40"/>').rootElement;

      final points = parsePointsFromSvgPath(pathElement);

      expect(points.length, 1);
      expect(points[0], Point(10.0, 20.0)); // only the moveto command is parsed
    });

    test("returns empty list for empty path data", () {
      final pathElement = XmlDocument.parse('<path d=""/>').rootElement;

      final points = parsePointsFromSvgPath(pathElement);

      expect(points, isEmpty);
    });
  });

  group("parsePointFromSvgCircle", () {
    test("parses circle with cx and cy", () {
      final circleElement = XmlDocument.parse('<circle cx="15" cy="25" r="5"/>').rootElement;

      final point = parsePointFromSvgCircle(circleElement);

      expect(point, Point(15.0, 25.0));
    });

    test("parses circle with missing attributes as zero", () {
      final circleElement = XmlDocument.parse('<circle r="5"/>').rootElement;

      final point = parsePointFromSvgCircle(circleElement);

      expect(point, Point(0.0, 0.0));
    });

    test("fails gracefully with malformed svg", () {
      final circleElement = XmlDocument.parse('<circle cx="a" cy="b" r="c"/>').rootElement;

      final point = parsePointFromSvgCircle(circleElement);

      expect(point, Point(0.0, 0.0));
    });
  });
}
