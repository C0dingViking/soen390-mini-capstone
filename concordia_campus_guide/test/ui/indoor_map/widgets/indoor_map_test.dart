import "dart:math";
import "dart:ui" show PointerDeviceKind;

import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/ui/indoor_map/view_models/indoor_view_model.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_map.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter/material.dart";
import "package:flutter_google_maps_webservices/places.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";

class TestIndoorViewModel extends IndoorViewModel {
  bool initCalled = false;
  String? initPath;

  TestIndoorViewModel() : super(floorplanInteractor: FloorplanInteractor()) {
    // provide a dummy floorplan so the widget's initial build doesn't crash
    selectedFloorplan = Floorplan(
      buildingId: "T",
      floorNumber: 1,
      svgPath: "",
      canvasWidth: 100,
      canvasHeight: 100,
    );
    // Initialize loaded room names with test data
    loadedRoomNames = ["T 110", "T 111", "T 112", "T 210", "H 820"];
  }

  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    initCalled = true;
    initPath = path;

    final normalizedPath = path.toUpperCase();

    if (normalizedPath == "H") {
      availableFloors = [8];
      loadedFloorplans = {
        8: Floorplan(
          buildingId: normalizedPath,
          floorNumber: 8,
          svgPath: "testfloor8.svg",
          canvasWidth: 100,
          canvasHeight: 100,
          rooms: [
            IndoorMapRoom(
              name: "820",
              doorLocation: const Point<double>(0, 0),
              points: const [
                Point<double>(0, 0),
                Point<double>(100, 0),
                Point<double>(100, 100),
                Point<double>(0, 100),
              ],
            ),
          ],
          pois: [],
        ),
      };
      selectedFloorplan = loadedFloorplans![8];
      notifyListeners();
      return;
    }

    availableFloors = [1, 2];
    loadedFloorplans = {
      1: Floorplan(
        buildingId: normalizedPath,
        floorNumber: 1,
        svgPath: "testfloor1.svg",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
        ],
        pois: [],
      ),
      2: Floorplan(
        buildingId: normalizedPath,
        floorNumber: 2,
        svgPath: "testfloor2.svg",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "210",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
        ],
        pois: [],
      ),
    };
    selectedFloorplan = loadedFloorplans![1];

    notifyListeners();
  }

  @override
  Future<void> initializeRoomNames() async {
    loadedRoomNames = ["T 110", "T 111", "T 112", "T 210", "H 820"];
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestIndoorViewModel ivm;

  Building makeTestBuilding(final bool supportsFloors) => Building(
    id: "T",
    name: "Test Building",
    description: "A building used for testing",
    campus: Campus.sgw,
    hours: OpeningHoursDetail(openNow: true),
    images: ["image.png"],
    location: Coordinate(latitude: 45.497, longitude: -73.578),
    outlinePoints: [],
    postalCode: "H3G 1M8",
    street: "123 Test St",
    supportedIndoorFloors: (supportsFloors) ? [1, 2] : [],
  );

  setUp(() {
    ivm = TestIndoorViewModel();
  });

  Future<void> pumpHomeScreen(final WidgetTester tester, final bool supportsFloors) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<IndoorViewModel>.value(
          value: ivm,
          child: IndoorMapView(building: makeTestBuilding(supportsFloors)),
        ),
      ),
    );
    await tester.pump();
  }

  group("IndoorMap Widget Tests", () {
    testWidgets("initializes view model with correct building ID", (final tester) async {
      await pumpHomeScreen(tester, true);
      expect(ivm.initCalled, isTrue);
      expect(ivm.initPath, equals("T"));
      expect(find.text("Current location"), findsAtLeastNWidgets(1));
      expect(find.text("Choose destination"), findsOneWidget);
    });

    testWidgets("displays loading indicator when view model is loading", (final tester) async {
      ivm.isLoading = true;
      await pumpHomeScreen(tester, true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("pops back to previous screen when load fails", (final tester) async {
      ivm.loadFailed = true;
      await pumpHomeScreen(tester, false);
      await tester.pumpAndSettle();
      expect(find.byType(IndoorMapView), findsNothing);
    });

    test("maps tap position to clicked room name", () {
      final floorplan = Floorplan(
        buildingId: "T",
        floorNumber: 1,
        svgPath: "",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
        ],
      );

      final roomName = resolveRoomNameFromTapPosition(
        const Offset(50, 50),
        const Size(100, 100),
        floorplan,
      );

      expect(roomName, equals("110"));
    });

    test("returns null when tap is outside room area", () {
      final floorplan = Floorplan(
        buildingId: "T",
        floorNumber: 1,
        svgPath: "",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
        ],
      );

      final roomName = resolveRoomNameFromTapPosition(
        const Offset(150, 50),
        const Size(100, 100),
        floorplan,
      );

      expect(roomName, isNull);
    });

    test("returns null for taps in letterboxed area outside SVG content", () {
      final floorplan = Floorplan(
        buildingId: "T",
        floorNumber: 1,
        svgPath: "",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
        ],
      );

      final roomName = resolveRoomNameFromTapPosition(
        const Offset(50, 25),
        const Size(100, 200),
        floorplan,
      );

      expect(roomName, isNull);
    });

    testWidgets("floor picker button displays the name of the current floor", (final tester) async {
      await pumpHomeScreen(tester, true);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text("T1"), findsOneWidget);
    });

    testWidgets("floor picker shows available floors when clicked", (final tester) async {
      await pumpHomeScreen(tester, true);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text("Floor 1"), findsOneWidget);
      expect(find.text("Floor 2"), findsOneWidget);
    });

    testWidgets("floor picker switches the selected floor when a floor is tapped", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Floor 2"));
      await tester.pumpAndSettle();
      expect(ivm.selectedFloorplan!.floorNumber, 2);
      expect(find.text("T2"), findsOneWidget);
    });

    testWidgets("floor picker shows error if changing floor fails", (final tester) async {
      await pumpHomeScreen(tester, true);

      // remove floor 2 to simulate failure when changing floors
      ivm.loadedFloorplans!.remove(2);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Floor 2"));
      await tester.pumpAndSettle();
      expect(find.text("Failed to change floor. Please try again."), findsOneWidget);
    });

    testWidgets("tap on map populates destination field", (final tester) async {
      await pumpHomeScreen(tester, true);

      final gestureFinder = find
          .ancestor(of: find.byType(InteractiveViewer), matching: find.byType(GestureDetector))
          .first;

      final gestureWidget = tester.widget<GestureDetector>(gestureFinder);
      final size = tester.getSize(gestureFinder);
      final tapPosition = Offset(size.width / 2, size.height / 2);

      gestureWidget.onTapUp!(
        TapUpDetails(localPosition: tapPosition, kind: PointerDeviceKind.touch),
      );
      await tester.pump();

      final destinationTextField = tester.widgetList<TextField>(find.byType(TextField)).last;
      expect(destinationTextField.controller?.text, "T 110");
    });

    testWidgets("Start Navigation switches to floor of current location", (final tester) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 210");
      await tester.enterText(destinationField, "T 110");
      await tester.pumpAndSettle();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(ivm.selectedFloorplan!.floorNumber, 2);
      expect(find.text("T2"), findsOneWidget);
    });

    testWidgets("Start Navigation switches to current location building and floor", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "H 820");
      await tester.enterText(destinationField, "T 110");
      await tester.pumpAndSettle();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(ivm.initPath, "h");
      expect(ivm.selectedFloorplan!.buildingId, "H");
      expect(ivm.selectedFloorplan!.floorNumber, 8);
      expect(find.text("H8"), findsOneWidget);
    });
  });
}
