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

    final leaveTime = departureTime ?? DateTime.now();

    RouteOption? bestRouteOption;
    int bestTotalTimeSeconds = 1 << 30;

    // evaluate both sgw -> loyola and loyola -> sgw orders
    final candidates = <List<ShuttleStop>>[
      [sgwShuttleStop, loyolaShuttleStop],
      [loyolaShuttleStop, sgwShuttleStop],
    ];

    for (final pair in candidates) {
      final board = pair[0];
      final alight = pair[1];

      final candidate = await _evaluateCandidate(
        start: start,
        destination: destination,
        board: board,
        alight: alight,
        leaveTime: leaveTime,
        shuttleRide: shuttleRide,
      );
      if (candidate == null) continue;
      if (candidate.totalTimeSeconds >= bestTotalTimeSeconds) continue;

      bestTotalTimeSeconds = candidate.totalTimeSeconds;
      bestRouteOption = candidate.routeOption;
    }

    return bestRouteOption;
  }

  Future<_CandidateRouteData?> _evaluateCandidate({
    required final Coordinate start,
    required final Coordinate destination,
    required final ShuttleStop board,
    required final ShuttleStop alight,
    required final DateTime leaveTime,
    required final int shuttleRide,
  }) async {
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

    if (walkToBoard == null || walkFromAlight == null) return null;
    final walkToBoardSeconds = walkToBoard.durationSeconds;
    final walkFromAlightSeconds = walkFromAlight.durationSeconds;
    if (walkToBoardSeconds == null || walkFromAlightSeconds == null) return null;

    final arriveBoard = leaveTime.add(Duration(seconds: walkToBoardSeconds));
    final waitTimeSeconds = _waitSeconds(arriveBoard);
    final totalTimeSeconds =
        walkToBoardSeconds + waitTimeSeconds + shuttleRide + walkFromAlightSeconds;

    final shuttleRoute = await _directionsService.fetchRoute(
      board.location,
      alight.location,
      RouteMode.driving,
    );
    final shuttlePolyline = shuttleRoute?.polyline ?? [board.location, alight.location];

    final routeOption = _buildRouteOption(
      walkToBoard: walkToBoard,
      walkFromAlight: walkFromAlight,
      board: board,
      alight: alight,
      shuttleRide: shuttleRide,
      waitTimeSeconds: waitTimeSeconds,
      totalTimeSeconds: totalTimeSeconds,
      shuttlePolyline: shuttlePolyline,
    );

    return _CandidateRouteData(routeOption: routeOption, totalTimeSeconds: totalTimeSeconds);
  }

  RouteOption _buildRouteOption({
    required final RouteOption walkToBoard,
    required final RouteOption walkFromAlight,
    required final ShuttleStop board,
    required final ShuttleStop alight,
    required final int shuttleRide,
    required final int waitTimeSeconds,
    required final int totalTimeSeconds,
    required final List<Coordinate> shuttlePolyline,
  }) {
    final steps = _buildSteps(
      walkToBoard: walkToBoard,
      walkFromAlight: walkFromAlight,
      board: board,
      alight: alight,
      shuttleRide: shuttleRide,
      waitTimeSeconds: waitTimeSeconds,
      shuttlePolyline: shuttlePolyline,
    );

    return RouteOption(
      mode: RouteMode.shuttle,
      distanceMeters: (walkToBoard.distanceMeters ?? 0) + (walkFromAlight.distanceMeters ?? 0),
      durationSeconds: totalTimeSeconds,
      polyline: [...walkToBoard.polyline, ...shuttlePolyline, ...walkFromAlight.polyline],
      steps: steps,
      summary: _buildSummary(waitTimeSeconds),
    );
  }

  List<RouteStep> _buildSteps({
    required final RouteOption walkToBoard,
    required final RouteOption walkFromAlight,
    required final ShuttleStop board,
    required final ShuttleStop alight,
    required final int shuttleRide,
    required final int waitTimeSeconds,
    required final List<Coordinate> shuttlePolyline,
  }) {
    final steps = <RouteStep>[...walkToBoard.steps];

    if (waitTimeSeconds > 0) {
      steps.add(
        RouteStep(
          instruction: "Wait for shuttle",
          distanceMeters: 0,
          durationSeconds: waitTimeSeconds,
          travelMode: "WAIT",
          polyline: [board.location],
        ),
      );
    }

    steps.add(
      RouteStep(
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
      ),
    );
    steps.addAll(walkFromAlight.steps);
    return steps;
  }

  String _buildSummary(final int waitTimeSeconds) {
    final summaryParts = <String>["Walk"];
    if (waitTimeSeconds > 0) {
      final minutes = (waitTimeSeconds / 60).round();
      summaryParts.add("Wait $minutes min");
    }
    summaryParts.addAll(["Shuttle", "Walk"]);
    return summaryParts.join(" → ");
  }

  int _waitSeconds(final DateTime arrival) {
    final next = _determineNextShuttleDeparture(arrival);
    return next.difference(arrival).inSeconds;
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

class _CandidateRouteData {
  final RouteOption routeOption;
  final int totalTimeSeconds;

  _CandidateRouteData({required this.routeOption, required this.totalTimeSeconds});
}
