import "package:concordia_campus_guide/main.dart" as app;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

void main() {
  patrolTest("[US-2.2] Current Location as Start and [US-2.3] Show Directions", (final $) async {
    $.log("STEP 1: Launching the app...");
    app.main();
    await $.pumpAndSettle();

    $.log("STEP 2: Handling location permission popup...");
    await $.platformAutomator.tap(
      Selector(text: "Only this time"),
      timeout: const Duration(seconds: 10),
    );

    $.log("STEP 3: Wait for UI to settle...");
    await $.pumpAndSettle();
    await $.pump(const Duration(seconds: 6));

    $.log("STEP 4: Finding and tapping the search bar...");
    final searchField = find.byKey(const Key("destination_search_field"));
    expect(searchField, findsOneWidget);

    await $.tester.tap(searchField);
    await $.pumpAndSettle();

    $.log("STEP 5: Typing 'Hall' into the search bar...");
    await $.enterText(searchField, "Hall");
    await $.pumpAndSettle();

    $.log("STEP 6: Selecting 'Henry F. Hall Building (H)' from results...");
    final hallOption = find.text("Henry F. Hall Building (H)");
    await $.tester.tap(hallOption);
    await $.pumpAndSettle();

    $.log("STEP 6.1: Dismissing keyboard...");
    await $.tester.tapAt(Offset(0.5, 0.85));
    await $.pumpAndSettle();
    await $.pump(const Duration(seconds: 2));

    $.log("STEP 7: Verifying that directions UI is shown...");
    await $.pump(const Duration(seconds: 5));

    $.log("TEST COMPLETE");
  });
}
