import "package:concordia_campus_guide/main.dart" as app;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

void main() {
  patrolTest(
    "[US-2.5] Multiple TrDriving Option",
        (final $) async {
      $.log("STEP 1: Launching the app...");
      app.main();
      await $.pumpAndSettle();

      $.log("STEP 2: Handling location permission popup...");
      await $.platformAutomator.tap(
        Selector(text: "Only this time"),
        timeout: const Duration(seconds: 10),
      );

      $.log("STEP 3: Waiting for UI to settle...");
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 6));

      // ---------------- SELECT DESTINATION = HALL ----------------

      $.log("STEP 4: Tapping the search bar...");
      final searchField =
      find.widgetWithText(TextField, "Search for a place or address");
      expect(searchField, findsOneWidget);
      await $.tester.tap(searchField);
      await $.pumpAndSettle();

      $.log("STEP 5: Typing 'CC'...");
      await $.enterText(searchField, "CC");
      await $.pumpAndSettle();

      $.log("STEP 6: Selecting 'Central Building (CC)'...");
      final hallOption = find.text("Central Building (CC)");
      await $.tester.tap(hallOption);
      await $.pumpAndSettle();

      $.log("STEP 6.1: Hiding keyboard...");
      await $.native.tapAt(Offset(0.5, 0.85));
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 1));

      $.log("STEP 7: Expanding Route Details Panel...");
      final handle = find.byKey(const Key("route_details_handle"));
      expect(handle, findsOneWidget);
      await $.tester.tap(handle);
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 2));

      $.log("STEP 9: Selecting Shuttle mode...");
      final shuttle = find.text("Shuttle");
      expect(shuttle, findsOneWidget);
      await $.tester.tap(shuttle);
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 2));

      await $.tester.tap(handle);
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 1));
      await $.tester.tap(handle);
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 1));

      $.log("STEP 10: Waiting for shuttle route to load...");
      await $.pump(const Duration(seconds: 3));

      $.log("TEST COMPLETE");
      await $.pump(const Duration(seconds: 1));
    },
  );
}
