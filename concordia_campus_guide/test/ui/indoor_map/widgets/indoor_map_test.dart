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
    selectedFloorplan = Floorplan(buildingId: "T", floorNumber: 1, svgPath: "");
  }

  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    initCalled = true;
    initPath = path;

    selectedFloorplan = Floorplan(
      buildingId: path,
      floorNumber: 1,
      svgPath: "",
      rooms: [],
      pois: [],
    );

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
  });
}
