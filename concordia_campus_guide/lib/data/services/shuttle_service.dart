import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/domain/models/shuttle_stop.dart";
import "directions_service.dart";

class ShuttleService {
  final DirectionsService _directionsService;

  ShuttleService({final DirectionsService? directionsService})
    : _directionsService = directionsService ?? DirectionsService();
  // Tries both directions and picks the fastest combination of walking + shuttle + walking.
  Future<RouteOption?> createShuttleRoute(
    final Coordinate start,
    final Coordinate destination, {
    final DateTime? departureTime,
  }) async {
    const shuttleRide = 1800;

    int waitSeconds(final DateTime arrival) {
      final next = _determineNextShuttleDeparture(arrival);
      return next.difference(arrival).inSeconds;
    }

    final leaveTimeSeconds = departureTime ?? DateTime.now();

    RouteOption? bestRouteOption;
    int bestTotalTimeSeconds = 1 << 30;

    // evaluate both sgw -> loyola and loyola -> sgw orders
    final candidates = [
      [sgwShuttleStop, loyolaShuttleStop],
      [loyolaShuttleStop, sgwShuttleStop],
    ];

    for (final pair in candidates) {
      final board = pair[0];
      final alight = pair[1];

      final walkToBoard = await _directionsService.fetchRoute(
        start,
        board.location,
        RouteMode.walking,
      );
      final walkFromAlight = await _directionsService.fetchRoute(
        alight.location,
        destination,
        RouteMode.walking,
      );

      if (walkToBoard == null || walkFromAlight == null) continue;
      if (walkToBoard.durationSeconds == null) continue;
      if (walkFromAlight.durationSeconds == null) continue;

      final arriveBoard = leaveTimeSeconds.add(
        Duration(seconds: walkToBoard.durationSeconds!),
      );
      final waitTimeSeconds = waitSeconds(arriveBoard);

      final totalTimeSeconds =
          (walkToBoard.durationSeconds ?? 0) +
          waitTimeSeconds +
          shuttleRide +
          (walkFromAlight.durationSeconds ?? 0);

      if (totalTimeSeconds < bestTotalTimeSeconds) {
        bestTotalTimeSeconds = totalTimeSeconds;

        final shuttleRoute = await _directionsService.fetchRoute(
          board.location,
          alight.location,
          RouteMode.driving,
        );
        final shuttlePolyline =
            shuttleRoute?.polyline ?? [board.location, alight.location];

        // added waiting step if needed
        final stepList = <RouteStep>[];
        stepList.addAll(walkToBoard.steps);
        if (waitTimeSeconds > 0) {
          stepList.add(
            RouteStep(
              instruction: "Wait for shuttle",
              distanceMeters: 0,
              durationSeconds: waitTimeSeconds,
              travelMode: "WAIT",
              polyline: [board.location],
            ),
          );
        }

        final shuttleLeg = RouteStep(
          instruction: "Take shuttle from ${board.name} to ${alight.name}",
          distanceMeters: 0,
          durationSeconds: shuttleRide,
          travelMode: "SHUTTLE",
          transitDetails: TransitDetails(
            lineName: "Campus Shuttle",
            shortName: "SH",
            mode: TransitMode.bus,
            departureStop: board.name,
            arrivalStop: alight.name,
          ),
          polyline: shuttlePolyline,
        );
        stepList.add(shuttleLeg);
        stepList.addAll(walkFromAlight.steps);

        final summaryParts = <String>["Walk"];
        if (waitTimeSeconds > 0) {
          final minutes = (waitTimeSeconds / 60).round();
          summaryParts.add("Wait $minutes min");
        }
        summaryParts.addAll(["Shuttle", "Walk"]);
        final summaryString = summaryParts.join(" → ");

        bestRouteOption = RouteOption(
          mode: RouteMode.shuttle,
          distanceMeters:
              (walkToBoard.distanceMeters ?? 0) +
              (walkFromAlight.distanceMeters ?? 0),
          durationSeconds: totalTimeSeconds,
          polyline: [
            ...walkToBoard.polyline,
            ...shuttlePolyline,
            ...walkFromAlight.polyline,
          ],
          steps: stepList,
          summary: summaryString,
        );
      }
    }

    return bestRouteOption;
  }

  /// Shuttle runs from 09:15 to 18:30 every 15 minutes. Wraps to next day at 09:15 if after 18:30. Returns the next departure DateTime.
  DateTime _determineNextShuttleDeparture(final DateTime when) {
    final dayStart = DateTime(when.year, when.month, when.day);
    final start = dayStart.add(const Duration(hours: 9, minutes: 15));
    final end = dayStart.add(const Duration(hours: 18, minutes: 30));
    if (when.isAfter(end)) {
      return start.add(const Duration(days: 1));
    }
    if (when.isBefore(start)) return start;
    final minutes = when.difference(start).inMinutes;
    final remainder = minutes % 15;
    if (remainder == 0) return when;
    return when.add(Duration(minutes: 15 - remainder));
  }
}
