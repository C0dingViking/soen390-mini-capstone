import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

import "package:concordia_campus_guide/main.dart" as app;

void main() {
  patrolTest(
    "[US-4.3] Accessibility-Aware Indoor Directions",
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

      $.log("STEP 4: Opening Vanier Library Building Information page...");
      await $(#destination_search_field).tap();
      await $.pumpAndSettle();

      await $.enterText($(#destination_search_field), "VL");
      await $.pumpAndSettle();

      final infoButton = find.byKey(const Key("building_info_Vanier Library Building (VL)"));
      await $.tester.tap(infoButton);
      await $.pumpAndSettle();

      $.log("STEP 5: Opening Floor Plans...");
      await $(#floor_plans_button).tap();
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 5));

      $.log("STEP 6: Selecting Accessibility-Aware Route and Starting the Navigation...");
      await $.pumpAndSettle();
      final accessibilityToggle = find.byKey(const Key("accessibility_mode_toggle"));
      await $.tester.tap(accessibilityToggle);
      await $.pumpAndSettle();

      $.log("STEP 7: Selecting Start and Destination Rooms...");
      final indoorSearchCard = find.byKey(const Key("indoor_search_card"));
      expect(indoorSearchCard, findsOneWidget, reason: "Indoor search card should be visible");
      $.log("Indoor search card is visible");

      final startSearchField = find.byKey(Key("indoor_start_search_field"));
      final destinationSearchField = find.byKey(Key("indoor_destination_search_field"));

      await $.tester.tap(startSearchField);
      await $.platform.android.pressBack();
      await $.pumpAndSettle();

      await $.enterText(startSearchField, "VL 204");
      await $.pumpAndSettle();

      await $.tester.tap(destinationSearchField);
      await $.pumpAndSettle();

      await $.enterText(destinationSearchField, "VL 104-1");
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 2));

      final startNavigationButton = find.byKey(const Key("start_navigation_button"));
      expect(startNavigationButton, findsOneWidget);
      await $.tester.tap(startNavigationButton);
      await $.pump(const Duration(seconds: 5));

      $.log("STEP 8: Verifying that the Indoor Path is Displayed on the Map...");
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
