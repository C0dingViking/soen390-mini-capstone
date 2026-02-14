import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/ui/directions/widgets/searchable_building_field.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_google_maps_webservices/places.dart";

void main() {
  testWidgets("SearchableBuildingField triggers filter, shows list, and selects item",
          (final WidgetTester tester) async {
        final buildings = [
          Building(
            id: "h",
            name: "Hall Building",
            description: "",
            street: "",
            postalCode: "",
            location: const Coordinate(latitude: 0, longitude: 0),
            campus: Campus.sgw,
            outlinePoints: [],
            hours: OpeningHoursDetail(
              openNow: true,
              periods: [],
              weekdayText: [],
            ),
            images: [],
          ),
          Building(
            id: "ev",
            name: "EV Building",
            description: "",
            street: "",
            postalCode: "",
            location: const Coordinate(latitude: 0, longitude: 0),
            campus: Campus.sgw,
            outlinePoints: [],
            hours: OpeningHoursDetail(
              openNow: true,
              periods: [],
              weekdayText: [],
            ),
            images: [],
          ),
        ];

        Building? selected;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchableBuildingField(
                buildings: buildings,
                selected: null,
                label: "Test",
                onSelected: (final b) => selected = b,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text("Hall Building"), findsOneWidget);
        expect(find.text("EV Building"), findsOneWidget);

        await tester.enterText(find.byType(TextField), "Hall");
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text("Hall Building"), findsOneWidget);
        expect(find.text("EV Building"), findsNothing);

        await tester.tap(find.text("Hall Building"));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(selected?.id, "h");
        expect(find.text("Hall Building (H)"), findsNothing);
      });
}
