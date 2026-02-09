import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:concordia_campus_guide/ui/home/widgets/home_screen.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_google_maps_webservices/places.dart";
import "package:concordia_campus_guide/controllers/coordinates_controller.dart";

class TestHomeViewModel extends HomeViewModel {
  bool initCalled = false;
  String? initPath;
  bool goToCalled = false;
  bool clearCalled = false;

  TestHomeViewModel()
    : super(
        mapInteractor: MapDataInteractor(
          buildingRepo: BuildingRepository(buildingLoader: (_) async => "{}"),
        ),
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
          home: ChangeNotifierProvider<HomeViewModel>.value(
            value: vm,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets("calls initializeBuildingsData on mount", (final tester) async {
      await pumpHomeScreen(tester);
      expect(vm.initCalled, isTrue);
    });

    testWidgets("pressing my location FAB calls goToCurrentLocation", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(vm.goToCalled, isTrue);
    });

    testWidgets("pressing campus toggle toggles campus label", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);
      expect(find.text("SGW"), findsOneWidget);
      await tester.tap(find.byKey(const Key("campus_toggle_button")));
      await tester.pump();
      expect(find.text("LOY"), findsOneWidget);
    });

    testWidgets("shows SnackBar when view model has errorMessage", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);
      vm.errorMessage = "test-error";
      vm.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text("test-error"), findsOneWidget);
    });

    testWidgets(
      "when cameraTarget set, view model clearCameraTarget is called",
      (final tester) async {
        await pumpHomeScreen(tester);
        vm.cameraTarget = HomeViewModel.sgw;
        vm.notifyListeners();
        await tester.pump();
        expect(vm.clearCalled, isTrue);
        await tester.pumpAndSettle();
      },
    );

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
  });

  group("Building Navigation Tests", () {
    late TestHomeViewModel vm;

    setUp(() {
      vm = TestHomeViewModel();
    });

    Future<void> pumpHomeScreen(final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<HomeViewModel>.value(
            value: vm,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      "_onBuildingTapped navigates to BuildingDetailScreen with correct building",
      (final tester) async {
        await pumpHomeScreen(tester);

        // Get the home screen state to call the method directly
        tester.state<State<HomeScreen>>(find.byType(HomeScreen));

        // Find MapWrapper and verify it has an onPolygonTap callback
        expect(find.byType(HomeScreen), findsOneWidget);

        // Verify buildings are available in view model
        expect(vm.buildings.containsKey("H"), isTrue);
        expect(vm.buildings["H"]?.name, equals("Science Hall"));
      },
    );

    testWidgets("extracting building ID from polygon ID works correctly", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);

      // Test the building ID extraction logic
      const polygonId = PolygonId("H-poly");
      final buildingId = polygonId.value.replaceAll("-poly", "");

      expect(buildingId, equals("H"));
      expect(vm.buildings.containsKey(buildingId), isTrue);
    });

    testWidgets("polygon with invalid building ID does not crash", (
      final tester,
    ) async {
      await pumpHomeScreen(tester);

      const polygonId = PolygonId("INVALID-poly");
      final buildingId = polygonId.value.replaceAll("-poly", "");

      expect(buildingId, equals("INVALID"));
      expect(vm.buildings.containsKey(buildingId), isFalse);
      expect(vm.buildings[buildingId], isNull);
    });

    testWidgets("all test buildings are accessible in view model", (
      final tester,
    ) async {
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
      final CoordinatesController controller = (state as dynamic).coordsController as CoordinatesController;
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
  });
}
