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
    final RouteMode mode, {
    final DateTime? departureTime,
    final DateTime? arrivalTime,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      logger.w("DirectionsService: API key not available");
      return null;
    }

    try {
      final modeString = _toModeString(mode);
      final origin = "${start.latitude},${start.longitude}";
      final dest = "${destination.latitude},${destination.longitude}";
      
      final queryParams = <String, String>{
        "origin": origin,
        "destination": dest,
        "mode": modeString,
        "alternatives": "false",
        "key": apiKey,
        if (mode == RouteMode.transit) "transit_mode": "subway|bus",
        if (departureTime != null) "departure_time": (departureTime.millisecondsSinceEpoch ~/ 1000).toString(),
        if (arrivalTime != null) "arrival_time": (arrivalTime.millisecondsSinceEpoch ~/ 1000).toString(),
      };
      
      final uri = Uri.https(
        "maps.googleapis.com",
        "/maps/api/directions/json",
        queryParams,
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
      final summary = route["summary"] as String?;
      
      // Parse departure and arrival times from leg if available
      DateTime? parsedDepartureTime;
      DateTime? parsedArrivalTime;
      
      if (leg != null) {
        final depTime = leg["departure_time"] as Map<String, dynamic>?;
        if (depTime != null) {
          final timestamp = depTime["value"] as int?;
          if (timestamp != null) {
            parsedDepartureTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          }
        }
        
        final arrTime = leg["arrival_time"] as Map<String, dynamic>?;
        if (arrTime != null) {
          final timestamp = arrTime["value"] as int?;
          if (timestamp != null) {
            parsedArrivalTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          }
        }
      }
      
      // Parse route steps for detailed instructions
      final steps = _parseRouteSteps(leg);
      
      logger.i(
        "DirectionsService: successfully parsed route for mode $modeString, "
        "points=${polyline.length}, distance=${distance?["value"]}, "
        "duration=${duration?["value"]}, steps=${steps.length}, summary=$summary",
      );

      return RouteOption(
        mode: mode,
        distanceMeters: (distance?["value"] as num?)?.toDouble(),
        durationSeconds: (duration?["value"] as num?)?.toInt(),
        polyline: polyline,
        steps: steps,
        summary: summary,
        departureTime: parsedDepartureTime,
        arrivalTime: parsedArrivalTime,
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

  List<RouteStep> _parseRouteSteps(final Map<String, dynamic>? leg) {
    if (leg == null) return [];
    
    final stepsData = leg["steps"] as List<dynamic>?;
    if (stepsData == null || stepsData.isEmpty) return [];
    
    final steps = <RouteStep>[];
    for (final stepData in stepsData) {
      final step = stepData as Map<String, dynamic>;
      
      final distance = step["distance"] as Map<String, dynamic>?;
      final duration = step["duration"] as Map<String, dynamic>?;
      final travelMode = step["travel_mode"] as String? ?? "WALKING";
      final instruction = _stripHtml(step["html_instructions"] as String? ?? "");
      
      // Parse polyline for this step
      final polylineData = step["polyline"] as Map<String, dynamic>?;
      final encodedPolyline = polylineData?["points"] as String? ?? "";
      final stepPolyline = encodedPolyline.isNotEmpty 
          ? decodePolyline(encodedPolyline) 
          : <Coordinate>[];
      
      TransitDetails? transitDetails;
      if (travelMode == "TRANSIT") {
        transitDetails = _parseTransitDetails(step);
      }
      
      steps.add(RouteStep(
        instruction: instruction,
        distanceMeters: (distance?["value"] as num?)?.toDouble() ?? 0,
        durationSeconds: (duration?["value"] as num?)?.toInt() ?? 0,
        travelMode: travelMode,
        transitDetails: transitDetails,
        polyline: stepPolyline,
      ));
    }
    
    return steps;
  }

  TransitDetails? _parseTransitDetails(final Map<String, dynamic> step) {
    final transitData = step["transit_details"] as Map<String, dynamic>?;
    if (transitData == null) return null;
    
    final line = transitData["line"] as Map<String, dynamic>?;
    final departureStop = transitData["departure_stop"] as Map<String, dynamic>?;
    final arrivalStop = transitData["arrival_stop"] as Map<String, dynamic>?;
    final numStops = transitData["num_stops"] as int?;
    
    final lineName = line?["name"] as String? ?? "";
    final shortName = line?["short_name"] as String? ?? "";
    final vehicleData = line?["vehicle"] as Map<String, dynamic>?;
    final vehicleType = vehicleData?["type"] as String? ?? "BUS";
    
    final transitMode = _parseTransitMode(vehicleType);
    
    return TransitDetails(
      lineName: lineName,
      shortName: shortName,
      mode: transitMode,
      departureStop: departureStop?["name"] as String? ?? "",
      arrivalStop: arrivalStop?["name"] as String? ?? "",
      numStops: numStops,
    );
  }

  TransitMode _parseTransitMode(final String vehicleType) {
    switch (vehicleType.toUpperCase()) {
      case "SUBWAY":
      case "METRO_RAIL":
        return TransitMode.subway;
      case "BUS":
        return TransitMode.bus;
      case "TRAIN":
      case "HEAVY_RAIL":
        return TransitMode.train;
      case "TRAM":
        return TransitMode.tram;
      case "RAIL":
        return TransitMode.rail;
      default:
        return TransitMode.bus;
    }
  }

  String _stripHtml(final String html) {
    return html
        .replaceAll(RegExp(r"<[^>]*>"), "")
        .replaceAll("&nbsp;", " ")
        .replaceAll("&amp;", "&")
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&quot;", "\"")
        .trim();
  }
}
