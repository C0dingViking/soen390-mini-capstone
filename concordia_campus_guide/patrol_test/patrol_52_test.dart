import "package:concordia_campus_guide/main.dart" as app;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

void main() {
  patrolTest("[US-5.2] Show directions to a selected outdoor point of interest", (final $) async {

    $.log("STEP 1: Launching the app...");
    app.main();
    await $.pumpAndSettle();

    $.log("STEP 2: Handling location permission popup...");
    await $.platformAutomator.tap(
      Selector(text: "Only this time"),
      timeout: const Duration(seconds: 10),);

    $.log("STEP 3: Waiting for UI to settle...");
    await $.pumpAndSettle();
    await $.pump(const Duration(seconds: 6));

    $.log("STEP 4: Tapping the search bar...");
    final searchField = find.widgetWithText(TextField, "Enter your destination");
    expect(searchField, findsOneWidget);
    await $.tester.tap(searchField);
    await $.pumpAndSettle();

    $.log("STEP 5: Typing 'Sushi' to search for sushi places around");
    await $.enterText(searchField, "Sushi");
    await $.pumpAndSettle();

    await $.pump(const Duration(seconds: 2));

    //Katsuya Montréal
    $.log("STEP 6: Selecting 'Katsuya Montréal'...");
    final sushiPlace = find.text("Katsuya Montréal");
    await $.tester.tap(sushiPlace);
    await $.pumpAndSettle();

    $.log("Waiting for keyboard to hide...");
    await $.pump(const Duration(seconds: 300));

    $.log("STEP 6: Opening nearby-limit menu...");
    await $.tap(find.byIcon(Icons.tune));
    await $.pumpAndSettle();
    await $.pump(const Duration(seconds: 3));

    $.log("STEP 7: Selecting 'Show Nearest 10 Locations'...");
    await $.tap(find.text("Show Nearest 10 Locations"));
    await $.pumpAndSettle();

    $.log("TEST COMPLETE");
    await $.pump(const Duration(seconds: 5));
  });
}
