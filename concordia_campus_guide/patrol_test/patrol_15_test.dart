import "package:concordia_campus_guide/main.dart" as app;
import "package:flutter_test/flutter_test.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:patrol/patrol.dart";

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

    final mapFinder = find.byType(GoogleMap);

    $.log("STEP 3: Tapping the Hall building");
    final center = $.tester.getCenter(mapFinder);
    final tapPoint = center + const Offset(-5, 5);
    await $.tester.tapAt(tapPoint);
    await $.pumpAndSettle();

    $.log("STEP 4: Waiting for building info to appear...");
    await $.tester.pump(const Duration(seconds: 5));

    $.log("TEST COMPLETE");
  });
}
