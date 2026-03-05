import "package:concordia_campus_guide/main.dart" as app;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

void main() {
  patrolTest(
    "US 1.1 1.2 1.3",
        (final $) async {
      $.log("PATROL-STEP 1: Launching the app...");
      app.main();
      await $.pumpAndSettle();

      $.log("PATROL-STEP 2: Handling location permission popup...");
      await $.platformAutomator.tap(
        Selector(text: "Only this time"),
        timeout: const Duration(seconds: 10),
      );

      $.log("PATROL-STEP 3: Waiting for UI to settle...");
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 6));

      $.log("PATROL-STEP 4: Locating the campus toggle button...");
      final toggleButton = $(const Key("campus_toggle_button"));
      await toggleButton.waitUntilVisible();

      $.log("PATROL-STEP 5: Tapping the toggle button (switch campus)...");
      await toggleButton.tap();
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 5));

      $.log("PATROL-STEP 6: Tapping the toggle button again to see other campus...");
      await toggleButton.tap();
      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 3));

      $.log("PATROL-STEP 7: Verifying the button still exists...");
      expect(toggleButton.exists, true);

      $.log("PATROL-STEP: TEST COMPLETE");
    },
  );
}
