// ignore_for_file: prefer_double_quotes

import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/domain/models/shuttle_stop.dart";
import "directions_service.dart";

class ShuttleService {
  final DirectionsService _directionsService;

  ShuttleService({final DirectionsService? directionsService})
      : _directionsService = directionsService ?? DirectionsService();

  /// Tries both directions and picks the fastest combination of walking +
  /// shuttle + walking.  Returns null if shuttle isn't available at the given time or if fail to produce a route.
  Future<RouteOption?> createShuttleRoute(
    final Coordinate start,
    final Coordinate destination, {
    final DateTime? departureTime,
  }) async {
    const shuttleRide = 1800; // fixed 30‑minute ride

    // helper to compute next departure and waiting time for a given arrival
    int waitSeconds(final DateTime arrival) {
      final next = _nextShuttleDeparture(arrival);
      if (next == null) return -1; // indicates no service
      return next.difference(arrival).inSeconds;
    }

    final leave = departureTime ?? DateTime.now();

    RouteOption? best;
    int bestTotal = 1 << 30;

    // evaluate both boarding/alighting orders
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

      final arriveBoard = leave.add(Duration(seconds: walkToBoard.durationSeconds!));
      final wait = waitSeconds(arriveBoard);
      if (wait < 0) continue; // no shuttle service for this day/time

      final total = (walkToBoard.durationSeconds ?? 0) + wait + shuttleRide +
          (walkFromAlight.durationSeconds ?? 0);

      if (total < bestTotal) {
        bestTotal = total;

        final shuttleLeg = RouteStep(
          instruction: 'Take shuttle from ${board.name} to ${alight.name}',
          distanceMeters: 0,
          durationSeconds: wait + shuttleRide,
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
          distanceMeters: (walkToBoard.distanceMeters ?? 0) +
              (walkFromAlight.distanceMeters ?? 0),
          durationSeconds: total,
          polyline: [...walkToBoard.polyline, ...walkFromAlight.polyline],
          steps: [...walkToBoard.steps, shuttleLeg, ...walkFromAlight.steps],
          summary: 'Walk → Shuttle → Walk',
        );
      }
    }

    return best;
  }

  /// Shuttle runs from 09:15 to 18:30 every 15 minutes.  Returns the DateTime
  /// of the first departure at or after or null if none remain.
  DateTime? _nextShuttleDeparture(final DateTime when) {
    final dayStart = DateTime(when.year, when.month, when.day);
    final start = dayStart.add(const Duration(hours: 9, minutes: 15));
    final end = dayStart.add(const Duration(hours: 18, minutes: 30));
    if (when.isAfter(end)) return null;
    if (when.isBefore(start)) return start;
    final minutes = when.difference(start).inMinutes;
    final remainder = minutes % 15;
    if (remainder == 0) return when;
    return when.add(Duration(minutes: 15 - remainder));
  }





}
