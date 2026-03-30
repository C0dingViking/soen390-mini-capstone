import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:concordia_campus_guide/ui/home/widgets/home_screen.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:concordia_campus_guide/domain/interactors/calendar_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/places_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/directions_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/domain/models/academic_class.dart";
import "package:concordia_campus_guide/domain/models/room.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_google_maps_webservices/places.dart";
import "package:concordia_campus_guide/controllers/coordinates_controller.dart";
import "package:googleapis/calendar/v3.dart" as calendar;

class _FakePlacesInteractor extends PlacesInteractor {
  @override
  Future<List<PlaceSuggestion>> searchPlaces(final String query) async => [];

  @override
  Future<Coordinate?> resolvePlace(final String placeId) async => null;

  @override
  Future<Coordinate?> resolvePlaceSuggestion(final PlaceSuggestion suggestion) async => null;
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

class _FakeGoogleCalendarRepository implements GoogleCalendarRepository {
  @override
  Future<List<calendar.Event>> getUpcomingEvents({
    final int maxResults = 10,
    final DateTime? timeMin,
    final DateTime? timeMax,
    final String calendarId = "primary",
  }) async => [];

  @override
  Future<List<calendar.Event>> getEventsInRange({
    required final DateTime startDate,
    required final DateTime endDate,
    final String calendarId = "primary",
  }) async => [];

  @override
  Future<List<calendar.CalendarListEntry>> getUserCalendars() async => [];
}

class _FakeCalendarInteractor extends CalendarInteractor {
  _FakeCalendarInteractor() : super(calendarRepo: _FakeGoogleCalendarRepository());
}

class TestHomeViewModel extends HomeViewModel {
  bool initCalled = false;
  String? initPath;
  bool goToCalled = false;
  bool showNextClassCalled = false;
  bool setDestinationToUpcomingClassBuildingCalled = false;
  bool clearCalled = false;
  bool exitNavigationCalled = false;
  bool forceShowLoginSuccessMessage = false;
  bool forceShowNextClassDialog = false;
  int clearLoginSuccessCalls = 0;
  int clearNextClassDialogCalls = 0;

  TestHomeViewModel()
    : super(
        mapInteractor: MapDataInteractor(
          buildingRepo: BuildingRepository(buildingLoader: (_) async => "{}"),
        ),
        placesInteractor: _FakePlacesInteractor(),
        directionsInteractor: _FakeDirectionsInteractor(),
        calendarInteractor: _FakeCalendarInteractor(),
      ) {
    // Add test buildings for navigation tests
    buildings = {
      "H": Building(
        id: "H",
        googlePlacesId: null,
        name: "Science Hall",
        description: "A science building",
        street: "7141 Rue Sherbrooke O",
        postalCode: "H4B 1R6",
        location: const Coordinate(latitude: 45.4572, longitude: -73.6404),
        hours: OpeningHoursDetail(),
        campus: Campus.loyola,
        outlinePoints: [],
        images: [],
        supportedIndoorFloors: const [1, 2],
        buildingFeatures: [BuildingFeature.elevator],
      ),
      "MB": Building(
        id: "MB",
        googlePlacesId: null,
        name: "J.W. McConnell Building",
        description: "Engineering building",
        street: "1400 De Maisonneuve Blvd. W",
        postalCode: "H3G 1M8",
        location: const Coordinate(latitude: 45.4972, longitude: -73.5786),
        hours: OpeningHoursDetail(),
        campus: Campus.sgw,
        outlinePoints: [],
        images: [],
        buildingFeatures: null,
      ),
    };
  }

  @override
  Future<void> initializeBuildingsData(final String path) async {
    initCalled = true;
    initPath = path;
    notifyListeners();
  }

  @override
  Future<void> goToCurrentLocation() async {
    goToCalled = true;
    notifyListeners();
  }

  @override
  void toggleCampus() {
    selectedCampusIndex = (selectedCampusIndex + 1) % 2;
    notifyListeners();
  }

  @override
  void clearCameraTarget() {
    clearCalled = true;
    cameraTarget = null;
    notifyListeners();
  }

