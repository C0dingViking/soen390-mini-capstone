import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

import "package:concordia_campus_guide/main.dart" as app;

//Precondition is the user must have signed in with Google at least
//once before running this test, and the app must have permission to access
//the user's calendar. This test will not work if the user has never signed in
//before or if calendar permissions are denied.
void main() {
  patrolTest(
    "[US-3.1] Connect to User Calendar",
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
      await $.pump(const Duration(seconds: 6));

      $.log("STEP 4: Tapping Hamburger Icon...");
      await $(#hamburger_button).tap();
      await $.pumpAndSettle();

      $.log("STEP 5: Tapping Login/Logout Tile...");
      await $(#hamburger_login_tile).tap();
      await $.pumpAndSettle();

      $.log("Step 6: Tap Sign in With Google...");
      final signin = find.text("Sign in with Google");
      await $.tester.tap(signin);
      await $.pump(const Duration(seconds: 3));

      // ignore: deprecated_member_use
      await $.native.tapAt(const Offset(0.48, 0.53));

      await $.pumpAndSettle();

      // ignore: deprecated_member_use
      await $.native.tapAt(const Offset(0.48, 0.588));

      $.log("STEP 7: Open Hamburger and tapping Import Google Calendar...");
      await $(#hamburger_button).tap();
      await $.pumpAndSettle();
      if ($.tester.any(find.byKey(const Key("hamburger_calendar")))) {
        await $(#hamburger_calendar).tap();
        await $.pumpAndSettle();
      }

      $.log("TEST COMPLETE");
      await $.pump(const Duration(seconds: 1));
    },
  );
}
