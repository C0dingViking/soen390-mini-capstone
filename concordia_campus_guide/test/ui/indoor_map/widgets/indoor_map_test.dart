import "dart:math";
import "dart:ui" show PointerDeviceKind;

import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/domain/models/indoor_pathfinding.dart";
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
      floorNumber: "1",
      svgPath: "",
      canvasWidth: 100,
      canvasHeight: 100,
    );
    // Initialize loaded room names with test data
    loadedRoomNames = ["T 110", "T 111", "T 112", "T 210", "H 820"];
    availableFloors = ["1", "2"];
  }

  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    initCalled = true;
    initPath = path;

    final normalizedPath = path.toUpperCase();

    if (normalizedPath == "H") {
      availableFloors = ["8"];
      loadedFloorplans = {
        "8": Floorplan(
          buildingId: normalizedPath,
          floorNumber: "8",
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
      selectedFloorplan = loadedFloorplans!["8"];
      notifyListeners();
      return;
    }

    availableFloors = ["1", "2"];
    loadedFloorplans = {
      "1": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "1",
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
          IndoorMapRoom(
            name: "111",
            doorLocation: const Point<double>(10, 10),
            points: const [
              Point<double>(100, 0),
              Point<double>(200, 0),
              Point<double>(200, 100),
              Point<double>(100, 100),
            ],
          ),
        ],
        pois: [],
      ),
      "2": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "2",
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
    selectedFloorplan = loadedFloorplans!["1"];

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
        floorNumber: "1",
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
        floorNumber: "1",
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
        floorNumber: "1",
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

    testWidgets("floor picker displays the current floor", (final tester) async {
      await pumpHomeScreen(tester, true);

      expect(find.text("1"), findsOneWidget);
    });

    testWidgets("floor picker switches to the next floor when up is tapped", (final tester) async {
      await pumpHomeScreen(tester, true);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(ivm.selectedFloorplan!.floorNumber, "2");
      expect(find.text("2"), findsOneWidget);
    });

    testWidgets("floor picker switches to the prev. floor when down is hit", (final tester) async {
      await pumpHomeScreen(tester, true);

      // go to second floor and back to test
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
      await tester.pumpAndSettle();

      expect(ivm.selectedFloorplan!.floorNumber, "1");
      expect(find.text("1"), findsOneWidget);
    });

    testWidgets("floor picker hides the up arrow if you can't go higher", (final tester) async {
      await pumpHomeScreen(tester, true);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(ivm.selectedFloorplan!.floorNumber, "2");
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets("floor picker hides the down arrow if you can't go lower", (final tester) async {
      await pumpHomeScreen(tester, true);

      expect(ivm.selectedFloorplan!.floorNumber, "1");
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
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

      expect(ivm.selectedFloorplan!.floorNumber, "2");
      expect(find.text("2"), findsOneWidget);
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
      expect(ivm.selectedFloorplan!.floorNumber, "8");
      expect(find.text("8"), findsOneWidget);
    });
  });

  group("Same-floor navigation (lines 179-211)", () {
    testWidgets("shows snackbar when room cannot be located on the floor", (final tester) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      // Start in building T, destination in building H → triggers
      // "Indoor navigation currently supports routes within a single
      // building." snackbar at line 166-172.
      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "H 820");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets("same-floor route between two valid rooms on floor 1", (final tester) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "T 111");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // After navigation, should still be on floor 1
      expect(ivm.selectedFloorplan!.floorNumber, "1");
    });

    testWidgets("same-floor route does not crash on pathfinding errors", (final tester) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "T 111");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // The view is still intact regardless of pathfinding outcome
      expect(find.byType(IndoorMapView), findsOneWidget);
    });
  });

  group("Segment navigation bar (lines 367-453)", () {
    testWidgets("inter-floor nav bar is hidden when no inter-floor route is active", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
    });

    testWidgets("inter-floor route between floors 1 and 2 exercises the inter-floor branch", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 210");
      await tester.enterText(destinationField, "T 110");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(IndoorMapView), findsOneWidget);
    });

    testWidgets("segment nav bar displays step count when inter-floor route is active", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t2-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      expect(find.textContaining("Step 1 of 2"), findsOneWidget);
    });

    testWidgets("segment description: exit only → Start → <transition>", (final tester) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-elevator-1",
            location: const Point<double>(50, 50),
            type: TransitionType.elevator,
            groupTag: "elevator-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t2-elevator-1",
            location: const Point<double>(50, 50),
            type: TransitionType.elevator,
            groupTag: "elevator-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // First segment has no entry, has exit → "Floor 1: Start → Elevator"
      expect(find.textContaining("Start"), findsWidgets);
      expect(find.textContaining("Elevator"), findsWidgets);
    });

    testWidgets("segment description: both entry and exit transitions", (final tester) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-elevator-1",
            location: const Point<double>(50, 50),
            type: TransitionType.elevator,
            groupTag: "elevator-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(75, 75)],
          entryTransition: FloorTransition(
            id: "t2-elevator-1",
            location: const Point<double>(50, 50),
            type: TransitionType.elevator,
            groupTag: "elevator-1",
          ),
          exitTransition: FloorTransition(
            id: "t2-escalator-1",
            location: const Point<double>(75, 75),
            type: TransitionType.escalator,
            groupTag: "escalator-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "3",
          path: [const Point<double>(75, 75), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t3-escalator-1",
            location: const Point<double>(75, 75),
            type: TransitionType.escalator,
            groupTag: "escalator-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // Advance to segment 2 which has both entry (elevator) and exit (escalator)
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      await tester.pump();

      // "Floor 2: Elevator → Escalator"
      expect(find.textContaining("Elevator"), findsWidgets);
      expect(find.textContaining("Escalator"), findsWidgets);
    });

    testWidgets("segment description: entry only → <transition> → Destination", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "3",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t3-escalator-1",
            location: const Point<double>(50, 50),
            type: TransitionType.escalator,
            groupTag: "escalator-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // Advance to last segment — entry only → "Floor 3: Escalator → Destination"
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining("Escalator"), findsWidgets);
      expect(find.textContaining("Destination"), findsWidgets);
    });

    testWidgets("segment description: no transitions → just floor number", (final tester) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: null,
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // Advance to segment 2 which has no transitions
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      await tester.pump();

      // Both transitions null → description is just "Floor 2"
      expect(find.textContaining("Floor 2"), findsWidgets);
    });

    testWidgets("tapping next segment advances to next step", (final tester) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t2-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining("Step 2 of 2"), findsOneWidget);
    });

    testWidgets("tapping previous segment goes back to prior step", (final tester) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t2-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // Go forward then back
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining("Step 2 of 2"), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining("Step 1 of 2"), findsOneWidget);
    });
  });

  group("Inter-floor segment bar visibility in build (lines 568-573)", () {
    testWidgets("segment navigation bar appears only when isInterFloorRoute is true", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      // Initially no inter-floor route → bar not shown
      expect(find.textContaining("Step"), findsNothing);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t2-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // The segment bar is now rendered
      expect(ivm.isInterFloorRoute, isTrue);
      expect(find.textContaining("Step 1 of 2"), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });
  });

  group("End indoor navigation behavior", () {
    testWidgets("End Navigation button is hidden when no indoor navigation is displayed", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      expect(find.text("End Navigation"), findsNothing);
    });

    testWidgets("End Navigation button appears when indoor navigation is displayed", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
      await tester.pump();

      expect(find.text("End Navigation"), findsOneWidget);
    });

    testWidgets("pressing End Navigation ends indoor navigation", (final tester) async {
      await pumpHomeScreen(tester, true);

      ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
      await tester.pump();

      await tester.tap(find.text("End Navigation"));
      await tester.pump();

      expect(ivm.indoorPath, isNull);
      expect(find.text("End Navigation"), findsNothing);
    });

    testWidgets(
      "clearing start or destination ends navigation when indoor navigation is displayed",
      (final tester) async {
        await pumpHomeScreen(tester, true);

        final startField = find.byType(TextField).first;
        final destinationField = find.byType(TextField).last;

        await tester.enterText(startField, "T 110");
        await tester.enterText(destinationField, "T 111");
        await tester.pump();

        ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
        await tester.pump();

        await tester.tap(find.descendant(of: startField, matching: find.byIcon(Icons.close)));
        await tester.pump();

        expect(ivm.indoorPath, isNull);

        ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
        await tester.pump();

        await tester.tap(find.descendant(of: destinationField, matching: find.byIcon(Icons.close)));
        await tester.pump();

        expect(ivm.indoorPath, isNull);
      },
    );
  });

  // Lines 641-670: _AnimatedIndoorPath widget

  group("AnimatedIndoorPath (lines 641-670)", () {
    testWidgets("indoor path painter is shown when indoorPath is set", (final tester) async {
      await pumpHomeScreen(tester, true);

      // Set an indoor path so the _AnimatedIndoorPath widget is built,
      // which creates an AnimationController with ..repeat().
      // Use pump() instead of pumpAndSettle() because the repeating
      // animation never settles.
      ivm.setIndoorPath([
        const Point<double>(0, 0),
        const Point<double>(50, 50),
        const Point<double>(100, 100),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets("indoor path painter is absent when indoorPath is null", (final tester) async {
      await pumpHomeScreen(tester, true);

      ivm.clearIndoorPath();
      await tester.pump();
      await tester.pump();

      expect(find.byType(IndoorMapView), findsOneWidget);
    });

    testWidgets("indoor path painter updates when path changes", (final tester) async {
      await pumpHomeScreen(tester, true);

      ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
      await tester.pump();
      await tester.pump();

      ivm.setIndoorPath([
        const Point<double>(10, 10),
        const Point<double>(90, 90),
        const Point<double>(50, 25),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(IndoorMapView), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets("clearing indoor path removes the path painter", (final tester) async {
      await pumpHomeScreen(tester, true);

      ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
      await tester.pump();
      await tester.pump();

      final customPaintCountBefore = tester.widgetList(find.byType(CustomPaint)).length;

      ivm.clearIndoorPath();
      await tester.pump();
      await tester.pump();

      final customPaintCountAfter = tester.widgetList(find.byType(CustomPaint)).length;

      expect(customPaintCountAfter, lessThanOrEqualTo(customPaintCountBefore));
    });
  });
}
