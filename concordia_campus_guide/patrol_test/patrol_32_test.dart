import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

import "package:concordia_campus_guide/main.dart" as app;

void main() {
  patrolTest("[US-3.2] Identify next class", 
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

    $.log("STEP 4: Open Hamburger and tapping Import Google Calendar...");
    await $(#hamburger_button).tap();
    await $.pumpAndSettle();
    if ($.tester.any(find.byKey(const Key("hamburger_calendar")))) {
      await $(#hamburger_calendar).tap();
      await $.pumpAndSettle();
    }

    $.log("STEP 5: Tapping Next Class Button...");
    if ($.tester.any(find.byKey(const Key("next_class")))) {
      await $(#next_class).tap();
      await $.pumpAndSettle();
    }

    $.log("TEST COMPLETE");
    await $.pump(const Duration(seconds: 1));
  
  });
}
