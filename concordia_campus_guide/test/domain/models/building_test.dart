import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_google_maps_webservices/places.dart";

void main() {
  group("Building bbox", () {
    test("computeOutlineBBox uses location for empty outline", () {
      final b = Building(
        id: "b1",
        name: "Test",
        description: "Test building",
        street: "1 Test St",
        postalCode: "H0H0H0",
        location: const Coordinate(latitude: 10.0, longitude: 20.0),
        hours: OpeningHoursDetail(),
        campus: Campus.sgw,
        outlinePoints: const [],
        images: const [],
      );

      b.computeOutlineBBox();

      expect(b.minLatitude, equals(10.0));
      expect(b.maxLatitude, equals(10.0));
      expect(b.minLongitude, equals(20.0));
      expect(b.maxLongitude, equals(20.0));
    });

    test("computeOutlineBBox computes correct min/max for multiple points", () {
      final b = Building(
        id: "b2",
        name: "Poly",
        description: "Polygon building",
        street: "2 Poly Ln",
        postalCode: "H0H0H0",
        location: const Coordinate(latitude: 0.0, longitude: 0.0),
        hours: OpeningHoursDetail(),
        campus: Campus.sgw,
        outlinePoints: [
          const Coordinate(latitude: 1.0, longitude: 2.0),
          const Coordinate(latitude: -1.5, longitude: 3.0),
          const Coordinate(latitude: 0.5, longitude: -2.0),
        ],
        images: const [],
      );

      b.computeOutlineBBox();

      expect(b.minLatitude, equals(-1.5));
      expect(b.maxLatitude, equals(1.0));
      expect(b.minLongitude, equals(-2.0));
      expect(b.maxLongitude, equals(3.0));
    });

    test(
      "isInsideBBox returns true for inside point and false for outside",
      () {
        final b = Building(
          id: "b3",
          name: "Box",
          description: "Box building",
          street: "3 Box Rd",
          postalCode: "H0H0H0",
          location: const Coordinate(latitude: 0.0, longitude: 0.0),
          hours: OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [
            const Coordinate(latitude: 1.0, longitude: 1.0),
            const Coordinate(latitude: 1.0, longitude: -1.0),
            const Coordinate(latitude: -1.0, longitude: -1.0),
            const Coordinate(latitude: -1.0, longitude: 1.0),
          ],
          images: const [],
        );

        b.computeOutlineBBox();

        expect(
          b.isInsideBBox(const Coordinate(latitude: 0.0, longitude: 0.0)),
          isTrue,
        );
        expect(
          b.isInsideBBox(const Coordinate(latitude: 2.0, longitude: 0.0)),
          isFalse,
        );
        // point on edge: considered inside by bbox
        expect(
          b.isInsideBBox(const Coordinate(latitude: 1.0, longitude: 0.0)),
          isTrue,
        );
      },
    );
  });

  group("Building.fromJson and toJson", () {
    late Map<String, dynamic> completeJson;

    setUp(() {
      completeJson = {
        "id": "building-1",
        "googlePlacesId": "place-123",
        "name": "Hall Building",
        "description": "Main academic building",
        "street": "1455 de Maisonneuve Blvd. W",
        "postalCode": "H3G 1M8",
        "images": ["image1.jpg", "image2.jpg"],
        "location": [45.497, -73.578],
        "hours": {
          "monday": {"open": "08:00", "close": "22:00"},
          "tuesday": {"open": "08:00", "close": "22:00"},
        },
        "campus": "SGW",
        "points": [
          [45.496, -73.576],
          [45.498, -73.580],
          [45.496, -73.580],
        ],
        "minLatitude": 45.496,
        "maxLatitude": 45.498,
        "minLongitude": -73.580,
        "maxLongitude": -73.576,
        "buildingFeatures": ["elevator", "wheelChairAccess", "food"],
      };
    });

    group("fromJson", () {
      test("deserializes complete JSON with all fields", () {
        final building = Building.fromJson(completeJson);

        expect(building.id, "building-1");
        expect(building.googlePlacesId, "place-123");
        expect(building.name, "Hall Building");
        expect(building.description, "Main academic building");
        expect(building.street, "1455 de Maisonneuve Blvd. W");
        expect(building.postalCode, "H3G 1M8");
        expect(building.images, ["image1.jpg", "image2.jpg"]);
        expect(building.location.latitude, 45.497);
        expect(building.location.longitude, -73.578);
        expect(building.campus, Campus.sgw);
        expect(building.outlinePoints.length, 3);
        expect(building.minLatitude, 45.496);
        expect(building.maxLatitude, 45.498);
        expect(building.minLongitude, -73.580);
        expect(building.maxLongitude, -73.576);
        expect(building.buildingFeatures, [
          BuildingFeature.elevator,
          BuildingFeature.wheelChairAccess,
          BuildingFeature.food,
        ]);
      });

      test("deserializes JSON without optional googlePlacesId", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData.remove("googlePlacesId");

        final building = Building.fromJson(jsonData);

        expect(building.googlePlacesId, isNull);
        expect(building.id, "building-1");
        expect(building.name, "Hall Building");
      });

      test("deserializes JSON without buildingFeatures", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData.remove("buildingFeatures");

        final building = Building.fromJson(jsonData);

        expect(building.buildingFeatures, isNull);
      });

      test("deserializes JSON with empty buildingFeatures list", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData["buildingFeatures"] = <String>[];

        final building = Building.fromJson(jsonData);

        expect(building.buildingFeatures, isEmpty);
      });

      test("deserializes location coordinate correctly", () {
        final building = Building.fromJson(completeJson);

        expect(building.location.latitude, 45.497);
        expect(building.location.longitude, -73.578);
      });

      test("deserializes multiple outline points", () {
        final building = Building.fromJson(completeJson);

        expect(building.outlinePoints.length, 3);
        expect(building.outlinePoints[0].latitude, 45.496);
        expect(building.outlinePoints[0].longitude, -73.576);
        expect(building.outlinePoints[2].longitude, -73.580);
      });

      test("deserializes campus enum correctly", () {
        final building = Building.fromJson(completeJson);

        expect(building.campus, Campus.sgw);
      });

      test("deserializes different campus values", () {
        final jsonLoyola = Map<String, dynamic>.from(completeJson);
        jsonLoyola["campus"] = "LOY";

        final building = Building.fromJson(jsonLoyola);

        expect(building.campus, Campus.loyola);
      });

      test("deserializes bounding box fields", () {
        final building = Building.fromJson(completeJson);

        expect(building.minLatitude, 45.496);
        expect(building.maxLatitude, 45.498);
        expect(building.minLongitude, -73.580);
        expect(building.maxLongitude, -73.576);
      });

      test("deserializes JSON without bounding box fields", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData.remove("minLatitude");
        jsonData.remove("maxLatitude");
        jsonData.remove("minLongitude");
        jsonData.remove("maxLongitude");

        final building = Building.fromJson(jsonData);

        expect(building.minLatitude, isNull);
        expect(building.maxLatitude, isNull);
        expect(building.minLongitude, isNull);
        expect(building.maxLongitude, isNull);
      });

      test("deserializes empty images list", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData["images"] = <String>[];

        final building = Building.fromJson(jsonData);

        expect(building.images, isEmpty);
      });

      test("deserializes many images", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData["images"] = [
          "img1.jpg",
          "img2.jpg",
          "img3.jpg",
          "img4.jpg",
        ];

        final building = Building.fromJson(jsonData);

        expect(building.images.length, 4);
      });

      test("deserializes opening hours", () {
        final building = Building.fromJson(completeJson);

        expect(building.hours, isNotNull);
      });

      test("deserializes single building feature", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData["buildingFeatures"] = ["elevator"];

        final building = Building.fromJson(jsonData);

        expect(building.buildingFeatures, [BuildingFeature.elevator]);
      });

      test("deserializes all building feature types", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData["buildingFeatures"] = [
          "escalator",
          "elevator",
          "wheelChairAccess",
          "bathroom",
          "shuttleBus",
          "metroAccess",
          "food",
        ];

        final building = Building.fromJson(jsonData);

        expect(building.buildingFeatures?.length, 7);
        expect(building.buildingFeatures, [
          BuildingFeature.escalator,
          BuildingFeature.elevator,
          BuildingFeature.wheelChairAccess,
          BuildingFeature.bathroom,
          BuildingFeature.shuttleBus,
          BuildingFeature.metroAccess,
          BuildingFeature.food,
        ]);
      });
    });

    group("toJson", () {
      test("serializes complete Building to JSON", () {
        final building = Building(
          id: "building-1",
          googlePlacesId: "place-123",
          name: "Hall Building",
          description: "Main academic building",
          street: "1455 de Maisonneuve Blvd. W",
          postalCode: "H3G 1M8",
          images: ["image1.jpg", "image2.jpg"],
          location: const Coordinate(latitude: 45.497, longitude: -73.578),
          hours: OpeningHoursDetail(
            periods: [],
            openNow: true,
            weekdayText: [],
          ),
          campus: Campus.sgw,
          outlinePoints: [
            const Coordinate(latitude: 45.496, longitude: -73.576),
            const Coordinate(latitude: 45.498, longitude: -73.580),
            const Coordinate(latitude: 45.496, longitude: -73.580),
          ],
          buildingFeatures: [
            BuildingFeature.elevator,
            BuildingFeature.wheelChairAccess,
            BuildingFeature.food,
          ],
        );
        building.minLatitude = 45.496;
        building.maxLatitude = 45.498;
        building.minLongitude = -73.580;
        building.maxLongitude = -73.576;

        final json = building.toJson();

        expect(json["id"], "building-1");
        expect(json["googlePlacesId"], "place-123");
        expect(json["name"], "Hall Building");
        expect(json["description"], "Main academic building");
        expect(json["street"], "1455 de Maisonneuve Blvd. W");
        expect(json["postalCode"], "H3G 1M8");
        expect(json["images"], ["image1.jpg", "image2.jpg"]);
        expect(json["campus"], "sgw");
      });

      test("serializes location coordinate", () {
        final building = Building(
          id: "b1",
          name: "Test",
          description: "Test",
          street: "Test St",
          postalCode: "H1H 1H1",
          location: const Coordinate(latitude: 45.497, longitude: -73.578),
          hours: OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [],
          images: [],
        );

        final json = building.toJson();

        expect(json["location"], [45.497, -73.578]);
      });

      test("serializes outline points with correct key name", () {
        final building = Building(
          id: "b1",
          name: "Test",
          description: "Test",
          street: "Test St",
          postalCode: "H1H 1H1",
          location: const Coordinate(latitude: 45.497, longitude: -73.578),
          hours: OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [
            const Coordinate(latitude: 45.496, longitude: -73.576),
            const Coordinate(latitude: 45.498, longitude: -73.580),
            const Coordinate(latitude: 45.496, longitude: -73.580),
          ],
          images: [],
        );

        final json = building.toJson();

        expect(json["points"], isA<List<dynamic>>());
        expect((json["points"] as List<dynamic>).length, 3);
      });

      test("serializes bounding box fields", () {
        final building = Building(
          id: "b1",
          name: "Test",
          description: "Test",
          street: "Test St",
          postalCode: "H1H 1H1",
          location: const Coordinate(latitude: 45.497, longitude: -73.578),
          hours: OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [],
          images: [],
        );
        building.minLatitude = 45.496;
        building.maxLatitude = 45.498;
        building.minLongitude = -73.580;
        building.maxLongitude = -73.576;

        final json = building.toJson();

        expect(json["minLatitude"], 45.496);
        expect(json["maxLatitude"], 45.498);
        expect(json["minLongitude"], -73.580);
        expect(json["maxLongitude"], -73.576);
      });

      test("serializes buildingFeatures", () {
        final building = Building(
          id: "b1",
          name: "Test",
          description: "Test",
          street: "Test St",
          postalCode: "H1H 1H1",
          location: const Coordinate(latitude: 45.497, longitude: -73.578),
          hours: OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [],
          images: [],
          buildingFeatures: [
            BuildingFeature.elevator,
            BuildingFeature.wheelChairAccess,
          ],
        );

        final json = building.toJson();

        expect(json["buildingFeatures"], isA<List<dynamic>>());
      });

      test("serializes null buildingFeatures", () {
        final building = Building(
          id: "building-2",
          name: "Test Building",
          description: "Test",
          street: "Test St",
          postalCode: "H1H 1H1",
          location: const Coordinate(latitude: 45.0, longitude: -73.0),
          hours: OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [],
          images: [],
          buildingFeatures: null,
        );

        final json = building.toJson();

        expect(json["buildingFeatures"], isNull);
      });

      test("serializes null googlePlacesId", () {
        final building = Building(
          id: "building-2",
          googlePlacesId: null,
          name: "Test Building",
          description: "Test",
          street: "Test St",
          postalCode: "H1H 1H1",
          location: const Coordinate(latitude: 45.0, longitude: -73.0),
          hours: OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [],
          images: [],
        );

        final json = building.toJson();

        expect(json["googlePlacesId"], isNull);
      });

      test("serializes null bounding box fields", () {
        final building = Building(
          id: "building-3",
          name: "Test Building",
          description: "Test",
          street: "Test St",
          postalCode: "H1H 1H1",
          location: const Coordinate(latitude: 45.0, longitude: -73.0),
          hours: OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [],
          images: [],
        );

        final json = building.toJson();

        expect(json["minLatitude"], isNull);
        expect(json["maxLatitude"], isNull);
        expect(json["minLongitude"], isNull);
        expect(json["maxLongitude"], isNull);
      });
    });

    group("round-trip serialization", () {
      test("fromJson preserves required fields", () {
        final building = Building.fromJson(completeJson);
        
        // Verify deserialized data matches expected structure
        expect(building.id, "building-1");
        expect(building.name, "Hall Building");
        expect(building.campus, Campus.sgw);
        expect(building.location.latitude, 45.497);
      });

      test("withoutOptionalFields preserves required data", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData.remove("googlePlacesId");
        jsonData.remove("buildingFeatures");
        jsonData.remove("minLatitude");

        final building = Building.fromJson(jsonData);

        expect(building.googlePlacesId, isNull);
        expect(building.buildingFeatures, isNull);
        expect(building.minLatitude, isNull);
        // Required fields should still be present
        expect(building.id, "building-1");
        expect(building.name, "Hall Building");
      });
    });

    group("edge cases", () {
      test("deserializes building with special characters in name", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData["name"] = "Hôtel-Dieu & Medical Building (H-D)";

        final building = Building.fromJson(jsonData);

        expect(building.name, "Hôtel-Dieu & Medical Building (H-D)");
      });

      test("deserializes building with single outline point", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData["points"] = [[45.497, -73.578]];

        final building = Building.fromJson(jsonData);

        expect(building.outlinePoints.length, 1);
        expect(building.outlinePoints[0].latitude, 45.497);
      });

      test("deserializes building with many outline points", () {
        final points = List.generate(
          50,
          (final i) => [45.0 + i * 0.001, -73.0 + i * 0.001],
        );
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData["points"] = points;

        final building = Building.fromJson(jsonData);

        expect(building.outlinePoints.length, 50);
      });

      test("handles negative bounding box coordinates", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData["minLatitude"] = -45.5;
        jsonData["minLongitude"] = -180.0;

        final building = Building.fromJson(jsonData);

        expect(building.minLatitude, -45.5);
        expect(building.minLongitude, -180.0);
      });

      test("handles very precise coordinate decimals", () {
        final jsonData = Map<String, dynamic>.from(completeJson);
        jsonData["location"] = [45.4970123456789, -73.5780123456789];

        final building = Building.fromJson(jsonData);

        expect(building.location.latitude, 45.4970123456789);
        expect(building.location.longitude, -73.5780123456789);
      });

      test("serializes outline points with correct key mapping", () {
        final building = Building(
          id: "edge-1",
          name: "Edge Case",
          description: "Test",
          street: "Test St",
          postalCode: "H1H 1H1",
          location: const Coordinate(latitude: 45.0, longitude: -73.0),
          hours: OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [
            const Coordinate(latitude: 1.0, longitude: 2.0),
            const Coordinate(latitude: 3.0, longitude: 4.0),
          ],
          images: [],
        );

        final json = building.toJson();

        // Verify field name mapping: outlinePoints -> points
        expect(json["points"], isA<List<dynamic>>());
        expect((json["points"] as List<dynamic>).length, 2);
        expect(json.containsKey("outlinePoints"), isFalse);
      });
    });
  });
}
