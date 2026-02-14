import "dart:convert";
import "package:concordia_campus_guide/data/services/api_key_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:concordia_campus_guide/utils/polyline_decoder.dart";
import "package:http/http.dart" as http;

class DirectionsService {
  final ApiKeyService _apiKeyService;
  String? _resolvedKey;
  Future<String?>? _keyLookup;
  final http.Client _httpClient;

  DirectionsService({http.Client? httpClient, ApiKeyService? apiKeyService})
      : _httpClient = httpClient ?? http.Client(),
        _apiKeyService = apiKeyService ?? ApiKeyService();

  Future<String?> _getApiKey() async {
    if (_resolvedKey != null) return _resolvedKey;

    _keyLookup ??= _apiKeyService.getGoogleMapsApiKey();
    final key = await _keyLookup;
    _resolvedKey = (key != null && key.trim().isNotEmpty) ? key : null;
    return _resolvedKey;
  }

  Future<RouteOption?> fetchRoute(
    final Coordinate start,
    final Coordinate destination,
    final RouteMode mode,
  ) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      logger.w("DirectionsService: API key not available");
      return null;
    }

    try {
      final modeString = _toModeString(mode);
      final origin = "${start.latitude},${start.longitude}";
      final dest = "${destination.latitude},${destination.longitude}";
      
      final uri = Uri.https(
        "maps.googleapis.com",
        "/maps/api/directions/json",
        {
          "origin": origin,
          "destination": dest,
          "mode": modeString,
          "key": apiKey,
          if (mode == RouteMode.transit) "transit_mode": "subway",
        },
      );
      
      logger.i(
        "DirectionsService: requesting route with mode=$modeString from $origin to $dest",
      );

      final response = await _httpClient.get(uri);
      
      if (response.statusCode != 200) {
        logger.w(
          "DirectionsService: HTTP error ${response.statusCode}",
          error: response.body,
        );
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data["status"] as String?;
      
      if (status != "OK") {
        logger.w(
          "DirectionsService: route request failed for mode $modeString",
          error: status ?? "Unknown error",
        );
        return null;
      }

      final routes = data["routes"] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        logger.w("DirectionsService: no routes returned for mode $modeString");
        return null;
      }

      final route = routes.first as Map<String, dynamic>;
      final legs = route["legs"] as List<dynamic>?;
      final leg = (legs != null && legs.isNotEmpty) 
          ? legs.first as Map<String, dynamic> 
          : null;
      
      final overviewPolyline = route["overview_polyline"] as Map<String, dynamic>?;
      final encoded = overviewPolyline?["points"] as String? ?? "";
      final polyline = encoded.isNotEmpty ? decodePolyline(encoded) : <Coordinate>[];

      final distance = leg?["distance"] as Map<String, dynamic>?;
      final duration = leg?["duration"] as Map<String, dynamic>?;
      
      logger.i(
        "DirectionsService: successfully parsed route for mode $modeString, "
        "points=${polyline.length}, distance=${distance?["value"]}, duration=${duration?["value"]}",
      );

      return RouteOption(
        mode: mode,
        distanceMeters: (distance?["value"] as num?)?.toDouble(),
        durationSeconds: (duration?["value"] as num?)?.toInt(),
        polyline: polyline,
      );
    } catch (e, stackTrace) {
      logger.w("DirectionsService: route request failed", error: e, stackTrace: stackTrace);
      return null;
    }
  }

  String _toModeString(final RouteMode mode) {
    switch (mode) {
      case RouteMode.walking:
        return "walking";
      case RouteMode.bicycling:
        return "bicycling";
      case RouteMode.driving:
        return "driving";
      case RouteMode.transit:
        return "transit";
    }
  }
}
