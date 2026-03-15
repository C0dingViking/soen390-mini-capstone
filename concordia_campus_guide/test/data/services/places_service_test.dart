import "package:concordia_campus_guide/data/services/api_key_service.dart";
import "package:concordia_campus_guide/data/services/places_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:flutter_google_maps_webservices/places.dart" as gmw;
import "package:flutter_test/flutter_test.dart";

class _FakeApiKeyService extends ApiKeyService {
  _FakeApiKeyService(this.value);

  final String? value;

  @override
  Future<String?> getGoogleMapsApiKey() async => value;
}

class _FakeGoogleMapsPlaces extends gmw.GoogleMapsPlaces {
  gmw.PlacesAutocompleteResponse? _autocompleteResp;
  gmw.PlacesDetailsResponse? _detailsResp;
  gmw.PlacesSearchResponse? _searchResp;
  gmw.PlacesSearchResponse? _nearbyResp;
  Exception? _autocompleteError;
  Exception? _detailsError;
  Exception? _searchError;
  Exception? _nearbyError;

  _FakeGoogleMapsPlaces() : super(apiKey: "fake-key");

  void setAutocompleteResponse(
    final gmw.PlacesAutocompleteResponse? resp, {
    final Exception? error,
  }) {
    _autocompleteResp = resp;
    _autocompleteError = error;
  }

  void setDetailsResponse(
    final gmw.PlacesDetailsResponse? resp, {
    final Exception? error,
  }) {
    _detailsResp = resp;
    _detailsError = error;
  }

  void setSearchResponse(
    final gmw.PlacesSearchResponse? resp, {
    final Exception? error,
  }) {
    _searchResp = resp;
    _searchError = error;
  }

  void setNearbyResponse(
    final gmw.PlacesSearchResponse? resp, {
    final Exception? error,
  }) {
    _nearbyResp = resp;
    _nearbyError = error;
  }

  @override
  Future<gmw.PlacesAutocompleteResponse> autocomplete(
    final String input, {
    final String? language,
    final List<gmw.Component>? components,
    final gmw.Location? location,
    final num? radius,
    final num? offset,
    final gmw.Location? origin,
    final String? sessionToken,
    final List<String>? types,
    final bool? strictbounds,
    final String? region,
  }) async {
    if (_autocompleteError != null) throw _autocompleteError!;
    return _autocompleteResp ?? gmw.PlacesAutocompleteResponse.fromJson({});
  }

  @override
  Future<gmw.PlacesDetailsResponse> getDetailsByPlaceId(
    final String placeId, {
    final List<String>? fields,
    final String? sessionToken,
    final String? language,
    final String? region,
  }) async {
    if (_detailsError != null) throw _detailsError!;
    return _detailsResp ?? gmw.PlacesDetailsResponse.fromJson({});
  }

  @override
  Future<gmw.PlacesSearchResponse> searchByText(
    final String query, {
    final String? language,
    final gmw.Location? location,
    final num? radius,
    final gmw.PriceLevel? minprice,
    final gmw.PriceLevel? maxprice,
    final bool? opennow,
    final String? pagetoken,
    final String? type,
    final String? region,
  }) async {
    if (_searchError != null) throw _searchError!;
    return _searchResp ?? gmw.PlacesSearchResponse.fromJson({});
  }

