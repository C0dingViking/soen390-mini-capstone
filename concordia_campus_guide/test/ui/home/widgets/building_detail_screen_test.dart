import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/ui/home/widgets/building_detail_screen.dart";
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

    testWidgets("displays building name in app bar", (final tester) async {
      await pumpBuildingDetailScreen(tester);
      expect(find.text("Science Hall"), findsOneWidget);
    });

    testWidgets("displays back button in app bar", (final tester) async {
      await pumpBuildingDetailScreen(tester);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets("displays building description", (final tester) async {
      await pumpBuildingDetailScreen(tester);
      expect(
        find.textContaining("A large, modern science teaching"),
        findsOneWidget,
      );
    });

    testWidgets("displays building features icons", (final tester) async {
      await pumpBuildingDetailScreen(tester);
      expect(find.byIcon(Icons.accessible), findsOneWidget);
      expect(find.byIcon(Icons.elevator), findsOneWidget);
      expect(find.byIcon(Icons.wc), findsOneWidget);
    });

    testWidgets("does not display features section when no features", (
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
      expect(find.byIcon(Icons.elevator), findsNothing);
    });

    testWidgets("displays placeholder when no images available", (
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
      expect(find.byIcon(Icons.apartment), findsOneWidget);
    });

    testWidgets("back button pops navigation", (final tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
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

      expect(find.text("Science Hall"), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text("Go to Building"), findsOneWidget);
      expect(find.text("Science Hall"), findsNothing);
    });

    testWidgets("displays all building feature types correctly", (
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
        ],
      );
      await pumpBuildingDetailScreen(tester);

      expect(find.byIcon(Icons.accessible), findsOneWidget);
      expect(find.byIcon(Icons.elevator), findsOneWidget);
      expect(find.byIcon(Icons.stairs), findsOneWidget);
      expect(find.byIcon(Icons.wc), findsOneWidget);
      expect(find.byIcon(Icons.train), findsOneWidget);
    });
  });
}
