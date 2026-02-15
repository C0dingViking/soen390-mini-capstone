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

  int refreshCallCount = 0;

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

  @override
  Future<void> refreshRoutes() async {
    refreshCallCount++;
    return super.refreshRoutes();
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
      // CircularProgressIndicator appears in both the refresh button and content area
      expect(find.byType(CircularProgressIndicator), findsWidgets);
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
    testWidgets("refresh button is visible in the handle", (
      final tester,
    ) async {
      vm.setRoutes({
        RouteMode.walking: makeOption(
          mode: RouteMode.walking,
          distanceMeters: 1200,
          durationSeconds: 600,
        ),
      });
      vm.selectedRouteMode = RouteMode.walking;
      vm.notifyListeners();

      await pumpPanel(tester);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets("refresh button shows spinner when loading", (
      final tester,
    ) async {
      vm.setRoutes({
        RouteMode.walking: makeOption(
          mode: RouteMode.walking,
          distanceMeters: 1200,
          durationSeconds: 600,
        ),
      });
      vm.selectedRouteMode = RouteMode.walking;
      vm.notifyListeners();

      await pumpPanel(tester);
      // Initially shows refresh icon
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Simulate loading state
      vm.setLoadingRoutes(true);
      await pumpPanel(tester);

      // Find both the handle refresh button and the content loader
      // The refresh button should have a spinner, the content should have one too
      final allProgressIndicators = find.byType(CircularProgressIndicator);
      expect(allProgressIndicators, findsWidgets);
      
      // Verify refresh icon is no longer visible
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets("refresh button is disabled while loading", (
      final tester,
    ) async {
      vm.setRoutes({
        RouteMode.walking: makeOption(
          mode: RouteMode.walking,
          distanceMeters: 1200,
          durationSeconds: 600,
        ),
      });
      vm.selectedRouteMode = RouteMode.walking;
      vm.notifyListeners();

      await pumpPanel(tester);

      // Simulate loading state
      vm.setLoadingRoutes(true);
      await pumpPanel(tester);

      // Find all IconButtons and get the one containing the spinner
      final iconButtons = find.byType(IconButton);
      expect(iconButtons, findsWidgets);
      
      // Find the button that is disabled (onPressed is null) 
      var disabledFound = false;
      for (int i = 0; i < iconButtons.evaluate().length; i++) {
        final button = tester.widget<IconButton>(iconButtons.at(i));
        if (button.onPressed == null) {
          disabledFound = true;
          break;
        }
      }
      expect(disabledFound, true);
    });

    testWidgets("refresh button calls refreshRoutes when tapped", (
      final tester,
    ) async {
      vm.setRoutes({
        RouteMode.walking: makeOption(
          mode: RouteMode.walking,
          distanceMeters: 1200,
          durationSeconds: 600,
        ),
      });
      vm.selectedRouteMode = RouteMode.walking;
      vm.notifyListeners();

      await pumpPanel(tester);

      expect(vm.refreshCallCount, 0);

      // Tap the refresh button
      final refreshButton = find.byIcon(Icons.refresh);
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      expect(vm.refreshCallCount, 1);
    });

    testWidgets("refresh button is enabled after loading completes", (
      final tester,
    ) async {
      vm.setRoutes({
        RouteMode.walking: makeOption(
          mode: RouteMode.walking,
          distanceMeters: 1200,
          durationSeconds: 600,
        ),
      });
      vm.selectedRouteMode = RouteMode.walking;
      vm.notifyListeners();

      await pumpPanel(tester);

      // Start loading - verify refresh icon exists initially
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      
      vm.setLoadingRoutes(true);
      await pumpPanel(tester);

      // While loading, refresh icon should be gone (replaced with spinner)
      expect(find.byIcon(Icons.refresh), findsNothing);

      // Stop loading
      vm.setLoadingRoutes(false);
      await pumpPanel(tester);

      // After loading, refresh icon should be back and button enabled
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);
      
      // Find the IconButton containing this icon
      final refreshIconButtonFinder = find.ancestor(
        of: refreshButton,
        matching: find.byType(IconButton),
      );
      expect(refreshIconButtonFinder, findsOneWidget);
      
      final iconButton = tester.widget<IconButton>(refreshIconButtonFinder);
      expect(iconButton.onPressed, isNotNull);
    });  });
}
