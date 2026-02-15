import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/domain/interactors/directions_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/places_interactor.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/home/widgets/route_details_panel.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";

class _FakePlacesInteractor extends PlacesInteractor {
  @override
  Future<List<PlaceSuggestion>> searchPlaces(final String query) async => [];

  @override
  Future<Coordinate?> resolvePlace(final String placeId) async => null;

  @override
  Future<Coordinate?> resolvePlaceSuggestion(
    final PlaceSuggestion suggestion,
  ) async => null;
}

class _FakeDirectionsInteractor extends DirectionsInteractor {
  @override
  Future<List<RouteOption>> getRouteOptions(
    final Coordinate start,
    final Coordinate destination, {
    final DateTime? departureTime,
    final DateTime? arrivalTime,
  }) async {
    return [];
  }
}

class _TestHomeViewModel extends HomeViewModel {
  _TestHomeViewModel()
      : super(
          mapInteractor: MapDataInteractor(
            buildingRepo: BuildingRepository(buildingLoader: (_) async => "{}"),
          ),
          placesInteractor: _FakePlacesInteractor(),
          directionsInteractor: _FakeDirectionsInteractor(),
        );

  void setRoutes(final Map<RouteMode, RouteOption> options) {
    routeOptions = options;
    notifyListeners();
  }

  void setLoadingRoutes(final bool loading) {
    isLoadingRoutes = loading;
    notifyListeners();
  }

  void setRouteError(final String? message) {
    routeErrorMessage = message;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("RouteDetailsPanel", () {
    late _TestHomeViewModel vm;

    setUp(() {
      vm = _TestHomeViewModel();
    });

    Future<void> pumpPanel(final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<HomeViewModel>.value(
              value: vm,
              child: const Stack(
                children: [
                  RouteDetailsPanel(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    RouteOption makeOption({
      required final RouteMode mode,
      final double? distanceMeters,
      final int? durationSeconds,
      final List<RouteStep> steps = const [],
      final String? summary,
    }) {
      return RouteOption(
        mode: mode,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        polyline: const [],
        steps: steps,
        summary: summary,
      );
    }

    testWidgets("renders nothing when no routes and not loading", (
      final tester,
    ) async {
      await pumpPanel(tester);
      expect(find.byType(AnimatedContainer), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets("shows loader when loading routes", (final tester) async {
      vm.setLoadingRoutes(true);
      await pumpPanel(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("shows error text when route error is set", (
      final tester,
    ) async {
      vm.setRoutes({
        RouteMode.walking: makeOption(
          mode: RouteMode.walking,
          distanceMeters: 1200,
          durationSeconds: 600,
        ),
      });
      vm.setRouteError("Route failed");
      await pumpPanel(tester);
      expect(find.text("Route failed"), findsOneWidget);
    });

    testWidgets("shows mode selector and summary data", (final tester) async {
      vm.setRoutes({
        RouteMode.walking: makeOption(
          mode: RouteMode.walking,
          distanceMeters: 1200,
          durationSeconds: 600,
          summary: "Main route",
        ),
        RouteMode.transit: makeOption(
          mode: RouteMode.transit,
          distanceMeters: 2200,
          durationSeconds: 900,
        ),
      });
      vm.selectedRouteMode = RouteMode.walking;
      vm.notifyListeners();

      await pumpPanel(tester);
      expect(find.text("Walk"), findsOneWidget);
      expect(find.text("Transit"), findsOneWidget);
      expect(find.text("Bike"), findsNothing);
      expect(find.text("Drive"), findsNothing);
      expect(find.text("10 min"), findsNWidgets(2));
      expect(find.text("1.2 km"), findsOneWidget);
      expect(find.text("Main route"), findsOneWidget);
    });

    testWidgets("shows time labels and suggested departure", (
      final tester,
    ) async {
      vm.setRoutes({
        RouteMode.walking: makeOption(
          mode: RouteMode.walking,
          distanceMeters: 100,
          durationSeconds: 60,
        ),
      });
      vm.selectedRouteMode = RouteMode.walking;
      vm.departureMode = DepartureMode.arriveBy;
      vm.selectedArrivalTime = DateTime(2025, 1, 1, 9, 30);
      vm.suggestedDepartureTime = DateTime(2025, 1, 1, 9, 15);
      vm.selectedDepartureTime = DateTime(2025, 1, 1, 9, 5);
      vm.notifyListeners();

      await pumpPanel(tester);
      expect(find.text("Depart at 09:05"), findsOneWidget);
      expect(find.text("Arrive by 09:30"), findsOneWidget);
      expect(
        find.text("Leave at 09:15 to arrive on time"),
        findsOneWidget,
      );
    });

    testWidgets("shows transit steps only when expanded", (
      final tester,
    ) async {
      final steps = [
        RouteStep(
          instruction: "Walk to stop",
          distanceMeters: 100,
          durationSeconds: 120,
          travelMode: "WALKING",
        ),
        RouteStep(
          instruction: "Take the bus",
          distanceMeters: 2000,
          durationSeconds: 900,
          travelMode: "TRANSIT",
          transitDetails: const TransitDetails(
            lineName: "Downtown Express",
            shortName: "105",
            mode: TransitMode.bus,
            departureStop: "Stop A",
            arrivalStop: "Stop B",
            numStops: 4,
          ),
        ),
      ];
      vm.setRoutes({
        RouteMode.transit: makeOption(
          mode: RouteMode.transit,
          distanceMeters: 2100,
          durationSeconds: 1020,
          steps: steps,
        ),
      });
      vm.selectedRouteMode = RouteMode.transit;
      vm.notifyListeners();

      await pumpPanel(tester);
      expect(find.text("Route Details"), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

      final handle = find.byWidgetPredicate(
        (final widget) => widget is GestureDetector && widget.onTap != null,
      );
      await tester.tap(handle.first);
      await tester.pumpAndSettle();

      expect(find.text("Route Details"), findsOneWidget);
      expect(find.text("Downtown Express"), findsOneWidget);
      expect(find.text("Board at Stop A"), findsOneWidget);
      expect(find.text("Exit at Stop B"), findsOneWidget);
    });
  });
}