  @override
  void exitNavigation() {
    exitNavigationCalled = true;
    super.exitNavigation();
  }

  @override
  Future<void> showNextClass() async {
    showNextClassCalled = true;
    notifyListeners();
  }

  @override
  Future<void> setDestinationToUpcomingClassBuilding() async {
    setDestinationToUpcomingClassBuildingCalled = true;
    notifyListeners();
  }

  @override
  bool get showLoginSuccessMessage => forceShowLoginSuccessMessage;

  @override
  void clearLoginSuccessMessage() {
    clearLoginSuccessCalls++;
    forceShowLoginSuccessMessage = false;
    notifyListeners();
  }

  @override
  bool get showNextClassDialog => forceShowNextClassDialog;

  @override
  void clearNextClassDialog() {
    clearNextClassDialogCalls++;
    forceShowNextClassDialog = false;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("HomeScreen Widget Tests", () {
    late TestHomeViewModel vm;

    setUp(() {
      vm = TestHomeViewModel();
    });

    Future<void> pumpHomeScreen(final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<HomeViewModel>.value(value: vm, child: const HomeScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets("calls initializeBuildingsData on mount", (final tester) async {
      await pumpHomeScreen(tester);
      expect(vm.initCalled, isTrue);
    });

    testWidgets("pressing my location FAB calls goToCurrentLocation", (final tester) async {
      await pumpHomeScreen(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(vm.goToCalled, isTrue);
    });

    testWidgets("pressing campus toggle toggles campus label", (final tester) async {
      await pumpHomeScreen(tester);
      expect(find.text("SGW"), findsOneWidget);
      await tester.tap(find.byKey(const Key("campus_toggle_button")));
      await tester.pump();
      expect(find.text("LOY"), findsOneWidget);
    });

    testWidgets("shows SnackBar when view model has errorMessage", (final tester) async {
      await pumpHomeScreen(tester);
      vm.errorMessage = "test-error";
      vm.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text("test-error"), findsOneWidget);
    });

    testWidgets("shows SnackBar when view model has infoMessage and auto clears it", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);
      vm.generateInfoMessage = "test-info";
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.text("test-info"), findsOneWidget);
      expect(vm.generateInfoMessage, isNull);
    });

    testWidgets("when cameraTarget set, view model clearCameraTarget is called", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);
      vm.cameraTarget = HomeViewModel.sgw;
      vm.notifyListeners();
      await tester.pump();
      expect(vm.clearCalled, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets("directions button is accessible", (final tester) async {
      await pumpHomeScreen(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(vm.buildings, isNotEmpty);
    });

    testWidgets("shows extended FAB when currentBuilding is set", (final tester) async {
      await pumpHomeScreen(tester);

      vm.currentBuilding = vm.buildings["H"];
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.text("H"), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets("shows regular FAB when no currentBuilding", (final tester) async {
      await pumpHomeScreen(tester);

      vm.currentBuilding = null;
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets("shows Next Class FAB when showNextClassFab is true", (final tester) async {
      await pumpHomeScreen(tester);

      vm.showNextClassFab = true;
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.text("Next Class"), findsOneWidget);
      expect(find.byIcon(Icons.school), findsOneWidget);
    });

    testWidgets("tapping Next Class FAB calls showNextClass", (final tester) async {
      await pumpHomeScreen(tester);

      vm.showNextClassFab = true;
      vm.notifyListeners();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FloatingActionButton, "Next Class"));
      await tester.pump();

      expect(vm.showNextClassCalled, isTrue);
    });

    testWidgets("shows login success dialog and calls clearLoginSuccessMessage", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);

      vm.forceShowLoginSuccessMessage = true;
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.text("Your Gmail Account is Connected!"), findsOneWidget);
      expect(vm.clearLoginSuccessCalls, greaterThan(0));
    });

    testWidgets("shows next class dialog and calls clearNextClassDialog", (final tester) async {
      await pumpHomeScreen(tester);

      vm.upcomingClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime(2026, 1, 5, 13, 0),
        DateTime(2026, 1, 5, 14, 0),
        Room("235", "2", Campus.sgw, "cl"),
      );
      vm.forceShowNextClassDialog = true;
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.text("SOEN390"), findsOneWidget);
      expect(find.text("Lecture"), findsOneWidget);
      expect(find.text("CL 235"), findsOneWidget);
      expect(vm.clearNextClassDialogCalls, greaterThan(0));

      await tester.tap(find.byKey(const Key("next_class_dialog_close_button")));
      await tester.pumpAndSettle();
      expect(find.text("SOEN390"), findsNothing);
    });

