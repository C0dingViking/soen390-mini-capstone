import "package:concordia_campus_guide/main.dart";
import "package:concordia_campus_guide/ui/home/widgets/home_screen.dart";
import "package:concordia_campus_guide/controllers/coordinates_controller.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:patrol/patrol.dart";

void main() {
  patrolTest("Swipe gestures on map", ($) async {
    await $.pumpWidgetAndSettle(const MyApp());

    final mapFinder = find.byType(GoogleMap);
    await $.tester.pumpAndSettle();

    final homeScreenState = $.tester.state<State<HomeScreen>>(
      find.byType(HomeScreen),
    );
    final coordsController =
        ((homeScreenState as dynamic).coordsController)
            as CoordinatesController;
    final controller = await coordsController.mapController;

    // The tests use the southwest corner of the visible map as reference to determine whether movement has occurred.

    final initialRegion = await controller.getVisibleRegion();
    $.log(
      "Initial position: ${initialRegion.southwest.latitude.toStringAsFixed(4)}, ${initialRegion.southwest.longitude.toStringAsFixed(4)}",
    );

    // Add delay for map rendering
    await $.pump(const Duration(seconds: 2));

    $.log("Swipe left");
    await $.tester.fling(mapFinder, const Offset(-300, 0), 800);
    await $.tester.pumpAndSettle();

    final afterLeft = await controller.getVisibleRegion();
    $.log(
      "After left swipe: ${afterLeft.southwest.latitude.toStringAsFixed(4)}, ${afterLeft.southwest.longitude.toStringAsFixed(4)}",
    );
    expect(
      afterLeft.southwest.longitude,
      isNot(closeTo(initialRegion.southwest.longitude, 0.00001)),
      reason: "Map should move after left swipe",
    );

    $.log("Swipe right");
    await $.tester.fling(mapFinder, const Offset(300, 0), 800);
    await $.tester.pumpAndSettle();

    final afterRight = await controller.getVisibleRegion();
    $.log(
      "After right swipe: ${afterRight.southwest.latitude.toStringAsFixed(4)}, ${afterRight.southwest.longitude.toStringAsFixed(4)}",
    );
    expect(
      afterRight.southwest.longitude,
      isNot(closeTo(afterLeft.southwest.longitude, 0.00001)),
      reason: "Map should move after right swipe",
    );

    $.log("Swipe up");
    await $.tester.fling(mapFinder, const Offset(0, -300), 800);
    await $.tester.pumpAndSettle();

    final afterUp = await controller.getVisibleRegion();
    $.log(
      "After up swipe: ${afterUp.southwest.latitude.toStringAsFixed(4)}, ${afterUp.southwest.longitude.toStringAsFixed(4)}",
    );
    expect(
      afterUp.southwest.latitude,
      isNot(closeTo(afterRight.southwest.latitude, 0.00001)),
      reason: "Map should move after up swipe",
    );

    $.log("Swipe down");
    await $.tester.fling(mapFinder, const Offset(0, 300), 800);
    await $.tester.pumpAndSettle();

    final afterDown = await controller.getVisibleRegion();
    $.log(
      "After down swipe: ${afterDown.southwest.latitude.toStringAsFixed(4)}, ${afterDown.southwest.longitude.toStringAsFixed(4)}",
    );
    expect(
      afterDown.southwest.latitude,
      isNot(closeTo(afterUp.southwest.latitude, 0.00001)),
      reason: "Map should move after down swipe",
    );
  });
}
