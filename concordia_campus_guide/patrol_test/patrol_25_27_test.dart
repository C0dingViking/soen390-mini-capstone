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

    $.log("STEP 4: Tapping the search bar...");
    final searchField = find.widgetWithText(TextField, "Search for a place or address");
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
    await $.pump(const Duration(seconds: 3));

    $.log("STEP 7: Expanding Route Details Panel...");
    final handle = find.byKey(const Key("route_details_handle"));
    expect(handle, findsOneWidget);
    await $.tester.tap(handle);
    await $.pumpAndSettle();
    await $.pump(const Duration(seconds: 2));

    $.log("STEP 8: Checking available transportation modes...");

    final walk = find.text("Walk");
    final bike = find.text("Bike");
    final transit = find.text("Transit");
    final shuttle = find.text("Shuttle");
    final driving = find.text("Driving");

    expect(walk, findsOneWidget, reason: "Walk must be available");
    $.log("Walking option exists");
    expect(bike, findsOneWidget, reason: "Bike must be available");
    $.log("Bike option exists");
    expect(transit, findsOneWidget, reason: "Transit must be available");
    $.log("Transit option exists");
    expect(shuttle, findsOneWidget, reason: "Shuttle must be available");
    $.log("Shuttle option exists");

    expect(driving, findsNothing, reason: "Driving must NOT be available");
    $.log("Driving option does NOT exists");

    $.log("TEST COMPLETE");
    await $.pump(const Duration(seconds: 5));
  });
}
