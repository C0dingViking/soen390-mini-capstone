import "package:concordia_campus_guide/main.dart" as app;
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";
import "package:flutter/material.dart";

void main() {
  patrolTest("US 1.5 Show Building info", (final $) async {
    $.log("STEP 1: Launching the app...");
    app.main();
    await $.pumpAndSettle();

    $.log("STEP 2: Handling location permission popup...");
    await $.platformAutomator.tap(
      Selector(text: "Only this time"),
      timeout: const Duration(seconds: 10),
    );

    await $.pumpAndSettle();
    await $.pump(const Duration(seconds: 6));

    $.log("STEP 4: Opening Hall Building Information page...");
    await $(#destination_search_field).tap();
    await $.pumpAndSettle();

    await $.enterText($(#destination_search_field), "Hall");
    await $.pumpAndSettle();

    final hallInfoButton = find.byKey(const Key("building_info_Henry F. Hall Building (H)"));
    await $.tester.tap(hallInfoButton);
    await $.pumpAndSettle();

    $.log("STEP 5: Verifying Building Name and Address are visible...");
    final buildingName = find.byKey(const Key("building_name"));
    expect(buildingName, findsOneWidget, reason: "Building name should be displayed");
    $.log("Building name is visible");

    final buildingAddress = find.byKey(const Key("building_address"));
    expect(buildingAddress, findsOneWidget, reason: "Building address should be displayed");
    $.log("Building address is visible");

    await $.pump(const Duration(seconds: 5));
  });
}
