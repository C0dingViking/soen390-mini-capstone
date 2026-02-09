import "package:flutter_test/flutter_test.dart";
import "package:mockito/mockito.dart";
import "package:mockito/annotations.dart";
import "package:concordia_campus_guide/ui/directions/view_models/directions_view_model.dart";
import "package:concordia_campus_guide/domain/interactors/route_interactor.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/route.dart";
import "package:concordia_campus_guide/data/services/location_service.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_google_maps_webservices/places.dart";

@GenerateMocks([RouteInteractor])
import "directions_view_model_test.mocks.dart";

void main() {
  
  TestWidgetsFlutterBinding.ensureInitialized();
  group("DirectionsViewModel", () {
    late DirectionsViewModel viewModel;
    late MockRouteInteractor mockRouteInteractor;
    late Building testBuilding;

    setUp(() {
      mockRouteInteractor = MockRouteInteractor();
      viewModel = DirectionsViewModel(routeInteractor: mockRouteInteractor);
      
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

    tearDown(() {
      viewModel.dispose();
      LocationService.resetForTesting();
    });

    test("initial state is correct", () {
      expect(viewModel.currentLocationCoordinate, isNull);
      expect(viewModel.destinationBuilding, isNull);
      expect(viewModel.plannedRoute, isNull);
      expect(viewModel.isLoadingLocation, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.canGetDirections, isFalse);
    });

    test("updateDestination sets destination building", () {
      // Act
      viewModel.updateDestination(testBuilding);

      // Assert
      expect(viewModel.destinationBuilding, equals(testBuilding));
      expect(viewModel.plannedRoute, isNull); // No route yet without start location
    });

    test("updateDestination creates route when start location is set", () {
      // Arrange
      const startCoord = Coordinate(latitude: 45.4972, longitude: -73.5786);
      final expectedRoute = DirectionRoute(
        startCoordinate: startCoord,
        destinationBuilding: testBuilding,
        estimatedDistanceMeters: 100.0,
      );
      
      when(mockRouteInteractor.createOutdoorRoute(startCoord, testBuilding))
          .thenReturn(expectedRoute);

      viewModel.currentLocationCoordinate = startCoord;

      // Act
      viewModel.updateDestination(testBuilding);

      // Assert
      expect(viewModel.plannedRoute, isNotNull);
      expect(viewModel.plannedRoute?.startCoordinate, equals(startCoord));
      expect(viewModel.plannedRoute?.destinationBuilding, equals(testBuilding));
      expect(viewModel.plannedRoute?.estimatedDistanceMeters, equals(100.0));
      verify(mockRouteInteractor.createOutdoorRoute(startCoord, testBuilding)).called(1);
    });

    test("clearStartLocation resets location and route", () {
      // Arrange
      const startCoord = Coordinate(latitude: 45.4972, longitude: -73.5786);
      final route = DirectionRoute(
        startCoordinate: startCoord,
        destinationBuilding: testBuilding,
        estimatedDistanceMeters: 100.0,
      );
      
      when(mockRouteInteractor.createOutdoorRoute(startCoord, testBuilding))
          .thenReturn(route);
      
      viewModel.currentLocationCoordinate = startCoord;
      viewModel.updateDestination(testBuilding);
      expect(viewModel.plannedRoute, isNotNull);

      // Act
      viewModel.clearStartLocation();

      // Assert
      expect(viewModel.currentLocationCoordinate, isNull);
      expect(viewModel.plannedRoute, isNull);
    });

    test("canGetDirections returns true when both location and destination are set", () {
      // Arrange
      const startCoord = Coordinate(latitude: 45.4972, longitude: -73.5786);
      final route = DirectionRoute(
        startCoordinate: startCoord,
        destinationBuilding: testBuilding,
        estimatedDistanceMeters: 100.0,
      );
      
      when(mockRouteInteractor.createOutdoorRoute(startCoord, testBuilding))
          .thenReturn(route);
      
      viewModel.currentLocationCoordinate = startCoord;
      viewModel.updateDestination(testBuilding);

      // Assert
      expect(viewModel.canGetDirections, isTrue);
    });

    test("canGetDirections returns false when location is missing", () {
      // Arrange
      viewModel.updateDestination(testBuilding);

      // Assert
      expect(viewModel.canGetDirections, isFalse);
    });

    test("canGetDirections returns false when destination is missing", () {
      // Arrange
      viewModel.currentLocationCoordinate = const Coordinate(latitude: 45.4972, longitude: -73.5786);

      // Assert
      expect(viewModel.canGetDirections, isFalse);
    });

    test("useCurrentLocation sets error message on location service failure", () async {
  // Arrange
  expect(viewModel.errorMessage, isNull, reason: "Should start with no error");
  expect(viewModel.isLoadingLocation, isFalse, reason: "Should start not loading");

  // Act
  await viewModel.useCurrentLocation();
  
  // Small delay to ensure all async operations complete
  await Future<void>.delayed(const Duration(milliseconds: 50));

  // Assert
  expect(viewModel.isLoadingLocation, isFalse, reason: "Loading should be false after completion");
  expect(viewModel.currentLocationCoordinate, isNull, reason: "Coordinate should be null on error");
  expect(viewModel.errorMessage, isNotNull, reason: "Error message should be set");
  
  // More flexible error message check
  if (viewModel.errorMessage != null) {
    expect(
      viewModel.errorMessage!.toLowerCase(),
      anyOf([
        contains("unable"),
        contains("error"),
        contains("failed"),
        contains("location"),
      ]),
      reason: "Error message should indicate a location problem",
    );
  }
});

  test("updateDestination notifies listeners exactly once", () {
      var count = 0;
      viewModel.addListener(() => count++);

      viewModel.updateDestination(testBuilding);

      expect(count, equals(1));
  });
  
  test("clearStartLocation notifies listeners exactly once", () {
      var count = 0;
      viewModel.addListener(() => count++);

      viewModel.clearStartLocation();

     expect(count, equals(1));
});


    test("updating location triggers route recalculation", () {
      // Arrange
      const coord1 = Coordinate(latitude: 45.4972, longitude: -73.5786);
      const coord2 = Coordinate(latitude: 45.4980, longitude: -73.5800);
      
      final route1 = DirectionRoute(
        startCoordinate: coord1,
        destinationBuilding: testBuilding,
        estimatedDistanceMeters: 100.0,
      );
      
      final route2 = DirectionRoute(
        startCoordinate: coord2,
        destinationBuilding: testBuilding,
        estimatedDistanceMeters: 200.0,
      );
      
      when(mockRouteInteractor.createOutdoorRoute(coord1, testBuilding))
          .thenReturn(route1);
      when(mockRouteInteractor.createOutdoorRoute(coord2, testBuilding))
          .thenReturn(route2);

      viewModel.updateDestination(testBuilding);
      viewModel.currentLocationCoordinate = coord1;
      viewModel.updateDestination(testBuilding); // Trigger route creation
      
      expect(viewModel.plannedRoute?.estimatedDistanceMeters, equals(100.0));

      // Act - Change location
      viewModel.currentLocationCoordinate = coord2;
      viewModel.updateDestination(testBuilding); // Trigger route recalculation

      // Assert
      expect(viewModel.plannedRoute?.estimatedDistanceMeters, equals(200.0));
      verify(mockRouteInteractor.createOutdoorRoute(coord1, testBuilding)).called(1);
      verify(mockRouteInteractor.createOutdoorRoute(coord2, testBuilding)).called(1);
    });

    test("clearing destination removes route", () {
      // Arrange
      const startCoord = Coordinate(latitude: 45.4972, longitude: -73.5786);
      final route = DirectionRoute(
        startCoordinate: startCoord,
        destinationBuilding: testBuilding,
        estimatedDistanceMeters: 100.0,
      );
      
      when(mockRouteInteractor.createOutdoorRoute(startCoord, testBuilding))
          .thenReturn(route);
      
      viewModel.currentLocationCoordinate = startCoord;
      viewModel.updateDestination(testBuilding);
      expect(viewModel.plannedRoute, isNotNull);

      // Act - Set destination to a different building, then clear it
      viewModel.destinationBuilding = null;
      viewModel.currentLocationCoordinate = startCoord;
      viewModel.updateDestination(testBuilding);

      // Assert
      expect(viewModel.canGetDirections, isFalse);
    });
  });
}
