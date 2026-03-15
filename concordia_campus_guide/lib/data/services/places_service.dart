import "dart:math" as math;

import "package:concordia_campus_guide/data/services/api_key_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:flutter_google_maps_webservices/places.dart";

class PlacesService {
  GoogleMapsPlaces? _places;
  final ApiKeyService _apiKeyService;
  String? _resolvedKey;

  PlacesService({final GoogleMapsPlaces? client, final ApiKeyService? apiKeyService})
    : _places = client,
      _apiKeyService = apiKeyService ?? ApiKeyService();

  Future<String?> _getApiKey() async {
    if (_resolvedKey != null) return _resolvedKey;

    final key = await _apiKeyService.getGoogleMapsApiKey();
    _resolvedKey = (key != null && key.trim().isNotEmpty) ? key : null;
    return _resolvedKey;
  }

  Future<GoogleMapsPlaces?> _getClient() async {
    if (_places != null) return _places;
    final key = await _getApiKey();
    if (key == null || key.isEmpty) return null;
    _places = GoogleMapsPlaces(apiKey: key);
    return _places;
  }

  Future<List<PlaceSuggestion>> fetchAutocomplete(final String input) async {
    final client = await _getClient();
    if (client == null) return [];

    try {
      final response = await client.autocomplete(
        input,
        language: "en",
        components: [Component(Component.country, "ca")],
        location: Location(lat: 45.4972, lng: -73.5786),
        radius: 25000,
      );

      if (!response.isOkay) return [];

      return response.predictions
          .map((final prediction) {
            final structured = prediction.structuredFormatting;
            return PlaceSuggestion(
              placeId: prediction.placeId ?? "",
              description: prediction.description ?? "",
              mainText: structured?.mainText ?? prediction.description ?? "",
              secondaryText: structured?.secondaryText ?? "",
              source: PlaceSuggestionSource.autocomplete,
            );
          })
          .where((final suggestion) => suggestion.placeId.isNotEmpty)
          .toList();
    } catch (e) {
      logger.w("PlacesService: autocomplete failed", error: e);
      return [];
    }
  }

  Future<List<PlaceSuggestion>> fetchNearbyPlaces(
    final String input,
    final Coordinate origin, {
    final int maxResults = 5,
  }) async {
    final client = await _getClient();
    if (client == null) return [];

    final trimmed = input.trim();
    if (trimmed.isEmpty || maxResults <= 0) return [];

    try {
      final response = await client.searchNearbyWithRankBy(
        Location(lat: origin.latitude, lng: origin.longitude),
        "distance",
        keyword: trimmed,
        language: "en",
      );

      if (!response.isOkay) return [];

      return response.results
          .map((final result) {
            final location = result.geometry?.location;
            if (location == null) {
              return null;
            }

            final coordinate = Coordinate(latitude: location.lat, longitude: location.lng);
            final name = result.name;
            final secondaryText = result.vicinity ?? result.formattedAddress ?? "";
            final description = secondaryText.isEmpty ? name : "$name, $secondaryText";

            return PlaceSuggestion(
              placeId: result.placeId,
              description: description,
              mainText: name,
              secondaryText: secondaryText,
              coordinate: coordinate,
              distanceMeters: _distanceBetween(origin, coordinate),
              source: PlaceSuggestionSource.nearby,
            );
          })
          .whereType<PlaceSuggestion>()
          .take(maxResults)
          .toList();
    } catch (e) {
      logger.w("PlacesService: nearby search failed", error: e);
      return [];
    }
  }

  Future<Coordinate?> fetchPlaceCoordinate(
    final String placeId, {
    final String? fallbackQuery,
  }) async {
    final client = await _getClient();
    if (client == null || placeId.isEmpty) return null;

    try {
      final details = await client.getDetailsByPlaceId(placeId, fields: const ["geometry"]);

      if (details.isOkay) {
        final location = details.result.geometry?.location;
        if (location != null) {
          return Coordinate(latitude: location.lat, longitude: location.lng);
        }
      }
    } catch (e) {
      logger.w("PlacesService: getDetailsByPlaceId failed", error: e);
    }

    if (fallbackQuery == null || fallbackQuery.trim().isEmpty) {
      return null;
    }

    try {
      final textResponse = await client.searchByText(
        fallbackQuery.trim(),
        language: "en",
        location: Location(lat: 45.4972, lng: -73.5786),
        radius: 25000,
      );

      if (!textResponse.isOkay || textResponse.results.isEmpty) return null;

      final location = textResponse.results.first.geometry?.location;
      if (location == null) return null;

      return Coordinate(latitude: location.lat, longitude: location.lng);
    } catch (e) {
      logger.w("PlacesService: both place details and text search failed", error: e);
      return null;
    }
  }

  double _distanceBetween(final Coordinate origin, final Coordinate destination) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _degreesToRadians(origin.latitude);
    final lat2 = _degreesToRadians(destination.latitude);
    final deltaLat = _degreesToRadians(destination.latitude - origin.latitude);
    final deltaLng = _degreesToRadians(destination.longitude - origin.longitude);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  double _degreesToRadians(final double degrees) {
    return degrees * math.pi / 180;
  }
}
