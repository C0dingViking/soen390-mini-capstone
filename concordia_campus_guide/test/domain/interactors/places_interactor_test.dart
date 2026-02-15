import "package:concordia_campus_guide/data/services/places_service.dart";
import "package:concordia_campus_guide/domain/interactors/places_interactor.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "places_interactor_test.mocks.dart";

@GenerateMocks([PlacesService])
void main() {
  group("PlacesInteractor", () {
    late MockPlacesService mockService;
    late PlacesInteractor interactor;

    setUp(() {
      mockService = MockPlacesService();
      interactor = PlacesInteractor(service: mockService);
    });

    group("constructor", () {
      test("initializes with provided service", () {
        final customService = MockPlacesService();
        final customInteractor = PlacesInteractor(service: customService);

        expect(customInteractor, isNotNull);
      });

      test("creates default PlacesService when none provided", () {
        final defaultInteractor = PlacesInteractor(service: null);

        expect(defaultInteractor, isNotNull);
      });
    });

    group("searchPlaces", () {
      test("calls fetchAutocomplete with query", () async {
        final suggestions = <PlaceSuggestion>[];
        when(mockService.fetchAutocomplete("hall"))
            .thenAnswer((_) async => suggestions);

        await interactor.searchPlaces("hall");

        verify(mockService.fetchAutocomplete("hall")).called(1);
      });

      test("returns results from service", () async {
        final suggestions = [
          PlaceSuggestion(
            placeId: "place-1",
            description: "Hall Building",
            mainText: "Hall Building",
            secondaryText: "Montreal",
          ),
          PlaceSuggestion(
            placeId: "place-2",
            description: "Hall Park",
            mainText: "Hall Park",
            secondaryText: "Montreal",
          ),
        ];
        when(mockService.fetchAutocomplete("hall"))
            .thenAnswer((_) async => suggestions);

        final result = await interactor.searchPlaces("hall");

        expect(result, suggestions);
        expect(result.length, 2);
        expect(result.first.placeId, "place-1");
        expect(result.last.placeId, "place-2");
      });

      test("returns empty list when no suggestions found", () async {
        when(mockService.fetchAutocomplete("xyz"))
            .thenAnswer((_) async => []);

        final result = await interactor.searchPlaces("xyz");

        expect(result, isEmpty);
      });

      test("propagates exceptions from service", () async {
        when(mockService.fetchAutocomplete("error"))
            .thenThrow(Exception("API error"));

        expect(
          () => interactor.searchPlaces("error"),
          throwsException,
        );
      });

      test("handles empty query string", () async {
        when(mockService.fetchAutocomplete(""))
            .thenAnswer((_) async => []);

        final result = await interactor.searchPlaces("");

        expect(result, isEmpty);
        verify(mockService.fetchAutocomplete("")).called(1);
      });
    });

    group("resolvePlace", () {
      test("calls fetchPlaceCoordinate with placeId", () async {
        when(mockService.fetchPlaceCoordinate("place-1"))
            .thenAnswer((_) async => null);

        await interactor.resolvePlace("place-1");

        verify(mockService.fetchPlaceCoordinate("place-1")).called(1);
      });

      test("returns coordinate from service", () async {
        final coordinate = Coordinate(latitude: 45.497, longitude: -73.578);
        when(mockService.fetchPlaceCoordinate("place-1"))
            .thenAnswer((_) async => coordinate);

        final result = await interactor.resolvePlace("place-1");

        expect(result, coordinate);
        expect(result!.latitude, 45.497);
        expect(result.longitude, -73.578);
      });

      test("returns null when coordinate not found", () async {
        when(mockService.fetchPlaceCoordinate("unknown"))
            .thenAnswer((_) async => null);

        final result = await interactor.resolvePlace("unknown");

        expect(result, isNull);
      });

      test("propagates exceptions from service", () async {
        when(mockService.fetchPlaceCoordinate("error"))
            .thenThrow(Exception("Coordinate resolution failed"));

        expect(
          () => interactor.resolvePlace("error"),
          throwsException,
        );
      });

      test("handles empty placeId", () async {
        when(mockService.fetchPlaceCoordinate(""))
            .thenAnswer((_) async => null);

        final result = await interactor.resolvePlace("");

        expect(result, isNull);
        verify(mockService.fetchPlaceCoordinate("")).called(1);
      });
    });

    group("resolvePlaceSuggestion", () {
      test("calls fetchPlaceCoordinate with placeId and description", () async {
        final suggestion = PlaceSuggestion(
          placeId: "place-1",
          description: "Hall Building, Montreal",
          mainText: "Hall Building",
          secondaryText: "Montreal",
        );
        when(mockService.fetchPlaceCoordinate(
          "place-1",
          fallbackQuery: "Hall Building, Montreal",
        )).thenAnswer((_) async => null);

        await interactor.resolvePlaceSuggestion(suggestion);

        verify(mockService.fetchPlaceCoordinate(
          "place-1",
          fallbackQuery: "Hall Building, Montreal",
        )).called(1);
      });

      test("returns coordinate from service", () async {
        final suggestion = PlaceSuggestion(
          placeId: "place-1",
          description: "Hall Building",
          mainText: "Hall Building",
          secondaryText: "Montreal",
        );
        final coordinate = Coordinate(latitude: 45.497, longitude: -73.578);
        when(mockService.fetchPlaceCoordinate(
          "place-1",
          fallbackQuery: "Hall Building",
        )).thenAnswer((_) async => coordinate);

        final result = await interactor.resolvePlaceSuggestion(suggestion);

        expect(result, coordinate);
        expect(result!.latitude, 45.497);
      });

      test("returns null when coordinate not found", () async {
        final suggestion = PlaceSuggestion(
          placeId: "unknown",
          description: "Unknown Place",
          mainText: "Unknown",
          secondaryText: "Place",
        );
        when(mockService.fetchPlaceCoordinate(
          "unknown",
          fallbackQuery: "Unknown Place",
        )).thenAnswer((_) async => null);

        final result = await interactor.resolvePlaceSuggestion(suggestion);

        expect(result, isNull);
      });

      test("passes description as fallbackQuery", () async {
        final suggestion = PlaceSuggestion(
          placeId: "place-123",
          description: "Custom Description For Fallback",
          mainText: "Main Text",
          secondaryText: "Secondary",
        );
        final coordinate = Coordinate(latitude: 48.0, longitude: -74.0);
        when(mockService.fetchPlaceCoordinate(
          "place-123",
          fallbackQuery: "Custom Description For Fallback",
        )).thenAnswer((_) async => coordinate);

        final result = await interactor.resolvePlaceSuggestion(suggestion);

        expect(result, coordinate);
        verify(mockService.fetchPlaceCoordinate(
          "place-123",
          fallbackQuery: "Custom Description For Fallback",
        )).called(1);
      });

      test("propagates exceptions from service", () async {
        final suggestion = PlaceSuggestion(
          placeId: "place-1",
          description: "Hall",
          mainText: "Hall",
          secondaryText: "",
        );
        when(mockService.fetchPlaceCoordinate(
          "place-1",
          fallbackQuery: "Hall",
        )).thenThrow(Exception("Resolution failed"));

        expect(
          () => interactor.resolvePlaceSuggestion(suggestion),
          throwsException,
        );
      });

      test("handles suggestion with empty description", () async {
        final suggestion = PlaceSuggestion(
          placeId: "place-1",
          description: "",
          mainText: "Place",
          secondaryText: "",
        );
        when(mockService.fetchPlaceCoordinate(
          "place-1",
          fallbackQuery: "",
        )).thenAnswer((_) async => null);

        final result = await interactor.resolvePlaceSuggestion(suggestion);

        expect(result, isNull);
        verify(mockService.fetchPlaceCoordinate(
          "place-1",
          fallbackQuery: "",
        )).called(1);
      });

      test("handles suggestion with empty placeId", () async {
        final suggestion = PlaceSuggestion(
          placeId: "",
          description: "Hall Building",
          mainText: "Hall Building",
          secondaryText: "Montreal",
        );
        when(mockService.fetchPlaceCoordinate(
          "",
          fallbackQuery: "Hall Building",
        )).thenAnswer((_) async => null);

        final result = await interactor.resolvePlaceSuggestion(suggestion);

        expect(result, isNull);
      });
    });
  });
}
