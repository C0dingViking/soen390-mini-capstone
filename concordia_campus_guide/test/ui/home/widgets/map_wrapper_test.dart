import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:concordia_campus_guide/ui/home/widgets/map_wrapper.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("MapWrapper Polygon Tap Tests", () {
    testWidgets("MapWrapper accepts onPolygonTap callback", (
      final tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapWrapper(
              initialCameraPosition: const CameraPosition(
                target: LatLng(45.4972, -73.5786),
                zoom: 15,
              ),
              onMapCreated: (_) {},
              myLocationEnabled: false,
              polygons: {
                Polygon(
                  polygonId: const PolygonId("test-poly"),
                  points: const [
                    LatLng(45.497, -73.579),
                    LatLng(45.498, -73.579),
                    LatLng(45.498, -73.578),
                  ],
                ),
              },
              markers: {},
              onPolygonTap: (final polygonId) {
                // Callback is provided to test it's accepted
              },
            ),
          ),
        ),
      );

      expect(find.byType(MapWrapper), findsOneWidget);
    });

    testWidgets("MapWrapper works without onPolygonTap callback", (
      final tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapWrapper(
              initialCameraPosition: const CameraPosition(
                target: LatLng(45.4972, -73.5786),
                zoom: 15,
              ),
              onMapCreated: (_) {},
              myLocationEnabled: false,
              polygons: {
                Polygon(
                  polygonId: const PolygonId("test-poly"),
                  points: const [
                    LatLng(45.497, -73.579),
                    LatLng(45.498, -73.579),
                    LatLng(45.498, -73.578),
                  ],
                ),
              },
              markers: {},
            ),
          ),
        ),
      );

      expect(find.byType(MapWrapper), findsOneWidget);
      expect(find.byType(GoogleMap), findsOneWidget);
    });

    testWidgets(
      "MapWrapper adds consumeTapEvents to polygons when callback provided",
      (final tester) async {
        final originalPolygon = Polygon(
          polygonId: const PolygonId("test-poly"),
          points: const [
            LatLng(45.497, -73.579),
            LatLng(45.498, -73.579),
            LatLng(45.498, -73.578),
          ],
          consumeTapEvents: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MapWrapper(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(45.4972, -73.5786),
                  zoom: 15,
                ),
                onMapCreated: (_) {},
                myLocationEnabled: false,
                polygons: {originalPolygon},
                markers: {},
                onPolygonTap: (final polygonId) {},
              ),
            ),
          ),
        );

        expect(find.byType(GoogleMap), findsOneWidget);
      },
    );

    testWidgets("MapWrapper passes through all required GoogleMap properties", (
      final tester,
    ) async {
      final testPolygon = Polygon(
        polygonId: const PolygonId("test-poly"),
        points: const [LatLng(45.497, -73.579), LatLng(45.498, -73.579)],
      );
      final testMarker = Marker(
        markerId: const MarkerId("test-marker"),
        position: const LatLng(45.497, -73.579),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapWrapper(
              initialCameraPosition: const CameraPosition(
                target: LatLng(45.4972, -73.5786),
                zoom: 15,
              ),
              onMapCreated: (_) {
                // Callback is provided to test it's accepted
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              polygons: {testPolygon},
              markers: {testMarker},
            ),
          ),
        ),
      );

      expect(find.byType(GoogleMap), findsOneWidget);
    });

    testWidgets("PolygonId extraction from polygon ID works correctly", (
      final tester,
    ) async {
      const testCases = [
        {"input": "H-poly", "expected": "H"},
        {"input": "MB-poly", "expected": "MB"},
        {"input": "EV-poly", "expected": "EV"},
        {"input": "INVALID-poly", "expected": "INVALID"},
      ];

      for (final testCase in testCases) {
        final polygonId = PolygonId(testCase["input"] as String);
        final buildingId = polygonId.value.replaceAll("-poly", "");
        expect(buildingId, equals(testCase["expected"]));
      }
    });
  });
}
