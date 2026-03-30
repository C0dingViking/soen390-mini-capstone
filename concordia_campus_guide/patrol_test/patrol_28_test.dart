import "package:concordia_campus_guide/main.dart" as app;
import "package:concordia_campus_guide/ui/home/widgets/route_details_panel.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

void main() {
  patrolTest("[US-2.8] Walking Transport Option: Add Detailed Steps", (final $) async {
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

    $.log("STEP 5: Typing 'Hall'...");
    await $.enterText(searchField, "Hall");
    await $.pumpAndSettle();

    $.log("STEP 6: Selecting 'Henry F. Hall Building (H)'...");
    final hallOption = find.text("Henry F. Hall Building (H)");
    await $.tester.tap(hallOption);
    await $.pumpAndSettle();

    $.log("STEP 6.1: Hiding keyboard...");
    await $.tester.tapAt(Offset(0.5, 0.85));
    await $.pumpAndSettle();
    await $.pump(const Duration(seconds: 1));

    $.log("STEP 7: Expanding Route Details Panel...");
    final handle = find.byKey(const Key("route_details_handle"));
    expect(handle, findsOneWidget);
    await $.tester.tap(handle);
    await $.pumpAndSettle();
    await $.pump(const Duration(seconds: 2));

    await $.tester.tap(handle);
    await $.pumpAndSettle();
    await $.pump(const Duration(seconds: 1));

    $.log("STEP 9: Verifying that detailed walking steps are shown...");
    final stepTiles = find.byType(RouteDetailsPanel);
    expect(stepTiles, findsWidgets, reason: "Detailed walking steps must be visible");

    $.log("RouteDetailsPanel is shown correctly");
    await $.pump(const Duration(seconds: 2));

    $.log("TEST COMPLETE");
    await $.pump(const Duration(seconds: 1));
  });
}
