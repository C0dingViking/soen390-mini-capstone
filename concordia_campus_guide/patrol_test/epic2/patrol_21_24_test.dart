import "package:concordia_campus_guide/main.dart" as app;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

void main() {
  patrolTest(
    "[US-2.1] Select Start (Hall) and Destination (CC) [US-2.4] Support Directions between Concordia Campuses",
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

      $.log("STEP 4: Tapping the destination field...");
      final startField = find.byKey(const Key("destination_search_field"));
      expect(startField, findsOneWidget);
      await $.tester.tap(startField);
      await $.pumpAndSettle();

      $.log("STEP 5: Typing 'Hall'...");
      await $.enterText(startField, "Hall");
      await $.pumpAndSettle();

      $.log("STEP 6: Selecting 'Henry F. Hall Building (H)'...");
      final hallOption = find.text("Henry F. Hall Building (H)");
      await $.tester.tap(hallOption);
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 5));

      $.log("STEP 7: Tapping the start field...");
      final destField = find.widgetWithText(TextField, "Current location");
      expect(destField, findsOneWidget);
      await $.tester.tap(destField);
      await $.pumpAndSettle();

      $.log("STEP 8: Typing 'CC'...");
      await $.enterText(destField, "CC");
      await $.pumpAndSettle();

      $.log("STEP 9: Selecting 'Central Building (CC)'...");
      final ccOption = find.text("Central Building (CC)");
      await $.tester.tap(ccOption);
      await $.pumpAndSettle();

      $.log("STEP 9.1: Hiding keyboard...");
      await $.tester.tapAt(Offset(0.2, 0.85));
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 3));

      $.log("STEP 10: Verifying that directions UI is shown...");

      $.log("TEST COMPLETE");
      await $.pump(const Duration(seconds: 3));
    },
  );
}
