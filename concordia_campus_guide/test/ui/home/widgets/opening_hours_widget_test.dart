import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/ui/home/widgets/opening_hours_widget.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter/material.dart";
import "package:flutter_google_maps_webservices/places.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("OpeningHoursWidget Tests", () {
    Building createBuildingWithHours(List<OpeningHoursPeriod> periods) {
      return Building(
        id: "TEST",
        googlePlacesId: null,
        name: "Test Building",
        description: "A test building",
        street: "123 Test St",
        postalCode: "H1H 1H1",
        location: const Coordinate(latitude: 45.5, longitude: -73.6),
        hours: OpeningHoursDetail(periods: periods),
        campus: Campus.sgw,
        outlinePoints: [],
        images: [],
        buildingFeatures: null,
      );
    }

    Future<void> pumpWidget(WidgetTester tester, Building building) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OpeningHoursWidget(building: building)),
        ),
      );
    }

    testWidgets("returns empty container when schedule is empty", (
      tester,
    ) async {
      final building = createBuildingWithHours([]);
      await pumpWidget(tester, building);

      expect(find.text("Open"), findsNothing);
      expect(find.text("Closed"), findsNothing);
    });

    testWidgets("displays open/closed status", (tester) async {
      final now = DateTime.now();
      final currentDay = now.weekday % 7;

      final building = createBuildingWithHours([
        OpeningHoursPeriod(
          open: OpeningHoursPeriodDate(day: currentDay, time: "0000"),
          close: OpeningHoursPeriodDate(day: currentDay, time: "2359"),
        ),
      ]);

      await pumpWidget(tester, building);
      await tester.pumpAndSettle();

      expect(find.textContaining(RegExp(r'(Open|Closed)')), findsOneWidget);
    });

    testWidgets("expands and collapses on tap", (tester) async {
      final now = DateTime.now();
      final currentDay = now.weekday % 7;

      final building = createBuildingWithHours([
        OpeningHoursPeriod(
          open: OpeningHoursPeriodDate(day: 1, time: "0900"),
          close: OpeningHoursPeriodDate(day: 1, time: "1700"),
        ),
        OpeningHoursPeriod(
          open: OpeningHoursPeriodDate(day: 2, time: "0900"),
          close: OpeningHoursPeriodDate(day: 2, time: "1700"),
        ),
      ]);

      await pumpWidget(tester, building);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.text("Mon"), findsOneWidget);
      expect(find.text("Tue"), findsOneWidget);
    });

    testWidgets("formats times correctly", (tester) async {
      final now = DateTime.now();
      final currentDay = now.weekday % 7;

      final building = createBuildingWithHours([
        OpeningHoursPeriod(
          open: OpeningHoursPeriodDate(day: currentDay, time: "0900"),
          close: OpeningHoursPeriodDate(day: currentDay, time: "1730"),
        ),
      ]);

      await pumpWidget(tester, building);
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      expect(find.textContaining("9 a.m."), findsOneWidget);
      expect(find.textContaining("5:30 p.m."), findsOneWidget);
    });

    testWidgets("displays multiple days in schedule", (tester) async {
      final building = createBuildingWithHours([
        OpeningHoursPeriod(
          open: OpeningHoursPeriodDate(day: 1, time: "0900"),
          close: OpeningHoursPeriodDate(day: 1, time: "1700"),
        ),
        OpeningHoursPeriod(
          open: OpeningHoursPeriodDate(day: 2, time: "0900"),
          close: OpeningHoursPeriodDate(day: 2, time: "1800"),
        ),
        OpeningHoursPeriod(
          open: OpeningHoursPeriodDate(day: 3, time: "0900"),
          close: OpeningHoursPeriodDate(day: 3, time: "1900"),
        ),
      ]);

      await pumpWidget(tester, building);
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      expect(find.text("Mon"), findsOneWidget);
      expect(find.text("Tue"), findsOneWidget);
      expect(find.text("Wed"), findsOneWidget);
    });
  });
}
