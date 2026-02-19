import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/domain/models/shuttle_stop.dart";
import "directions_service.dart";

class ShuttleService {
  final DirectionsService _directionsService;

  ShuttleService({final DirectionsService? directionsService})
      : _directionsService = directionsService ?? DirectionsService();

  Future<RouteOption?> createShuttleRoute(Coordinate start, Coordinate destination) async {
    const shuttleDuration = 1800; // 30 min

    final candidates = [
      [sgwShuttleStop, loyolaShuttleStop],
      [loyolaShuttleStop, sgwShuttleStop],
    ];

    RouteOption? best;
    int bestTotal = 1 << 30;

    for (final pair in candidates) {
      final board = pair[0];
      final alight = pair[1];

      final walkToBoard = await _directionsService.fetchRoute(start, board.location, RouteMode.walking);
      final walkFromAlight = await _directionsService.fetchRoute(alight.location, destination, RouteMode.walking);

      if (walkToBoard == null || walkFromAlight == null) continue;

      final total = (walkToBoard.durationSeconds ?? 0) + shuttleDuration + (walkFromAlight.durationSeconds ?? 0);

      if (total < bestTotal) {
        bestTotal = total;

        final shuttleLeg = RouteStep(
          instruction: 'Take shuttle from ${board.name} to ${alight.name}',
          distanceMeters: 0,
          durationSeconds: shuttleDuration,
          travelMode: 'SHUTTLE',
          transitDetails: TransitDetails(
            lineName: 'Campus Shuttle',
            shortName: 'SH',
            mode: TransitMode.bus,
            departureStop: board.name,
            arrivalStop: alight.name,
          ),
          polyline: [board.location, alight.location],
        );

        best = RouteOption(
          mode: RouteMode.shuttle,
          distanceMeters: (walkToBoard.distanceMeters ?? 0) + (walkFromAlight.distanceMeters ?? 0),
          durationSeconds: (walkToBoard.durationSeconds ?? 0) + shuttleDuration + (walkFromAlight.durationSeconds ?? 0),
          polyline: [...walkToBoard.polyline, ...walkFromAlight.polyline],
          steps: [...walkToBoard.steps, shuttleLeg, ...walkFromAlight.steps],
          summary: 'Walk → Shuttle → Walk',
        );
      }
    }

    return best;
  }





}
