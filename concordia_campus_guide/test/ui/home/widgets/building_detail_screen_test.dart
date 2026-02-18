import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/ui/home/widgets/building_detail_screen.dart";
import "package:concordia_campus_guide/ui/home/widgets/opening_hours_widget.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_google_maps_webservices/places.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("BuildingDetailScreen Widget Tests", () {
    late Building testBuilding;

    setUp(() {
      testBuilding = Building(
        id: "H",
        googlePlacesId: null,
        name: "Science Hall",
        description:
            "A large, modern science teaching and research complex at Concordia's Loyola Campus.",
        street: "7141 Rue Sherbrooke O",
        postalCode: "H4B 1R6",
        location: const Coordinate(latitude: 45.4572, longitude: -73.6404),
        hours: OpeningHoursDetail(),
        campus: Campus.loyola,
        outlinePoints: [],
        images: ["assets/images/science_hall.jpg"],
        buildingFeatures: [
          BuildingFeature.wheelChairAccess,
          BuildingFeature.elevator,
          BuildingFeature.bathroom,
        ],
      );
    });

    Future<void> pumpBuildingDetailScreen(final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuildingDetailScreen(building: testBuilding)),
      );
    }

    testWidgets("displays building name and description", (final tester) async {
      await pumpBuildingDetailScreen(tester);
      expect(find.text("Science Hall"), findsOneWidget);
      expect(
        find.textContaining("A large, modern science teaching"),
        findsOneWidget,
      );
    });

    testWidgets("back button pops navigation", (final tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (final context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          BuildingDetailScreen(building: testBuilding),
                    ),
                  );
                },
                child: const Text("Go to Building"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Go to Building"));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text("Go to Building"), findsOneWidget);
      expect(find.text("Science Hall"), findsNothing);
    });

    testWidgets("displays building features icons", (final tester) async {
      await pumpBuildingDetailScreen(tester);
      expect(find.byIcon(Icons.accessible), findsOneWidget);
      expect(find.byIcon(Icons.elevator), findsOneWidget);
      expect(find.byIcon(Icons.wc), findsOneWidget);
    });

    testWidgets("hides features section when no features", (
      final tester,
    ) async {
      testBuilding = Building(
        id: "H",
        googlePlacesId: null,
        name: "Science Hall",
        description: "A large, modern science teaching and research complex.",
        street: "7141 Rue Sherbrooke O",
        postalCode: "H4B 1R6",
        location: const Coordinate(latitude: 45.4572, longitude: -73.6404),
        hours: OpeningHoursDetail(),
        campus: Campus.loyola,
        outlinePoints: [],
        images: [],
        buildingFeatures: null,
      );
      await pumpBuildingDetailScreen(tester);
      expect(find.byIcon(Icons.accessible), findsNothing);
    });

    testWidgets("displays placeholder when no images", (final tester) async {
      testBuilding = Building(
        id: "H",
        googlePlacesId: null,
        name: "Science Hall",
        description: "A large, modern science teaching and research complex.",
        street: "7141 Rue Sherbrooke O",
        postalCode: "H4B 1R6",
        location: const Coordinate(latitude: 45.4572, longitude: -73.6404),
        hours: OpeningHoursDetail(),
        campus: Campus.loyola,
        outlinePoints: [],
        images: [],
        buildingFeatures: null,
      );
      await pumpBuildingDetailScreen(tester);
      expect(find.byIcon(Icons.apartment), findsOneWidget);
    });

    testWidgets("opens and closes accessibility dialog", (final tester) async {
      await pumpBuildingDetailScreen(tester);

      await tester.tap(find.byWidgetPredicate(
            (final w) => w is FloatingActionButton && w.heroTag == "accessibility_info", ));
      await tester.pumpAndSettle();
      expect(find.text("Accessibility Features"), findsOneWidget);

      await tester.tap(find.text("Close"));
      await tester.pumpAndSettle();
      expect(find.text("Accessibility Features"), findsNothing);
    });

    testWidgets("accessibility dialog shows all feature descriptions", (
      final tester,
    ) async {
      testBuilding = Building(
        id: "H",
        googlePlacesId: null,
        name: "Science Hall",
        description: "Test building.",
        street: "7141 Rue Sherbrooke O",
        postalCode: "H4B 1R6",
        location: const Coordinate(latitude: 45.4572, longitude: -73.6404),
        hours: OpeningHoursDetail(),
        campus: Campus.loyola,
        outlinePoints: [],
        images: [],
        buildingFeatures: [
          BuildingFeature.wheelChairAccess,
          BuildingFeature.elevator,
          BuildingFeature.escalator,
          BuildingFeature.bathroom,
          BuildingFeature.metroAccess,
          BuildingFeature.food,
          BuildingFeature.shuttleBus,
        ],
      );
      await pumpBuildingDetailScreen(tester);
      await tester.tap(find.byWidgetPredicate(
            (final w) => w is FloatingActionButton && w.heroTag == "accessibility_info", ));
      await tester.pumpAndSettle();

      expect(find.text("Wheelchair Accessible"), findsOneWidget);
      expect(find.text("Elevator Available"), findsOneWidget);
      expect(find.text("Escalator Available"), findsOneWidget);
      expect(find.text("Restrooms Available"), findsOneWidget);
      expect(find.text("Metro Access"), findsOneWidget);
      expect(find.text("Food Services"), findsOneWidget);
      expect(find.text("Shuttle Bus Stop"), findsOneWidget);
    });

    testWidgets("displays OpeningHoursWidget when hours present", (
      final tester,
    ) async {
      testBuilding = Building(
        id: "H",
        googlePlacesId: null,
        name: "Science Hall",
        description: "Test building.",
        street: "7141 Rue Sherbrooke O",
        postalCode: "H4B 1R6",
        location: const Coordinate(latitude: 45.4572, longitude: -73.6404),
        hours: OpeningHoursDetail(
          periods: [
            OpeningHoursPeriod(
              open: OpeningHoursPeriodDate(day: 1, time: "0900"),
              close: OpeningHoursPeriodDate(day: 1, time: "1700"),
            ),
          ],
        ),
        campus: Campus.loyola,
        outlinePoints: [],
        images: [],
        buildingFeatures: null,
      );
      await pumpBuildingDetailScreen(tester);
      expect(find.byType(OpeningHoursWidget), findsOneWidget);
    });
  });
}
