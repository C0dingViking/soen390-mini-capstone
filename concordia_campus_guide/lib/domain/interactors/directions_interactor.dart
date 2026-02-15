import "package:concordia_campus_guide/data/services/directions_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";

class DirectionsInteractor {
  final DirectionsService _service;

  DirectionsInteractor({final DirectionsService? service})
      : _service = service ?? DirectionsService();

  Future<List<RouteOption>> getRouteOptions(
    final Coordinate start,
    final Coordinate destination, {
    final DateTime? departureTime,
    final DateTime? arrivalTime,
  }) async {
    final results = await Future.wait(
      RouteMode.values.map(
        (final mode) => _service.fetchRoute(
          start,
          destination,
          mode,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
        ),
      ),
    );

    return results.whereType<RouteOption>().toList();
  }
}
