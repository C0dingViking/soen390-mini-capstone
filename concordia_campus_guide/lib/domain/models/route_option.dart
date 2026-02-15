import "package:concordia_campus_guide/domain/models/coordinate.dart";

enum RouteMode { 
    walking, 
    bicycling, 
    driving, 
    transit; 

    String get asString {
        switch(this) {
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

enum TransitMode { bus, subway, train, tram, rail }

class TransitDetails {
  final String lineName;
  final String shortName;
  final TransitMode mode;
  final String departureStop;
  final String arrivalStop;
  final int? numStops;
  final String? departureTime;
  final String? arrivalTime;

  const TransitDetails({
    required this.lineName,
    required this.shortName,
    required this.mode,
    required this.departureStop,
    required this.arrivalStop,
    this.numStops,
    this.departureTime,
    this.arrivalTime,
  });
}

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final int durationSeconds;
  final String travelMode; // WALKING, TRANSIT, etc.
  final TransitDetails? transitDetails;
  final List<Coordinate> polyline;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.travelMode,
    this.transitDetails,
    this.polyline = const [],
  });
}

class RouteOption {
  final RouteMode mode;
  final double? distanceMeters;
  final int? durationSeconds;
  final List<Coordinate> polyline;
  final List<RouteStep> steps;
  final String? summary;
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  const RouteOption({
    required this.mode,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    this.steps = const [],
    this.summary,
    this.departureTime,
    this.arrivalTime,
  });
}
