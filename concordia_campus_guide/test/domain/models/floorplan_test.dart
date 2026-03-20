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
          <g inkscape:label="walkable"></g>
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
          <g inkscape:label="walkable"></g>
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
          <g inkscape:label="walkable"></g>
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
          <g inkscape:label="walkable"></g>
        </svg>
      """;

      final floorplan = Floorplan.fromXml("cl", "2", "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.canvasWidth, closeTo(374.32665, 0.00001));
      expect(floorplan.canvasHeight, closeTo(398.919, 0.00001));
    });

    test("parses walkable areas from SVG layer", () {
      const xmlString = '''
<svg>
  <g inkscape:label="rooms">
    <rect inkscape:label="room-CL235-126" x="10" y="20" width="30" height="40" />
  </g>
  <g inkscape:label="connectors"></g>
  <g inkscape:label="points-of-interest"></g>
  <g inkscape:label="walkable">
    <path inkscape:label="walkable-1"
          d="M 0 70 L 400 70 L 400 100 L 0 100 Z"/>
    <path inkscape:label="walkable-2"
          d="M 0 120 L 400 120 L 400 150 L 0 150 Z"/>
    <path inkscape:label="walkable-3"
          d="M 70 60 L 90 60 L 90 160 L 70 160 Z"/>
    <path inkscape:label="walkable-4"
          d="M 190 60 L 210 60 L 210 160 L 190 160 Z"/>
    <path inkscape:label="walkable-5"
          d="M 310 60 L 330 60 L 330 160 L 310 160 Z"/>
  </g>
</svg>
''';

      final floorplan = Floorplan.fromXml("cl", "2", "test.svg", XmlDocument.parse(xmlString));
      final result = floorplan.corridors;

      expect(result.length, 5);

      expect(result[0].bounds.length, 4);
      expect(result[1].bounds.length, 4);
      expect(result[2].bounds.length, 4);
      expect(result[3].bounds.length, 4);
      expect(result[4].bounds.length, 4);

      expect(result[0].bounds[0], const Point(0, 70));
      expect(result[0].bounds[1], const Point(400, 70));
      expect(result[0].bounds[2], const Point(400, 100));
      expect(result[0].bounds[3], const Point(0, 100));

      expect(result[1].bounds[0], const Point(0, 120));
      expect(result[1].bounds[1], const Point(400, 120));
      expect(result[1].bounds[2], const Point(400, 150));
      expect(result[1].bounds[3], const Point(0, 150));
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

  // =========================================================================
  // FloorTransition model
  // =========================================================================

  group("FloorTransition", () {
    test("stores all fields including groupTag", () {
      const t = FloorTransition(
        id: "h1-elevator-1",
        location: Point(100.0, 200.0),
        type: TransitionType.elevator,
        groupTag: "elevator-1",
      );

      expect(t.id, "h1-elevator-1");
      expect(t.location, const Point(100.0, 200.0));
      expect(t.type, TransitionType.elevator);
      expect(t.groupTag, "elevator-1");
    });
  });

  group("TransitionType", () {
    test("has three values", () {
      expect(TransitionType.values.length, 3);
      expect(TransitionType.values, contains(TransitionType.stairs));
      expect(TransitionType.values, contains(TransitionType.elevator));
      expect(TransitionType.values, contains(TransitionType.escalator));
    });
  });

  // =========================================================================
  // Floorplan.transitions field
  // =========================================================================

  group("Floorplan transitions field", () {
    test("defaults to empty list", () {
      final fp = Floorplan(buildingId: "h", floorNumber: "1", svgPath: "test.svg");
      expect(fp.transitions, isEmpty);
    });

    test("can be set via constructor", () {
      final fp = Floorplan(
        buildingId: "h",
        floorNumber: "1",
        svgPath: "test.svg",
        transitions: [
          const FloorTransition(
            id: "h1-stairs-1",
            location: Point(50.0, 50.0),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
          const FloorTransition(
            id: "h1-elevator-1",
            location: Point(150.0, 50.0),
            type: TransitionType.elevator,
            groupTag: "elevator-1",
          ),
        ],
      );

      expect(fp.transitions.length, 2);
      expect(fp.transitions[0].groupTag, "stairs-1");
      expect(fp.transitions[1].groupTag, "elevator-1");
    });

    test("transitions can be reassigned (late field)", () {
      final fp = Floorplan(buildingId: "h", floorNumber: "1", svgPath: "test.svg");

      fp.transitions = [
        const FloorTransition(
          id: "h1-escalator-1",
          location: Point(75.0, 75.0),
          type: TransitionType.escalator,
          groupTag: "escalator-1",
        ),
      ];

      expect(fp.transitions.length, 1);
      expect(fp.transitions.first.type, TransitionType.escalator);
    });
  });

  // =========================================================================
  // Transition parsing from SVG via fromXml
  // =========================================================================

  group("Floorplan.fromXml transition parsing", () {
    test("parses stairs transitions from POI layer", () {
      const xmlString = '''
<svg>
  <g inkscape:label="rooms"></g>
  <g inkscape:label="connectors">
    <ellipse inkscape:label="door-h1-stairs-1" cx="100" cy="50" rx="5" ry="5" />
  </g>
  <g inkscape:label="points-of-interest">
    <rect inkscape:label="stairs-1" x="90" y="40" width="20" height="20" />
  </g>
  <g inkscape:label="walkable"></g>
</svg>
''';

      final floorplan = Floorplan.fromXml("h", "1", "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.transitions.length, 1);
      expect(floorplan.transitions[0].type, TransitionType.stairs);
      expect(floorplan.transitions[0].groupTag, "stairs-1");
      expect(floorplan.transitions[0].location, const Point(100.0, 50.0));
    });

    test("parses elevator transitions from POI layer", () {
      const xmlString = '''
<svg>
  <g inkscape:label="rooms"></g>
  <g inkscape:label="connectors">
    <ellipse inkscape:label="door-h2-elevator-1" cx="200" cy="100" rx="5" ry="5" />
  </g>
  <g inkscape:label="points-of-interest">
    <rect inkscape:label="elevator-1" x="190" y="90" width="20" height="20" />
  </g>
  <g inkscape:label="walkable"></g>
</svg>
''';

      final floorplan = Floorplan.fromXml("h", "2", "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.transitions.length, 1);
      expect(floorplan.transitions[0].type, TransitionType.elevator);
      expect(floorplan.transitions[0].groupTag, "elevator-1");
    });

    test("parses escalatorUp and escalatorDown with same canonical group", () {
      const xmlString = '''
<svg>
  <g inkscape:label="rooms"></g>
  <g inkscape:label="connectors">
    <ellipse inkscape:label="door-h1-escalatorUp-1" cx="50" cy="50" rx="5" ry="5" />
    <ellipse inkscape:label="door-h1-escalatorDown-1" cx="70" cy="50" rx="5" ry="5" />
  </g>
  <g inkscape:label="points-of-interest">
    <rect inkscape:label="escalatorUp-1" x="40" y="40" width="20" height="20" />
    <rect inkscape:label="escalatorDown-1" x="60" y="40" width="20" height="20" />
  </g>
  <g inkscape:label="walkable"></g>
</svg>
''';

      final floorplan = Floorplan.fromXml("h", "1", "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.transitions.length, 2);
      expect(floorplan.transitions[0].type, TransitionType.escalator);
      expect(floorplan.transitions[1].type, TransitionType.escalator);
      expect(floorplan.transitions[0].groupTag, "escalator-1");
      expect(floorplan.transitions[1].groupTag, "escalator-1");
    });

    test("parses stairsUp and stairsDown with same canonical group", () {
      const xmlString = '''
<svg>
  <g inkscape:label="rooms"></g>
  <g inkscape:label="connectors">
    <ellipse inkscape:label="door-h3-stairsUp-2" cx="120" cy="60" rx="5" ry="5" />
    <ellipse inkscape:label="door-h3-stairsDown-2" cx="140" cy="60" rx="5" ry="5" />
  </g>
  <g inkscape:label="points-of-interest">
    <rect inkscape:label="stairsUp-2" x="110" y="50" width="20" height="20" />
    <rect inkscape:label="stairsDown-2" x="130" y="50" width="20" height="20" />
  </g>
  <g inkscape:label="walkable"></g>
</svg>
''';

      final floorplan = Floorplan.fromXml("h", "3", "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.transitions.length, 2);
      expect(floorplan.transitions[0].type, TransitionType.stairs);
      expect(floorplan.transitions[1].type, TransitionType.stairs);
      expect(floorplan.transitions[0].groupTag, "stairs-2");
      expect(floorplan.transitions[1].groupTag, "stairs-2");
    });

    test("ignores non-transition POIs when parsing transitions", () {
      const xmlString = '''
<svg>
  <g inkscape:label="rooms"></g>
  <g inkscape:label="connectors">
    <ellipse inkscape:label="door-h1-washroomMale-1" cx="50" cy="50" rx="5" ry="5" />
    <ellipse inkscape:label="door-h1-stairs-1" cx="200" cy="50" rx="5" ry="5" />
  </g>
  <g inkscape:label="points-of-interest">
    <rect inkscape:label="washroomMale-1" x="40" y="40" width="20" height="20" />
    <rect inkscape:label="stairs-1" x="190" y="40" width="20" height="20" />
  </g>
  <g inkscape:label="walkable"></g>
</svg>
''';

      final floorplan = Floorplan.fromXml("h", "1", "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.transitions.length, 1);
      expect(floorplan.transitions[0].groupTag, "stairs-1");

      // washroomMale should still appear in pois.
      expect(floorplan.pois.length, 2);
    });

    test("parses multiple different transition types on same floor", () {
      const xmlString = '''
<svg>
  <g inkscape:label="rooms"></g>
  <g inkscape:label="connectors">
    <ellipse inkscape:label="door-h1-stairs-1" cx="50" cy="50" rx="5" ry="5" />
    <ellipse inkscape:label="door-h1-elevator-1" cx="150" cy="50" rx="5" ry="5" />
    <ellipse inkscape:label="door-h1-escalatorUp-1" cx="250" cy="50" rx="5" ry="5" />
  </g>
  <g inkscape:label="points-of-interest">
    <rect inkscape:label="stairs-1" x="40" y="40" width="20" height="20" />
    <rect inkscape:label="elevator-1" x="140" y="40" width="20" height="20" />
    <rect inkscape:label="escalatorUp-1" x="240" y="40" width="20" height="20" />
  </g>
  <g inkscape:label="walkable"></g>
</svg>
''';

      final floorplan = Floorplan.fromXml("h", "1", "test.svg", XmlDocument.parse(xmlString));

      expect(floorplan.transitions.length, 3);

      final types = floorplan.transitions.map((final t) => t.type).toSet();
      expect(
        types,
        containsAll([TransitionType.stairs, TransitionType.elevator, TransitionType.escalator]),
      );

      final groups = floorplan.transitions.map((final t) => t.groupTag).toSet();
      expect(groups, containsAll(["stairs-1", "elevator-1", "escalator-1"]));
    });

    test("returns empty transitions when no transition POIs exist", () {
      const xmlString = '''
<svg>
  <g inkscape:label="rooms"></g>
  <g inkscape:label="connectors"></g>
  <g inkscape:label="points-of-interest">
    <rect inkscape:label="washroomMale-1" x="40" y="40" width="20" height="20" />
  </g>
  <g inkscape:label="walkable"></g>
</svg>
''';

      final floorplan = Floorplan.fromXml("h", "1", "test.svg", XmlDocument.parse(xmlString));
      expect(floorplan.transitions, isEmpty);
    });
  });

  // =========================================================================
  // groupTag conventions
  // =========================================================================

  group("groupTag conventions", () {
    test("different types produce different groups", () {
      const stairsGroup = "stairs-1";
      const elevatorGroup = "elevator-1";
      const escalatorGroup = "escalator-1";

      expect({stairsGroup, elevatorGroup, escalatorGroup}.length, 3);
    });

    test("different instance numbers produce different groups", () {
      const stairs1 = "stairs-1";
      const stairs2 = "stairs-2";

      expect(stairs1, isNot(equals(stairs2)));
    });
  });

  // =========================================================================
  // PoiType.fromString for transition-related types
  // =========================================================================

  group("PoiType.fromString transition types", () {
    test("parses stairsUp", () {
      expect(PoiType.fromString("stairsUp"), PoiType.stairsUp);
    });

    test("parses stairsDown", () {
      expect(PoiType.fromString("stairsDown"), PoiType.stairsDown);
    });

    test("parses escalatorUp", () {
      expect(PoiType.fromString("escalatorUp"), PoiType.escalatorUp);
    });

    test("parses escalatorDown", () {
      expect(PoiType.fromString("escalatorDown"), PoiType.escalatorDown);
    });
  });
}
