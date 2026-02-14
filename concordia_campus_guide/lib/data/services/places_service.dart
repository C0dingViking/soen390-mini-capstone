import "package:concordia_campus_guide/data/services/api_key_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:flutter_google_maps_webservices/places.dart";

class PlacesService {
  GoogleMapsPlaces? _places;
  final ApiKeyService _apiKeyService;
  String? _resolvedKey;
  Future<String?>? _keyLookup;

  PlacesService({GoogleMapsPlaces? client, ApiKeyService? apiKeyService})
      : _places = client,
        _apiKeyService = apiKeyService ?? ApiKeyService();

  Future<String?> _getApiKey() async {
    if (_resolvedKey != null) return _resolvedKey;

    _keyLookup ??= _apiKeyService.getGoogleMapsApiKey();
    final key = await _keyLookup;
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

      return response.predictions.map((final prediction) {
        final structured = prediction.structuredFormatting;
        return PlaceSuggestion(
          placeId: prediction.placeId ?? "",
          description: prediction.description ?? "",
          mainText: structured?.mainText ?? prediction.description ?? "",
          secondaryText: structured?.secondaryText ?? "",
        );
      }).where((final suggestion) => suggestion.placeId.isNotEmpty).toList();
    } catch (e) {
      logger.w("PlacesService: autocomplete failed", error: e);
      return [];
    }
  }

  Future<Coordinate?> fetchPlaceCoordinate(final String placeId) async {
    final client = await _getClient();
    if (client == null || placeId.isEmpty) return null;

    try {
      final details = await client.getDetailsByPlaceId(
        placeId,
        fields: ["geometry", "name", "formatted_address"],
      );

      if (!details.isOkay) return null;

      final location = details.result.geometry?.location;
      if (location == null) return null;

      return Coordinate(latitude: location.lat, longitude: location.lng);
    } catch (e) {
      logger.w("PlacesService: details lookup failed", error: e);
      return null;
    }
  }
}
