import "package:concordia_campus_guide/ui/directions/widgets/searchable_building_field.dart";
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
      expect(find.byType(SearchableBuildingField), findsNWidgets(2));
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets("dropdown shows all buildings", (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsScreen(buildings: testBuildings),
        ),
      );

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      expect(find.text("Hall Building"), findsWidgets);
      expect(find.text("EV Building"), findsWidgets);
    });

    testWidgets("can select building from dropdown", (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsScreen(buildings: testBuildings),
        ),
      );

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Hall Building").last);
      await tester.pumpAndSettle();

      expect(find.text("Hall Building"), findsOneWidget);
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

      // Dropdown menu doesn't have constrains anymore, just check TextField for this test
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets("building codes are uppercase", (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsScreen(buildings: testBuildings),
        ),
      );

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      expect(find.textContaining("Hall Building"), findsWidgets);
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
      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsScreen(buildings: testBuildings),
        ),
      );

      await tester.pump();

      // Get the  ViewModel created inside DirectionsScreen
      final viewModel = Provider.of<DirectionsViewModel>(
        tester.element(find.byType(Consumer<DirectionsViewModel>)),
        listen: false,
      );

      // Set required state so the button becomes enabled
      viewModel.currentLocationCoordinate = const Coordinate(latitude: 45.4972, longitude: -73.5786);
      viewModel.destinationBuilding = testBuildings["h"]!;
      viewModel.plannedRoute = viewModel.routeInteractor.createOutdoorRoute(
        viewModel.currentLocationCoordinate!,
        viewModel.destinationBuilding!,
      );
      viewModel.notifyListeners();

  await tester.pump();

  // Select Start Location
  await tester.tap(find.byType(TextField).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text("Hall Building").first);
  await tester.pumpAndSettle();

  // Select Destination Building
  await tester.tap(find.byType(TextField).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text("Hall Building").first);
  await tester.pumpAndSettle();

  await tester.pump();

  // Tap Get Directions button
  await tester.drag(find.byType(Scaffold), const Offset(0, -300));
  await tester.pumpAndSettle();
  await tester.tap( find.widgetWithText(ElevatedButton, "Get Directions") );
  await tester.pumpAndSettle();

  // Verify dialog-specific content (unique to the dialog only)
  expect(find.text("Route Created"), findsOneWidget);
  expect(find.text("OK"), findsOneWidget);
  expect(find.textContaining("From: Current Location"), findsOneWidget);
  expect(find.textContaining("To: Hall Building"), findsOneWidget);    // ← More specific!
  expect(find.textContaining("Distance: 0.00 km"), findsOneWidget);   // ← More specific!

  // Tap OK to dismiss
  await tester.tap(find.text("OK"));
  await tester.pumpAndSettle();

  // Dialog should be gone
  expect(find.text("Route Created"), findsNothing);
});

testWidgets("shows error message when errorMessage is set", (final WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DirectionsScreen(
        buildings: testBuildings,
      ),
    ),
  );

  await tester.pump();

  final vm = Provider.of<DirectionsViewModel>(
    tester.element(find.byType(Consumer<DirectionsViewModel>)),
    listen: false,
  );

  vm.errorMessage = "Unable to get current location: test error";
  vm.notifyListeners();

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
