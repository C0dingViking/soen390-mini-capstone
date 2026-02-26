import "package:concordia_campus_guide/data/services/directions_service.dart";
import "package:concordia_campus_guide/data/services/shuttle_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";

class DirectionsInteractor {
  final DirectionsService _service;
  final ShuttleService _shuttleService;

  DirectionsInteractor({final DirectionsService? service, final ShuttleService? shuttleService})
    : _service = service ?? DirectionsService(),
      _shuttleService = shuttleService ?? ShuttleService();

  Future<List<RouteOption>> getRouteOptions(
    final Coordinate start,
    final Coordinate destination, {
    final DateTime? departureTime,
    final DateTime? arrivalTime,
  }) async {
    final results = await Future.wait(
      RouteMode.values
          .where((final mode) => mode != RouteMode.shuttle)
          .map(
            (final mode) => _service.fetchRoute(
              start,
              destination,
              mode,
              departureTime: departureTime,
              arrivalTime: arrivalTime,
            ),
          ),
    );

    final shuttleRoute = await _shuttleService.createShuttleRoute(
      start,
      destination,
      departureTime: departureTime,
    );
    final allRoutes = results.whereType<RouteOption>().toList();
    if (shuttleRoute != null) {
      allRoutes.add(shuttleRoute);
    }

    return allRoutes;
  }
}
