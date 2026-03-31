import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

import "package:concordia_campus_guide/main.dart" as app;

void main() {
  patrolTest(
    "[US-4.7] Indoor Directions Between Campuses",
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

      $.log("STEP 4: Tapping the destination field...");
      final destinationField = find.byKey(const Key("destination_search_field"));
      expect(destinationField, findsOneWidget);
      await $.tester.tap(destinationField);
      await $.pumpAndSettle();

      $.log("STEP 4.1: Hiding keyboard...");
      await $.platform.android.pressBack(); //needed for to hide the keyboard on Android, otherwise UI layout issues occur when trying to tap the start field
      await $.pumpAndSettle();

      $.log("STEP 5: Entering 'VL 101' as destination...");
      await $.enterText(destinationField, "VL 101");
      await $.pumpAndSettle();

      $.log("STEP 6: Selecting 'VL 101-1'...");
      final vlOption = find.text("VL 101-1");
      await $.tester.tap(vlOption);
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 3));

      $.log("STEP 7: Tapping the start field...");
      final startField = find.widgetWithText(TextField, "Current location");
      expect(startField, findsOneWidget);
      await $.tester.tap(startField);
      await $.pumpAndSettle();

      $.log("STEP 8: Entering 'MB 1.13' as start...");
      await $.enterText(startField, "MB 1.13");
      await $.pumpAndSettle();

      $.log("STEP 9: Selecting 'MB 1.132'...");

      final handle = find.byKey(const Key("route_details_handle"));
      expect(handle, findsOneWidget);
      await $.tester.tap(handle);
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 3));

      final mbOption = find.text("MB 1.132");
      await $.tester.tap(mbOption);
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 3));

      $.log("STEP 10: Expanding Route Details Panel...");
      expect(handle, findsOneWidget);
      await $.tester.drag(handle, const Offset(0, -600));
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 2));

      $.log("STEP 11: Go to Indoor Directions...");
      final indoorDirectionsButton = find.byKey(const Key("start_origin_indoor_navigation_button"));
      expect(indoorDirectionsButton, findsOneWidget);
      await $.tester.tap(indoorDirectionsButton);
      await $.pump(const Duration(seconds: 3));

      final indoorPathPainter1 = find.byKey(const Key("indoor_path_painter"));
      expect(
        indoorPathPainter1,
        findsOneWidget,
        reason: "Indoor path should be displayed on the map",
      );

      $.log("STEP 12: Move to Destination Indoor Map...");
      final continueOutdoorsBtn = find.byKey(const Key("continue_outdoor_navigation_button"));
      expect(continueOutdoorsBtn, findsOneWidget);
      await $.tester.tap(continueOutdoorsBtn);
      await $.pumpAndSettle();

      await $.pump(const Duration(seconds: 3));

      final size = $.tester.binding.window.physicalSize /
             $.tester.binding.window.devicePixelRatio;

      final start = Offset(size.width / 2, size.height * 0.75);
      final offset = Offset(0, -600);

      await $.tester.dragFrom(start, offset);
      await $.pumpAndSettle();

      final switchToIndoorNavigationBtn = find.byKey(const Key("switch_to_indoor_navigation_button"));
      await $.tester.tap(switchToIndoorNavigationBtn);
      await $.pump(const Duration(seconds: 3));

      final indoorPathPainter2 = find.byKey(const Key("indoor_path_painter"));
      expect(
        indoorPathPainter2,
        findsOneWidget,
        reason: "Indoor path should be displayed on the map",
      );

    },
  );
}