  @override
  Future<gmw.PlacesSearchResponse> searchNearbyWithRankBy(
    final gmw.Location location,
    final String rankby, {
    final String? type,
    final String? keyword,
    final String? language,
    final gmw.PriceLevel? minprice,
    final gmw.PriceLevel? maxprice,
    final String? name,
    final String? pagetoken,
  }) async {
    if (_nearbyError != null) throw _nearbyError!;
    return _nearbyResp ?? gmw.PlacesSearchResponse.fromJson({});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("PlacesService", () {
    late _FakeGoogleMapsPlaces client;
    late PlacesService service;

    setUp(() {
      client = _FakeGoogleMapsPlaces();
      service = PlacesService(client: client);
    });

    test("fetchAutocomplete returns empty when api key missing", () async {
      final service = PlacesService(apiKeyService: _FakeApiKeyService(null));

      final results = await service.fetchAutocomplete("hall");

      expect(results, isEmpty);
    });

    test("fetchAutocomplete returns empty when response not OK", () async {
      client.setAutocompleteResponse(
        gmw.PlacesAutocompleteResponse.fromJson({
          "status": "ZERO_RESULTS",
          "predictions": <Map<String, dynamic>>[],
        }),
      );

      final results = await service.fetchAutocomplete("hall");

      expect(results, isEmpty);
    });

    test("fetchAutocomplete maps predictions and filters empty ids", () async {
      client.setAutocompleteResponse(
        gmw.PlacesAutocompleteResponse.fromJson({
          "status": "OK",
          "predictions": [
            {
              "description": "Ignore me",
              "place_id": "",
              "structured_formatting": {
                "main_text": "Ignore",
                "secondary_text": "",
              },
            },
            {
              "description": "Hall Building",
              "place_id": "place-1",
              "structured_formatting": {
                "main_text": "Hall Building",
                "secondary_text": "Montreal",
              },
            },
          ],
        }),
      );

      final results = await service.fetchAutocomplete("hall");

      expect(results.length, 1);
      expect(results.first.placeId, "place-1");
      expect(results.first.mainText, "Hall Building");
      expect(results.first.secondaryText, "Montreal");
      expect(results.first.source, PlaceSuggestionSource.autocomplete);
    });

    test("fetchAutocomplete returns empty on exception", () async {
      client.setAutocompleteResponse(null, error: Exception("boom"));

      final results = await service.fetchAutocomplete("hall");

      expect(results, isEmpty);
    });

    test("fetchNearbyPlaces returns empty when api key missing", () async {
      final service = PlacesService(apiKeyService: _FakeApiKeyService(null));

      final results = await service.fetchNearbyPlaces(
        "restaurant",
        const Coordinate(latitude: 45.497, longitude: -73.578),
      );

      expect(results, isEmpty);
    });

    test("fetchNearbyPlaces maps results and limits response", () async {
      client.setNearbyResponse(
        gmw.PlacesSearchResponse.fromJson({
          "status": "OK",
          "results": [
            {
              "place_id": "nearby-1",
              "reference": "nearby-1",
              "name": "Cafe One",
              "vicinity": "Montreal",
              "icon": "https://example.com/icon.png",
              "types": ["cafe", "food", "point_of_interest", "establishment"],
              "geometry": {
                "location": {"lat": 45.498, "lng": -73.579},
              },
            },
            {
              "place_id": "nearby-2",
              "reference": "nearby-2",
              "name": "Cafe Two",
              "vicinity": "Montreal",
              "icon": "https://example.com/icon.png",
              "types": ["cafe", "food", "point_of_interest", "establishment"],
              "geometry": {
                "location": {"lat": 45.499, "lng": -73.580},
              },
            },
          ],
        }),
      );

      final results = await service.fetchNearbyPlaces(
        "coffee",
        const Coordinate(latitude: 45.497, longitude: -73.578),
        maxResults: 1,
      );

      expect(results.length, 1);
      expect(results.first.placeId, "nearby-1");
      expect(results.first.coordinate, isNotNull);
      expect(results.first.distanceMeters, isNotNull);
      expect(results.first.source, PlaceSuggestionSource.nearby);
    });

    test("fetchNearbyPlaces returns empty on exception", () async {
      client.setNearbyResponse(null, error: Exception("boom"));

      final results = await service.fetchNearbyPlaces(
        "restaurant",
        const Coordinate(latitude: 45.497, longitude: -73.578),
      );

      expect(results, isEmpty);
    });

    test("fetchPlaceCoordinate returns null when no client", () async {
      final service = PlacesService(apiKeyService: _FakeApiKeyService(""));

      final result = await service.fetchPlaceCoordinate("place-1");

      expect(result, isNull);
    });

    test("fetchPlaceCoordinate returns null when place id empty", () async {
      final result = await service.fetchPlaceCoordinate("");

      expect(result, isNull);
    });

    test("fetchPlaceCoordinate uses details result when available", () async {
      client.setDetailsResponse(
        gmw.PlacesDetailsResponse.fromJson({
          "status": "OK",
          "result": {
            "place_id": "place-1",
            "name": "Hall Building",
            "formatted_address": "Montreal",
            "geometry": {
              "location": {"lat": 45.5, "lng": -73.5},
            },
          },
        }),
      );

      final result = await service.fetchPlaceCoordinate("place-1");

      expect(result, isNotNull);
      expect(result!.latitude, 45.5);
      expect(result.longitude, -73.5);
    });

    test("fetchPlaceCoordinate falls back to text search", () async {
      client.setDetailsResponse(
        gmw.PlacesDetailsResponse.fromJson({
          "status": "OK",
          "result": {
            "place_id": "place-1",
            "name": "Hall",
            "formatted_address": "Montreal",
          },
        }),
      );

      client.setSearchResponse(
        gmw.PlacesSearchResponse.fromJson({
          "status": "OK",
          "results": [
            {
              "reference": "place-ref-1",
              "address_components": [
                {
                  "long_name": "Montreal",
                  "short_name": "Montreal",
                  "types": ["locality"],
                },
              ],
              "adr_address": "Montreal",
              "business_status": "OPERATIONAL",
              "formatted_address": "Montreal",
              "geometry": {
                "location": {"lat": 45.6, "lng": -73.6},
              },
              "icon":
                  "https://maps.gstatic.com/mapfiles/place_api/icons/v1/icon1.png",
              "name": "Hall Building",
              "opening_hours": {"open_now": true},
              "photos": <Map<String, dynamic>>[],
              "place_id": "search-result-1",
              "plus_code": {
                "compound_code": "Code",
                "global_code": "GlobalCode",
              },
              "types": ["point_of_interest", "establishment"],
            },
          ],
        }),
      );

      final result = await service.fetchPlaceCoordinate(
        "place-1",
        fallbackQuery: "Hall Building",
      );

      expect(result, isNotNull);
      expect(result!.latitude, 45.6);
      expect(result.longitude, -73.6);
    });

    test("fetchPlaceCoordinate falls back after details exception", () async {
      client.setDetailsResponse(null, error: Exception("details fail"));

      client.setSearchResponse(
        gmw.PlacesSearchResponse.fromJson({
          "status": "OK",
          "results": [
            {
              "reference": "place-ref-2",
              "address_components": [
                {
                  "long_name": "Montreal",
                  "short_name": "Montreal",
                  "types": ["locality"],
                },
              ],
              "adr_address": "Montreal",
              "business_status": "OPERATIONAL",
              "formatted_address": "Montreal",
              "geometry": {
                "location": {"lat": 45.7, "lng": -73.7},
              },
              "icon":
                  "https://maps.gstatic.com/mapfiles/place_api/icons/v1/icon1.png",
              "name": "Hall Building",
              "opening_hours": {"open_now": true},
              "photos": <Map<String, dynamic>>[],
              "place_id": "search-result-1",
              "plus_code": {
                "compound_code": "Code",
                "global_code": "GlobalCode",
              },
              "types": ["point_of_interest"],
            },
          ],
        }),
      );

      final result = await service.fetchPlaceCoordinate(
        "place-1",
        fallbackQuery: "Hall Building",
      );

      expect(result, isNotNull);
      expect(result!.latitude, 45.7);
      expect(result.longitude, -73.7);
    });

    test("fetchPlaceCoordinate returns null without fallback query", () async {
      client.setDetailsResponse(
        gmw.PlacesDetailsResponse.fromJson({
          "status": "ZERO_RESULTS",
          "result": {
            "place_id": "place-1",
            "name": "Not Found",
            "formatted_address": "Unknown",
            "geometry": {
              "location": {"lat": 0.0, "lng": 0.0},
              "bounds": {
                "northeast": {"lat": 0.0, "lng": 0.0},
                "southwest": {"lat": 0.0, "lng": 0.0},
              },
            },
          },
        }),
      );

      final result = await service.fetchPlaceCoordinate("place-1");

      expect(result, isNull);
    });

    test("fetchPlaceCoordinate returns null when text search fails", () async {
      client.setDetailsResponse(
        gmw.PlacesDetailsResponse.fromJson({
          "status": "ZERO_RESULTS",
          "result": {
            "place_id": "place-1",
            "name": "Not Found",
            "formatted_address": "Unknown",
            "geometry": {
              "location": {"lat": 0.0, "lng": 0.0},
              "bounds": {
                "northeast": {"lat": 0.0, "lng": 0.0},
                "southwest": {"lat": 0.0, "lng": 0.0},
              },
            },
          },
        }),
      );

      client.setSearchResponse(
        gmw.PlacesSearchResponse.fromJson({
          "status": "ZERO_RESULTS",
          "results": <Map<String, dynamic>>[],
        }),
      );

      final result = await service.fetchPlaceCoordinate(
        "place-1",
        fallbackQuery: "Hall Building",
      );

      expect(result, isNull);
    });
  });
}
