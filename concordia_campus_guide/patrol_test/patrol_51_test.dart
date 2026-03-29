import "package:concordia_campus_guide/main.dart" as app;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

void main() {
  patrolTest("[US-5.1] Show the nearest outdoor points of interest", (final $) async {
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

    $.log("STEP 4: Tapping the search bar...");
    final searchField = find.widgetWithText(TextField, "Enter your destination");
    expect(searchField, findsOneWidget);
    await $.tester.tap(searchField);
    await $.pumpAndSettle();

    $.log("STEP 5: Typing 'Sushi' to search for sushi places around");
    await $.enterText(searchField, "Sushi");
    await $.pumpAndSettle();

    await $.tester.testTextInput.receiveAction(TextInputAction.search);
    await $.pumpAndSettle();

    await $.pump(const Duration(seconds: 50));

    $.log("TEST COMPLETE");
    await $.pump(const Duration(seconds: 5));
  });
}
