import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/data/services/shuttle_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/data/services/directions_service.dart";

/// A fake directions service that simply returns a constant walking route
/// for whatever coordinates are passed.  This keeps the shuttle logic
/// deterministic and avoids hitting the real Google API during tests.
class _FakeDirectionsService extends DirectionsService {
  final int walkSeconds;

  _FakeDirectionsService({this.walkSeconds = 300}) : super();

  @override
  Future<RouteOption?> fetchRoute(
    final Coordinate start,
    final Coordinate destination,
    final RouteMode mode, {
    final DateTime? departureTime,
    final DateTime? arrivalTime,
  }) async {
    // always return a short route with fixed duration regardless of mode
    return RouteOption(
      mode: mode,
      distanceMeters: 50.0,
      durationSeconds: walkSeconds,
      polyline: [start, destination],
      steps: [],
    );
  }
}

void main() {
  final start = Coordinate(latitude: 0, longitude: 0);
  final end = Coordinate(latitude: 1, longitude: 1);

  group("ShuttleService scheduling", () {
    final shuttle = ShuttleService(
      directionsService: _FakeDirectionsService(walkSeconds: 300),
    );

    test("after 18:30 wraps to next day 9:15", () async {
      final late = DateTime(2024, 1, 1, 19, 0);
      final route = await shuttle.createShuttleRoute(start, end, departureTime: late);
      expect(route, isNotNull);
      // walk 5 min + wait until next day 09:15 + ride 30 + walk 5
      // difference is ~14 hours
      expect(route!.durationSeconds, greaterThan(50000)); // rough sanity check
    });

    test("before 9:15 waits until 9:15", () async {
      final early = DateTime(2024, 1, 1, 8, 50);
      final route = await shuttle.createShuttleRoute(start, end, departureTime: early);
      expect(route, isNotNull);
      // walk to board takes 5 min -> arrive 8:55, wait 20 min to 9:15, ride 30, walk 5
      expect(route!.durationSeconds, 300 + 1200 + 1800 + 300);
    });

    test('during service rounds up to next quarter and includes wait step', () async {
      // leave at 09:20, walk 5 -> arrive 09:25, next departure 09:30 (5 min wait)
      final mid = DateTime(2024, 1, 1, 9, 20);
      final route = await shuttle.createShuttleRoute(start, end, departureTime: mid);
      expect(route, isNotNull);
      expect(route!.durationSeconds, 300 + 300 + 1800 + 300);
      // should have a wait step before shuttle leg
      expect(route.steps.any((s) => s.travelMode == 'WAIT'), isTrue);
      final waitStep = route.steps.firstWhere((s) => s.travelMode == 'WAIT');
      expect(waitStep.durationSeconds, equals(300));
    });

    test("exact quarter departure has zero wait", () async {
      final perfect = DateTime(2024, 1, 1, 9, 10);
      final route = await shuttle.createShuttleRoute(start, end, departureTime: perfect);
      expect(route, isNotNull);
      // arrive boards at 9:15 exactly
      expect(route!.durationSeconds, 300 + 1800 + 300);
    });
  });
}
