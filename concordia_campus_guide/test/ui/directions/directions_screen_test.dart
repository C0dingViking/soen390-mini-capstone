import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";
import "package:concordia_campus_guide/ui/directions/directions_screen.dart";
import "package:concordia_campus_guide/ui/directions/view_models/directions_view_model.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/interactors/route_interactor.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_google_maps_webservices/places.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("DirectionsScreen Widget Tests", () {
    late Map<String, Building> testBuildings;

    setUp(() {
      final mockHours = OpeningHoursDetail.fromJson({
        "open_now": true,
        "periods": [
          {
            "open": {"day": 1, "time": "0700"},
            "close": {"day": 1, "time": "2300"},
          }
        ],
        "weekday_text": ["Monday: 7:00 AM – 11:00 PM"],
      });

      testBuildings = {
        "h": Building(
          id: "h",
          name: "Hall Building",
          description: "Main building on SGW campus",
          street: "1455 De Maisonneuve Blvd. W.",
          postalCode: "H3G 1M8",
          location: const Coordinate(latitude: 45.4970, longitude: -73.5790),
          campus: Campus.sgw,
          outlinePoints: [],
          hours: mockHours,
          images: [],
        ),
        "ev": Building(
          id: "ev",
          name: "EV Building",
          description: "Engineering building",
          street: "1515 St. Catherine St. W.",
          postalCode: "H3G 2W1",
          location: const Coordinate(latitude: 45.4953, longitude: -73.5780),
          campus: Campus.sgw,
          outlinePoints: [],
          hours: mockHours,
          images: [],
        ),
      };
    });

    testWidgets("renders all main UI elements", (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsScreen(buildings: testBuildings),
        ),
      );

      expect(find.text("Start Location"), findsOneWidget);
      expect(find.text("Destination Building"), findsOneWidget);
      expect(find.text("Use Current Location"), findsOneWidget);
      expect(find.text("Select a building"), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets("dropdown shows all buildings", (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsScreen(buildings: testBuildings),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text("Hall Building (H)"), findsWidgets);
      expect(find.text("EV Building (EV)"), findsWidgets);
    });

    testWidgets("can select building from dropdown", (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsScreen(buildings: testBuildings),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Hall Building (H)").last);
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets("shows loading indicator when fetching location", (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsScreen(buildings: testBuildings),
        ),
      );

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("UI has proper layout constraints", (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsScreen(buildings: testBuildings),
        ),
      );

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(DropdownButtonFormField<String>),
          matching: find.byType(Container),
        ),
      );

      expect(container.constraints, const BoxConstraints(maxHeight: 56));
    });

    testWidgets("building codes are uppercase", (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsScreen(buildings: testBuildings),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.textContaining("(H)"), findsWidgets);
      expect(find.textContaining("(h)"), findsNothing);
    });

    testWidgets("shows location state when set", (final WidgetTester tester) async {
      final viewModel = DirectionsViewModel(routeInteractor: RouteInteractor());
      viewModel.currentLocationCoordinate = const Coordinate(latitude: 45.4972, longitude: -73.5786);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DirectionsViewModel>.value(
            value: viewModel,
            child: DirectionsScreen(buildings: testBuildings),
          ),
        ),
      );

      await tester.pump();

      expect(viewModel.currentLocationCoordinate, isNotNull);
      expect(viewModel.currentLocationCoordinate?.latitude, equals(45.4972));
      expect(find.textContaining("Current Location"), findsOneWidget);
    });

    testWidgets("Get Directions button enabled when both inputs set", (final WidgetTester tester) async {
      final viewModel = DirectionsViewModel(routeInteractor: RouteInteractor());
      viewModel.currentLocationCoordinate = const Coordinate(latitude: 45.4972, longitude: -73.5786);
      viewModel.updateDestination(testBuildings["h"]!);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DirectionsViewModel>.value(
            value: viewModel,
            child: DirectionsScreen(buildings: testBuildings),
          ),
        ),
      );

      expect(viewModel.plannedRoute, isNotNull);
      expect(viewModel.canGetDirections, isTrue);
      expect(viewModel.plannedRoute?.destinationBuilding.name, equals("Hall Building"));
    });
    testWidgets("shows route dialog when Get Directions pressed", (final WidgetTester tester) async {
  final viewModel = DirectionsViewModel(routeInteractor: RouteInteractor());
  viewModel.currentLocationCoordinate = const Coordinate(latitude: 45.4972, longitude: -73.5786);
  viewModel.updateDestination(testBuildings["h"]!);

  await tester.pumpWidget(
    MaterialApp(
      home: DirectionsScreen(
        buildings: testBuildings,
        viewModel: viewModel,
      ),
    ),
  );

  await tester.pump();

  // Tap Get Directions button
  final getDirectionsButton = find.descendant(
    of: find.byType(ElevatedButton),
    matching: find.text("Get Directions"),
  );
  await tester.tap(getDirectionsButton);
  await tester.pumpAndSettle();

  // Verify dialog-specific content (unique to the dialog only)
  expect(find.text("Route Created"), findsOneWidget);
  expect(find.text("OK"), findsOneWidget);
  expect(find.textContaining("From: Current Location"), findsOneWidget);
  expect(find.textContaining("To: Hall Building"), findsOneWidget);    // ← More specific!
  expect(find.textContaining("Distance: 0.04 km"), findsOneWidget);   // ← More specific!

  // Tap OK to dismiss
  await tester.tap(find.text("OK"));
  await tester.pumpAndSettle();

  // Dialog should be gone
  expect(find.text("Route Created"), findsNothing);
});

testWidgets("shows error message when errorMessage is set", (final WidgetTester tester) async {
  final viewModel = DirectionsViewModel(routeInteractor: RouteInteractor());
  viewModel.errorMessage = "Unable to get current location: test error";

  await tester.pumpWidget(
    MaterialApp(
      home: DirectionsScreen(
        buildings: testBuildings,
        viewModel: viewModel,
      ),
    ),
  );

  await tester.pump();

  
  expect(find.textContaining("Unable to get current location"), findsOneWidget);

  // Verify error styling
  final errorText = tester.widget<Text>(
    find.textContaining("Unable to get current location"),
  );
  expect(errorText.style?.color, Colors.red);
  expect(errorText.style?.fontSize, 12);
});
  });
}
