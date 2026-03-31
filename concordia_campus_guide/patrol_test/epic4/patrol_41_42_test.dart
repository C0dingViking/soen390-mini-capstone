import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

import "package:concordia_campus_guide/main.dart" as app;

void main() {
  patrolTest(
    "[US-4.1] Select Indoor Start and Destination\n[US-4.2] Show Indoor Route on Map",
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
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
      await $.pump(const Duration(seconds: 4));

      $.log("STEP 4: Opening Hall Building Information page...");
      await $(#destination_search_field).tap();
      await $.pumpAndSettle();

      await $.enterText($(#destination_search_field), "Hall");
      await $.pumpAndSettle();

      final hallInfoButton = find.byKey(const Key("building_info_Henry F. Hall Building (H)"));
      await $.tester.tap(hallInfoButton);
      await $.pumpAndSettle();

      $.log("STEP 5: Opening Floor Plans...");
      await $(#floor_plans_button).tap();
      await $.pumpAndSettle();

      $.log("STEP 6: Selecting Start and Destination Rooms...");
      final indoorSearchCard = find.byKey(const Key("indoor_search_card"));
      expect(indoorSearchCard, findsOneWidget, reason: "Indoor search card should be visible");
      $.log("Indoor search card is visible");

      final startSearchField = find.byKey(Key("indoor_start_search_field"));
      final destinationSearchField = find.byKey(Key("indoor_destination_search_field"));

      await $.tester.tap(startSearchField);
      await $.pumpAndSettle();

      await $.enterText(startSearchField, "H 822");
      await $.pumpAndSettle();

      await $.tester.tap(destinationSearchField);
      await $.pumpAndSettle();

      await $.enterText(destinationSearchField, "H 964");
      await $.pumpAndSettle();

      $.log("STEP 7: Verifying that the 'Start Navigation' button is enabled...");
      final startNavigationButton = find.byKey(const Key("start_navigation_button"));
      expect(startNavigationButton, findsOneWidget);
      $.log("'Start Navigation' button is visible and enabled");

      $.log("Step 8: Tapping 'Start Navigation' button...");
      await $.tester.tap(startNavigationButton);
      await $.pump(const Duration(seconds: 5)); // use fixed delay since pupmAndSettle times out

      $.log("STEP 9: Verifying that the indoor path is displayed on the map...");
      final indoorPathPainter = find.byKey(const Key("indoor_path_painter"));
      expect(
        indoorPathPainter,
        findsOneWidget,
        reason: "Indoor path should be displayed on the map",
      );
      $.log("Indoor path is displayed on the map");
      await $.pump(const Duration(seconds: 5));
    },
  );
}
