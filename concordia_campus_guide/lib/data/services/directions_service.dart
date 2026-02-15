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
  final http.Client _httpClient;

  DirectionsService({final http.Client? httpClient, final ApiKeyService? apiKeyService})
      : _httpClient = httpClient ?? http.Client(),
        _apiKeyService = apiKeyService ?? ApiKeyService();

  Future<String?> _getApiKey() async {
    if (_resolvedKey != null) return _resolvedKey;

    final key = await _apiKeyService.getGoogleMapsApiKey();
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
      final modeString = mode.asString;
      final uri = _buildDirectionsUri(
        start,
        destination,
        mode,
        modeString,
        apiKey,
        departureTime,
        arrivalTime,
      );

      logger.i(
        "DirectionsService: requesting route with mode=$modeString from $start to $destination",
      );

      final response = await _httpClient.get(uri);
      final data = _decodeResponse(response, modeString);
      if (data == null) return null;

      final routeOption = _parseRouteOption(data, mode, modeString);
      if (routeOption == null) return null;

      logger.i(
        "DirectionsService: successfully parsed route for mode $modeString, "
        "points=${routeOption.polyline.length}, distance=${routeOption.distanceMeters}, "
        "duration=${routeOption.durationSeconds}, steps=${routeOption.steps.length}, "
        "summary=${routeOption.summary}",
      );

      return routeOption;
    } catch (e, stackTrace) {
        logger.w("DirectionsService: route request failed", error: e, stackTrace: stackTrace);
        return null;
    }
  }

  Uri _buildDirectionsUri(
    final Coordinate start,
    final Coordinate destination,
    final RouteMode mode,
    final String modeString,
    final String apiKey,
    final DateTime? departureTime,
    final DateTime? arrivalTime,
  ) {
    final origin = "${start.latitude},${start.longitude}";  
    final dest = "${destination.latitude},${destination.longitude}";

    final queryParams = <String, String>{
      "origin": origin,
      "destination": dest,
      "mode": modeString,
      "alternatives": "false",
      "key": apiKey,
      if (mode == RouteMode.transit) "transit_mode": "subway|bus|train|rail",
      if (departureTime != null) "departure_time": (departureTime.millisecondsSinceEpoch ~/ 1000).toString(),
      if (arrivalTime != null) "arrival_time": (arrivalTime.millisecondsSinceEpoch ~/ 1000).toString(),
    };

    return Uri.https(
      "maps.googleapis.com",
      "/maps/api/directions/json",
      queryParams,
    );
  }

  Map<String, dynamic>? _decodeResponse(final http.Response response, final String modeString) {
    if (response.statusCode != 200) {
      logger.w(
        "DirectionsService: HTTP error ${response.statusCode}",
        error: response.body,
      );
      return null;
    }

    final data = json.decode(response.body);
    if (data is! Map<String, dynamic>) {
      logger.w("DirectionsService: invalid response payload for mode $modeString");
      return null;
    }

    return data;
  }

  RouteOption? _parseRouteOption(
    final Map<String, dynamic> data,
    final RouteMode mode,
    final String modeString,
  ) {
    final route = _firstRoute(data, modeString);
    if (route == null) return null;

    final leg = _firstLeg(route);
    final polyline = _parseOverviewPolyline(route);
    final distance = leg?["distance"] as Map<String, dynamic>?;
    final duration = leg?["duration"] as Map<String, dynamic>?;
    final summary = route["summary"] as String?;
    final legTimes = _parseLegTimes(leg);
    final steps = _parseRouteSteps(leg);

    return RouteOption(
      mode: mode,
      distanceMeters: (distance?["value"] as num?)?.toDouble(),
      durationSeconds: (duration?["value"] as num?)?.toInt(),
      polyline: polyline,
      steps: steps,
      summary: summary,
      departureTime: legTimes.departureTime,
      arrivalTime: legTimes.arrivalTime,
    );
  }

  Map<String, dynamic>? _firstRoute(final Map<String, dynamic> data, final String modeString) {
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

    return routes.first as Map<String, dynamic>;
  }

  Map<String, dynamic>? _firstLeg(final Map<String, dynamic> route) {
    final legs = route["legs"] as List<dynamic>?;
    if (legs == null || legs.isEmpty) return null;

    return legs.first as Map<String, dynamic>;
  }

  List<Coordinate> _parseOverviewPolyline(final Map<String, dynamic> route) {
    final overviewPolyline = route["overview_polyline"] as Map<String, dynamic>?;
    final encoded = overviewPolyline?["points"] as String? ?? "";
    return encoded.isNotEmpty ? decodePolyline(encoded) : <Coordinate>[];
  }

  _LegTimes _parseLegTimes(final Map<String, dynamic>? leg) {
    if (leg == null) return const _LegTimes();

    final departure = _parseTimeValue(leg["departure_time"] as Map<String, dynamic>?);
    final arrival = _parseTimeValue(leg["arrival_time"] as Map<String, dynamic>?);
    return _LegTimes(departureTime: departure, arrivalTime: arrival);
  }

  DateTime? _parseTimeValue(final Map<String, dynamic>? timeData) {
    final timestamp = timeData?["value"] as int?;
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
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
    final departureTimeData = transitData["departure_time"] as Map<String, dynamic>?;
    final arrivalTimeData = transitData["arrival_time"] as Map<String, dynamic>?;
    
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
      departureTime: departureTimeData?["text"] as String?,
      arrivalTime: arrivalTimeData?["text"] as String?,
      departureDateTime: _parseTimeValue(departureTimeData),
      arrivalDateTime: _parseTimeValue(arrivalTimeData),
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

  // not using regexp cus sonarqube doesn't like it so have to do this instead... yuck
  String _stripHtml(final String html) {
    final buffer = StringBuffer();
    var inTag = false;
    for (var i = 0; i < html.length; i++) {
      final char = html[i];
      if (char == "<") {
        inTag = true;
        continue;
      }
      if (char == ">") {
        inTag = false;
        continue;
      }
      if (!inTag) {
        buffer.write(char);
      }
    }

    return buffer
        .toString()
        .replaceAll("&nbsp;", " ")
        .replaceAll("&amp;", "&")
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&quot;", "\"")
        .trim();
  }
}

class _LegTimes {
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  const _LegTimes({this.departureTime, this.arrivalTime});
}