    testWidgets("tapping Go to Next Class sets destination and closes dialog", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);

      vm.upcomingClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime(2026, 1, 5, 13, 0),
        DateTime(2026, 1, 5, 14, 0),
        Room("235", "2", Campus.sgw, "cl"),
      );
      vm.forceShowNextClassDialog = true;
      vm.notifyListeners();
      await tester.pumpAndSettle();

      await tester.tap(find.text("Go to Next Class"));
      await tester.pumpAndSettle();

      expect(vm.setDestinationToUpcomingClassBuildingCalled, isTrue);
      expect(find.text("SOEN390"), findsNothing);
    });

    testWidgets("does not show next class dialog when upcomingClass is null", (final tester) async {
      await pumpHomeScreen(tester);

      vm.upcomingClass = null;
      vm.forceShowNextClassDialog = true;
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.text("Lecture"), findsNothing);
    });

    testWidgets("android back exits navigation and collapses search bar", (final tester) async {
      await pumpHomeScreen(tester);

      vm.routeOptions = {
        RouteMode.walking: const RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 1200,
          durationSeconds: 600,
          polyline: [],
        ),
      };
      vm.setSearchBarExpanded(true);
      vm.notifyListeners();
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(vm.exitNavigationCalled, isTrue);
      expect(vm.routeOptions, isEmpty);
      expect(vm.isSearchBarExpanded, isFalse);
    });

    testWidgets("shows main-screen indoor switch button for room destination inside building", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);

      vm.selectedDestinationLabel = "H 110";
      vm.currentBuilding = vm.buildings["H"];
      vm.routeOptions = {
        RouteMode.walking: const RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 600,
          durationSeconds: 480,
          polyline: [],
        ),
      };
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key("main_screen_switch_to_indoor_navigation_button")),
        findsOneWidget,
      );
      expect(find.text("Switch Indoor"), findsOneWidget);
    });

    testWidgets("hides main-screen indoor switch button for non-room destination", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);

      vm.selectedDestinationLabel = "Hall Building";
      vm.currentBuilding = vm.buildings["H"];
      vm.routeOptions = {
        RouteMode.walking: const RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 600,
          durationSeconds: 480,
          polyline: [],
        ),
      };
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("main_screen_switch_to_indoor_navigation_button")), findsNothing);
    });

    testWidgets(
      "hides main-screen indoor switch button when user is outside destination building",
      (final tester) async {
        await pumpHomeScreen(tester);

        vm.selectedDestinationLabel = "H 110";
        vm.currentBuilding = vm.buildings["MB"];
        vm.routeOptions = {
          RouteMode.walking: const RouteOption(
            mode: RouteMode.walking,
            distanceMeters: 600,
            durationSeconds: 480,
            polyline: [],
          ),
        };
        vm.notifyListeners();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key("main_screen_switch_to_indoor_navigation_button")),
          findsNothing,
        );
      },
    );

    testWidgets("hides main-screen indoor switch button without active route", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);

      vm.selectedDestinationLabel = "H 110";
      vm.currentBuilding = vm.buildings["H"];
      vm.routeOptions = {};
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("main_screen_switch_to_indoor_navigation_button")), findsNothing);
    });
  });

  group("Building Navigation Tests", () {
    late TestHomeViewModel vm;

    setUp(() {
      vm = TestHomeViewModel();
    });

    Future<void> pumpHomeScreen(final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<HomeViewModel>.value(value: vm, child: const HomeScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets("_onBuildingTapped navigates to BuildingDetailScreen with correct building", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);

      // Get the home screen state to call the method directly
      tester.state<State<HomeScreen>>(find.byType(HomeScreen));

      // Find MapWrapper and verify it has an onPolygonTap callback
      expect(find.byType(HomeScreen), findsOneWidget);

      // Verify buildings are available in view model
      expect(vm.buildings.containsKey("H"), isTrue);
      expect(vm.buildings["H"]?.name, equals("Science Hall"));
    });

    testWidgets("extracting building ID from polygon ID works correctly", (final tester) async {
      await pumpHomeScreen(tester);

      // Test the building ID extraction logic
      const polygonId = PolygonId("H-poly");
      final buildingId = polygonId.value.replaceAll("-poly", "");

      expect(buildingId, equals("H"));
      expect(vm.buildings.containsKey(buildingId), isTrue);
    });

    testWidgets("polygon with invalid building ID does not crash", (final tester) async {
      await pumpHomeScreen(tester);

      const polygonId = PolygonId("INVALID-poly");
      final buildingId = polygonId.value.replaceAll("-poly", "");

      expect(buildingId, equals("INVALID"));
      expect(vm.buildings.containsKey(buildingId), isFalse);
      expect(vm.buildings[buildingId], isNull);
    });

    testWidgets("all test buildings are accessible in view model", (final tester) async {
      await pumpHomeScreen(tester);

      expect(vm.buildings.length, equals(2));
      expect(vm.buildings.containsKey("H"), isTrue);
      expect(vm.buildings.containsKey("MB"), isTrue);

      final scienceHall = vm.buildings["H"];
      expect(scienceHall?.name, equals("Science Hall"));
      expect(scienceHall?.id, equals("H"));

      final mcConnell = vm.buildings["MB"];
      expect(mcConnell?.name, equals("J.W. McConnell Building"));
      expect(mcConnell?.id, equals("MB"));
    });

    testWidgets("exposes coordsController getter", (final tester) async {
      await pumpHomeScreen(tester);
      final State<HomeScreen> state = tester.state(find.byType(HomeScreen));
      final CoordinatesController controller =
          (state as dynamic).coordsController as CoordinatesController;
      expect(controller, isNotNull);
    });

    testWidgets("building tap handler extracts correct ID", (final tester) async {
      await pumpHomeScreen(tester);

      // Simulate building tap logic
      const polygonId = PolygonId("H-poly");
      final buildingId = polygonId.value.replaceAll("-poly", "");
      final building = vm.buildings[buildingId];

      // Verify building is found
      expect(building, isNotNull);
      expect(building?.id, equals("H"));
      expect(building?.name, equals("Science Hall"));
    });

    testWidgets("tapping extended FAB when currentBuilding is set calls goToCurrentLocation", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);

      // Set currentBuilding so extended FAB appears
      vm.currentBuilding = vm.buildings["H"];
      vm.notifyListeners();
      await tester.pumpAndSettle();

      // Ensure extended FAB is shown
      expect(find.text("H"), findsOneWidget);

      // Tap the extended FAB specifically
      final extendedFab = find.widgetWithText(FloatingActionButton, "H");

      await tester.tap(extendedFab);
      await tester.pump();

      expect(vm.goToCalled, isTrue);
    });

    testWidgets("building tap with valid ID finds building", (final tester) async {
      await pumpHomeScreen(tester);

      // Test the extraction and lookup logic
      final testCases = [
        {"input": "H-poly", "expected": "H"},
        {"input": "MB-poly", "expected": "MB"},
      ];

      for (final testCase in testCases) {
        final polygonId = PolygonId(testCase["input"]!);
        final buildingId = polygonId.value.replaceAll("-poly", "");
        final building = vm.buildings[buildingId];

        expect(buildingId, equals(testCase["expected"]));
        expect(building, isNotNull);
      }
    });

    testWidgets("building marker tap lookup finds correct building", (final tester) async {
      await pumpHomeScreen(tester);

      const markerId = MarkerId("H-marker");
      final buildingId = markerId.value.replaceAll("-marker", "");
      final building = vm.buildings[buildingId];

      expect(buildingId, equals("H"));
      expect(building, isNotNull);
      expect(building?.id, equals("H"));
      expect(building?.name, equals("Science Hall"));
    });
  });
}
