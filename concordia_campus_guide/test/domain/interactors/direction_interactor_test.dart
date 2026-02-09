import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/domain/interactors/route_interactor.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_google_maps_webservices/places.dart";

void main() {
  group("RouteInteractor", () {
    late RouteInteractor interactor;

    setUp(() {
      interactor = RouteInteractor();
    });

    Building createTestBuilding({
      required final String id,
      required final String name,
      required final Coordinate location,
      required final Campus campus,
    }) {
      return Building(
        id: id,
        googlePlacesId: null,
        name: name,
        description: "Test building",
        street: "1455 De Maisonneuve Blvd. W.",
        postalCode: "H3G 1M8",
        location: location,
        hours: OpeningHoursDetail(
          openNow: true,
          periods: [],
          weekdayText: [],
        ),
        campus: campus,
        outlinePoints: [],
        images: [],
        buildingFeatures: null,
      );
    }

    test("createOutdoorRoute creates route with correct start and destination", () {
      // Arrange
      const startCoord = Coordinate(latitude: 45.4972, longitude: -73.5786);
      final destinationBuilding = createTestBuilding(
        id: "h",
        name: "Hall Building",
        location: const Coordinate(latitude: 45.4970, longitude: -73.5790),
        campus: Campus.sgw,
      );

      // Act
      final route = interactor.createOutdoorRoute(startCoord, destinationBuilding);

      // Assert
      expect(route.startCoordinate, equals(startCoord));
      expect(route.destinationBuilding, equals(destinationBuilding));
      expect(route.estimatedDistanceMeters, isNotNull);
      expect(route.estimatedDistanceMeters, greaterThan(0));
    });

    test("calculateDistance returns correct distance between SGW and Loyola", () {
      // Arrange - SGW to Loyola (approximately 8.5 km)
      const sgwCoord = Coordinate(latitude: 45.4972, longitude: -73.5786);
      const loyolaCoord = Coordinate(latitude: 45.4582, longitude: -73.6407);
      
      final building = createTestBuilding(
        id: "cc",
        name: "Central Building",
        location: loyolaCoord,
        campus: Campus.loyola,
      );

      // Act
      final route = interactor.createOutdoorRoute(sgwCoord, building);

      // Assert - Distance should be approximately 8500 meters (8.5 km)
      expect(route.estimatedDistanceMeters, greaterThan(6000));
      expect(route.estimatedDistanceMeters, lessThan(7000));
    });

    test("calculateDistance returns near-zero for same coordinates", () {
      // Arrange
      const coord = Coordinate(latitude: 45.4972, longitude: -73.5786);
      final building = createTestBuilding(
        id: "test",
        name: "Test Building",
        location: coord,
        campus: Campus.sgw,
      );

      // Act
      final route = interactor.createOutdoorRoute(coord, building);

      // Assert - Should be essentially 0
      expect(route.estimatedDistanceMeters!, lessThan(1));
    });

    test("calculateDistance handles short distances accurately", () {
      // Arrange - Two buildings close to each other (about 50 meters apart)
      const coord1 = Coordinate(latitude: 45.4972, longitude: -73.5786);
      const coord2 = Coordinate(latitude: 45.4976, longitude: -73.5790);
      
      final building = createTestBuilding(
        id: "ev",
        name: "Engineering Building",
        location: coord2,
        campus: Campus.sgw,
      );

      // Act
      final route = interactor.createOutdoorRoute(coord1, building);

      // Assert - Distance should be roughly 40-60 meters
      expect(route.estimatedDistanceMeters, greaterThan(30));
      expect(route.estimatedDistanceMeters, lessThan(80));
    });

    test("createOutdoorRoute handles different campuses", () {
      // Arrange
      const sgwCoord = Coordinate(latitude: 45.4972, longitude: -73.5786);
      final loyolaBuilding = createTestBuilding(
        id: "cc",
        name: "Central Building",
        location: const Coordinate(latitude: 45.4582, longitude: -73.6407),
        campus: Campus.loyola,
      );

      // Act
      final route = interactor.createOutdoorRoute(sgwCoord, loyolaBuilding);

      // Assert
      expect(route.startCoordinate, equals(sgwCoord));
      expect(route.destinationBuilding.campus, equals(Campus.loyola));
      expect(route.estimatedDistanceMeters, greaterThan(1000));
    });

    test("createOutdoorRoute handles coordinates at extreme latitudes", () {
      // Arrange - North pole to equator (extreme case)
      const northPole = Coordinate(latitude: 89.0, longitude: 0.0);
      final equatorBuilding = createTestBuilding(
        id: "test",
        name: "Equator Building",
        location: const Coordinate(latitude: 0.0, longitude: 0.0),
        campus: Campus.sgw,
      );

      // Act
      final route = interactor.createOutdoorRoute(northPole, equatorBuilding);

      // Assert - Should be approximately 9,890 km (Earth"s quarter circumference)
      expect(route.estimatedDistanceMeters, greaterThan(9800000));
      expect(route.estimatedDistanceMeters, lessThan(10000000));
    });
  });
}
