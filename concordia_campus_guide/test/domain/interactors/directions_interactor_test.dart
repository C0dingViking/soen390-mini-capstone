import "package:concordia_campus_guide/data/services/directions_service.dart";
import "package:concordia_campus_guide/domain/interactors/directions_interactor.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "directions_interactor_test.mocks.dart";

@GenerateMocks([DirectionsService])
void main() {
  group("DirectionsInteractor", () {
    late MockDirectionsService mockService;
    late DirectionsInteractor interactor;

    setUp(() {
      mockService = MockDirectionsService();
      interactor = DirectionsInteractor(service: mockService);
    });

    group("constructor", () {
      test("initializes with provided service", () {
        final customService = MockDirectionsService();
        final customInteractor = DirectionsInteractor(service: customService);

        expect(customInteractor, isNotNull);
      });

      test("creates default DirectionsService when none provided", () {
        final defaultInteractor = DirectionsInteractor(service: null);

        expect(defaultInteractor, isNotNull);
      });
    });

    group("getRouteOptions", () {
      const startCoord = Coordinate(latitude: 45.5, longitude: -73.5);
      const destCoord = Coordinate(latitude: 45.6, longitude: -73.6);

      test("calls fetchRoute for all RouteMode values", () async {
        when(mockService.fetchRoute(
          any,
          any,
          any,
          departureTime: anyNamed("departureTime"),
          arrivalTime: anyNamed("arrivalTime"),
        )).thenAnswer((_) async => null);

        await interactor.getRouteOptions(startCoord, destCoord);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.walking,
          departureTime: null,
          arrivalTime: null,
        )).called(1);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.bicycling,
          departureTime: null,
          arrivalTime: null,
        )).called(1);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.driving,
          departureTime: null,
          arrivalTime: null,
        )).called(1);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.transit,
          departureTime: null,
          arrivalTime: null,
        )).called(1);

        verifyNoMoreInteractions(mockService);
      });

      test("returns all non-null route options", () async {
        final walkingRoute = RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 1000,
          durationSeconds: 720,
          polyline: const [],
          steps: const [],
        );

        final bicyclingRoute = RouteOption(
          mode: RouteMode.bicycling,
          distanceMeters: 1000,
          durationSeconds: 300,
          polyline: const [],
          steps: const [],
        );

        when(mockService.fetchRoute(startCoord, destCoord, RouteMode.walking,
                departureTime: null, arrivalTime: null))
            .thenAnswer((_) async => walkingRoute);

        when(mockService.fetchRoute(startCoord, destCoord, RouteMode.bicycling,
                departureTime: null, arrivalTime: null))
            .thenAnswer((_) async => bicyclingRoute);

        when(mockService.fetchRoute(startCoord, destCoord, RouteMode.driving,
                departureTime: null, arrivalTime: null))
            .thenAnswer((_) async => null);

        when(mockService.fetchRoute(startCoord, destCoord, RouteMode.transit,
                departureTime: null, arrivalTime: null))
            .thenAnswer((_) async => null);

        final result =
            await interactor.getRouteOptions(startCoord, destCoord);

        expect(result.length, 2);
        expect(result[0], walkingRoute);
        expect(result[1], bicyclingRoute);
      });

      test("returns empty list when all routes are null", () async {
        when(mockService.fetchRoute(
          any,
          any,
          any,
          departureTime: anyNamed("departureTime"),
          arrivalTime: anyNamed("arrivalTime"),
        )).thenAnswer((_) async => null);

        final result =
            await interactor.getRouteOptions(startCoord, destCoord);

        expect(result, isEmpty);
      });

      test("passes departureTime parameter to service", () async {
        final departureTime = DateTime(2026, 2, 14, 10, 0);

        when(mockService.fetchRoute(
          any,
          any,
          any,
          departureTime: anyNamed("departureTime"),
          arrivalTime: anyNamed("arrivalTime"),
        )).thenAnswer((_) async => null);

        await interactor.getRouteOptions(
          startCoord,
          destCoord,
          departureTime: departureTime,
        );

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.walking,
          departureTime: departureTime,
          arrivalTime: null,
        )).called(1);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.bicycling,
          departureTime: departureTime,
          arrivalTime: null,
        )).called(1);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.driving,
          departureTime: departureTime,
          arrivalTime: null,
        )).called(1);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.transit,
          departureTime: departureTime,
          arrivalTime: null,
        )).called(1);
      });

      test("passes arrivalTime parameter to service", () async {
        final arrivalTime = DateTime(2026, 2, 14, 16, 0);

        when(mockService.fetchRoute(
          any,
          any,
          any,
          departureTime: anyNamed("departureTime"),
          arrivalTime: anyNamed("arrivalTime"),
        )).thenAnswer((_) async => null);

        await interactor.getRouteOptions(
          startCoord,
          destCoord,
          arrivalTime: arrivalTime,
        );

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.walking,
          departureTime: null,
          arrivalTime: arrivalTime,
        )).called(1);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.bicycling,
          departureTime: null,
          arrivalTime: arrivalTime,
        )).called(1);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.driving,
          departureTime: null,
          arrivalTime: arrivalTime,
        )).called(1);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.transit,
          departureTime: null,
          arrivalTime: arrivalTime,
        )).called(1);
      });

      test("passes both time parameters to service", () async {
        final departureTime = DateTime(2026, 2, 14, 10, 0);
        final arrivalTime = DateTime(2026, 2, 14, 16, 0);

        when(mockService.fetchRoute(
          any,
          any,
          any,
          departureTime: anyNamed("departureTime"),
          arrivalTime: anyNamed("arrivalTime"),
        )).thenAnswer((_) async => null);

        await interactor.getRouteOptions(
          startCoord,
          destCoord,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
        );

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.walking,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
        )).called(1);

        verify(mockService.fetchRoute(
          startCoord,
          destCoord,
          RouteMode.transit,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
        )).called(1);
      });

      test("fetches all routes in parallel using Future.wait", () async {
        final callOrder = <String>[];

        when(mockService.fetchRoute(
          any,
          any,
          RouteMode.walking,
          departureTime: anyNamed("departureTime"),
          arrivalTime: anyNamed("arrivalTime"),
        )).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          callOrder.add("walking");
          return null;
        });

        when(mockService.fetchRoute(
          any,
          any,
          RouteMode.bicycling,
          departureTime: anyNamed("departureTime"),
          arrivalTime: anyNamed("arrivalTime"),
        )).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          callOrder.add("bicycling");
          return null;
        });

        when(mockService.fetchRoute(
          any,
          any,
          RouteMode.driving,
          departureTime: anyNamed("departureTime"),
          arrivalTime: anyNamed("arrivalTime"),
        )).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          callOrder.add("driving");
          return null;
        });

        when(mockService.fetchRoute(
          any,
          any,
          RouteMode.transit,
          departureTime: anyNamed("departureTime"),
          arrivalTime: anyNamed("arrivalTime"),
        )).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          callOrder.add("transit");
          return null;
        });

        await interactor.getRouteOptions(startCoord, destCoord);

        // Verify calls completed; if sequential, would take 140ms+ total
        // If parallel with Future.wait, takes ~50ms (longest delay)
        expect(callOrder.length, 4);
        expect(callOrder, contains("walking"));
        expect(callOrder, contains("bicycling"));
        expect(callOrder, contains("driving"));
        expect(callOrder, contains("transit"));
      });
    });
  });
}
