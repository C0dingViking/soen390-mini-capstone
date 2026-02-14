import "package:concordia_campus_guide/data/services/api_key_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:concordia_campus_guide/utils/polyline_decoder.dart";
import "package:flutter_google_maps_webservices/directions.dart";

class DirectionsService {
  GoogleMapsDirections? _directions;
  final ApiKeyService _apiKeyService;
  String? _resolvedKey;
  Future<String?>? _keyLookup;

  DirectionsService({GoogleMapsDirections? client, ApiKeyService? apiKeyService})
      : _directions = client,
        _apiKeyService = apiKeyService ?? ApiKeyService();

  Future<String?> _getApiKey() async {
    if (_resolvedKey != null) return _resolvedKey;

    _keyLookup ??= _apiKeyService.getGoogleMapsApiKey();
    final key = await _keyLookup;
    _resolvedKey = (key != null && key.trim().isNotEmpty) ? key : null;
    return _resolvedKey;
  }

  Future<GoogleMapsDirections?> _getClient() async {
    if (_directions != null) return _directions;
    final key = await _getApiKey();
    if (key == null || key.isEmpty) return null;
    _directions = GoogleMapsDirections(apiKey: key);
    return _directions;
  }

  Future<RouteOption?> fetchRoute(
    final Coordinate start,
    final Coordinate destination,
    final RouteMode mode,
  ) async {
    final client = await _getClient();
    if (client == null) return null;

    try {
      final response = await client.directionsWithLocation(
        Location(lat: start.latitude, lng: start.longitude),
        Location(lat: destination.latitude, lng: destination.longitude),
        travelMode: _toTravelMode(mode),
        transitMode:
            mode == RouteMode.transit ? [TransitMode.subway] : const [],
      );

      if (!response.isOkay || response.routes.isEmpty) {
        logger.w(
          "DirectionsService: route request failed",
          error: response.errorMessage ?? response.status,
        );
        return null;
      }

      final route = response.routes.first;
      final leg = route.legs.isNotEmpty ? route.legs.first : null;
      final encoded = route.overviewPolyline?.points ?? "";
        final polyline =
          encoded.isNotEmpty ? decodePolyline(encoded) : <Coordinate>[];

      return RouteOption(
        mode: mode,
        distanceMeters: leg?.distance?.value?.toDouble(),
        durationSeconds: leg?.duration?.value?.toInt(),
        polyline: polyline,
      );
    } catch (e) {
      logger.w("DirectionsService: route request failed", error: e);
      return null;
    }
  }

  TravelMode _toTravelMode(final RouteMode mode) {
    switch (mode) {
      case RouteMode.walking:
        return TravelMode.walking;
      case RouteMode.bicycling:
        return TravelMode.bicycling;
      case RouteMode.driving:
        return TravelMode.driving;
      case RouteMode.transit:
        return TravelMode.transit;
    }
  }
}
