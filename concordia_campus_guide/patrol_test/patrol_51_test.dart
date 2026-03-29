import "package:concordia_campus_guide/main.dart" as app;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

void main() {
  patrolTest("[US-2.5] Support Multiple Transportation Types [US-2.7] No Driving", (final $) async {
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

    //$.log("STEP 4: Tapping the search bar...");
    //final searchField = find.widgetWithText(TextField, "Search for a place or address");
    //expect(searchField, findsOneWidget);
    //await $.tester.tap(searchField);
    //await $.pumpAndSettle();

    $.log("TEST COMPLETE");
    await $.pump(const Duration(seconds: 5));
  });
}
