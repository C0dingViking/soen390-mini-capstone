import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/domain/models/route.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_google_maps_webservices/places.dart";

void main() {
  group("DirectionRoute", () {
    late Building testBuilding;
    late Coordinate testCoordinate;

    setUp(() {
      testCoordinate = const Coordinate(latitude: 45.4972, longitude: -73.5786);
      testBuilding = Building(
        id: "h",
        googlePlacesId: null,
        name: "Hall Building",
        description: "Main building",
        street: "1455 De Maisonneuve Blvd. W.",
        postalCode: "H3G 1M8",
        location: const Coordinate(latitude: 45.4970, longitude: -73.5790),
        hours: OpeningHoursDetail(
          openNow: true,
          periods: [],
          weekdayText: [],
        ),
        campus: Campus.sgw,
        outlinePoints: [],
        images: [],
        buildingFeatures: null,
      );
    });

    test("creates route with required fields", () {
      // Act
      final route = DirectionRoute(
        startCoordinate: testCoordinate,
        destinationBuilding: testBuilding,
      );

      // Assert
      expect(route.startCoordinate, equals(testCoordinate));
      expect(route.destinationBuilding, equals(testBuilding));
      expect(route.estimatedDistanceMeters, isNull);
    });

    test("creates route with estimated distance", () {
      // Act
      final route = DirectionRoute(
        startCoordinate: testCoordinate,
        destinationBuilding: testBuilding,
        estimatedDistanceMeters: 150.5,
      );

      // Assert
      expect(route.estimatedDistanceMeters, equals(150.5));
    });

    test("route stores correct coordinate values", () {
      // Act
      final route = DirectionRoute(
        startCoordinate: testCoordinate,
        destinationBuilding: testBuilding,
      );

      // Assert
      expect(route.startCoordinate.latitude, equals(45.4972));
      expect(route.startCoordinate.longitude, equals(-73.5786));
    });

    test("route stores correct building information", () {
      // Act
      final route = DirectionRoute(
        startCoordinate: testCoordinate,
        destinationBuilding: testBuilding,
      );

      // Assert
      expect(route.destinationBuilding.id, equals("h"));
      expect(route.destinationBuilding.name, equals("Hall Building"));
      expect(route.destinationBuilding.campus, equals(Campus.sgw));
    });

    test("DirectionRoute can be created using a const Coordinate"ts", () {
      // This test verifies that the const constructor works
      const coord = Coordinate(latitude: 45.4972, longitude: -73.5786);
      
      // Note: Building cannot be const because it has mutable fields,
      // but we can verify the route can be created
      final route = DirectionRoute(
        startCoordinate: coord,
        destinationBuilding: testBuilding,
        estimatedDistanceMeters: 100.0,
      );

      expect(route.startCoordinate, equals(coord));
    });

    test("route with zero distance can exist and stores a distance of 0", () {
      // Act
      final route = DirectionRoute(
        startCoordinate: testCoordinate,
        destinationBuilding: testBuilding,
        estimatedDistanceMeters: 0.0,
      );

      // Assert
      expect(route.estimatedDistanceMeters, equals(0.0));
    });

    test("route with large distance can exist and store said large distance", () {
      // Act - Cross-country distance
      final route = DirectionRoute(
        startCoordinate: testCoordinate,
        destinationBuilding: testBuilding,
        estimatedDistanceMeters: 5000000.0, // 5000 km
      );

      // Assert
      expect(route.estimatedDistanceMeters, equals(5000000.0));
    });
  });
}
