import "package:concordia_campus_guide/main.dart" as app;
import "package:patrol/patrol.dart";

void main() {
  patrolTest(
    "US 1.4 Show Current Campus Building",
        (final $) async {
      $.log("STEP 1: Launching the app...");
      app.main();
      await $.pumpAndSettle();

      $.log("STEP 2: Handling location permission popup...");
      await $.platformAutomator.tap(
        Selector(text: "Only this time"),
        timeout: const Duration(seconds: 10),
      );

      await $.pumpAndSettle();
      await $.pump(const Duration(seconds: 2));

      $.log("STEP 3: Tapping My Location button ...");
      await $(#my_location_key).tap();
      await $.pumpAndSettle();

      $.log("STEP 4: Waiting for map animation...");
      await $.pump(const Duration(seconds: 5));

      $.log("TEST COMPLETE");
    },
  );
}
