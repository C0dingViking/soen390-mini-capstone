import "package:concordia_campus_guide/domain/models/coordinate.dart";

enum RouteMode { walking, bicycling, driving, transit }

class RouteOption {
  final RouteMode mode;
  final double? distanceMeters;
  final int? durationSeconds;
  final List<Coordinate> polyline;

  const RouteOption({
    required this.mode,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
  });
}
