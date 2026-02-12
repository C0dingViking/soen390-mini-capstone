import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/ui/directions/widgets/searchable_building_field.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_google_maps_webservices/places.dart";

void main() {
  testWidgets("SearchableBuildingField triggers filter, shows list, and selects item",
          (WidgetTester tester) async {
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
                onSelected: (b) => selected = b,
              ),
            ),
          ),
        );

        // Tap → triggers onTap → calls _filter()
        await tester.tap(find.byType(TextField));
        await tester.pump();            // IMPORTANT
        await tester.pumpAndSettle();

        expect(find.text("Hall Building (H)"), findsOneWidget);
        expect(find.text("EV Building (EV)"), findsOneWidget);

        // Type → triggers _filter("Hall")
        await tester.enterText(find.byType(TextField), "Hall");
        await tester.pump();            // IMPORTANT
        await tester.pumpAndSettle();

        expect(find.text("Hall Building (H)"), findsOneWidget);
        expect(find.text("EV Building (EV)"), findsNothing);

        // Tap → triggers onSelected + hides list
        await tester.tap(find.text("Hall Building (H)"));
        await tester.pump();            // IMPORTANT
        await tester.pumpAndSettle();

        expect(selected?.id, "h");
        expect(find.text("Hall Building (H)"), findsNothing);
      });
}
