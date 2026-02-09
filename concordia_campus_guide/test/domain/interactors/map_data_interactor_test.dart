import "dart:io";
import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/models/building_map_data.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:flutter_google_maps_webservices/places.dart";
import "package:flutter_test/flutter_test.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:logger/logger.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Map Data Interactor", () {
    late MapDataInteractor mdi;

    setUp(() {
      Logger.level = Level.off;
      final repo = BuildingRepository(
        buildingLoader: (final path) async {
          return File(path).readAsString();
        },
      );
      mdi = MapDataInteractor(buildingRepo: repo);
    });

    test("loads building payload correctly", () async {
      final BuildingMapDataDTO payload = await mdi.loadBuildingsWithMapElements(
        "test/assets/building_testdata.json",
        AppTheme.concordiaMaroon,
      );

      expect(payload.buildings.length, 1);
      expect(payload.buildingMarkers.length, 1);
      expect(payload.buildingOutlines.length, 1);
      expect(payload.errorMessage, isNull);

      final building = payload.buildings["t"]!;
      expect(building.id, "t");
      expect(building.name, "Test Building (T)");
      expect(building.location.latitude, closeTo(45.67, 1e-6));
      expect(building.outlinePoints.length, 3);
      expect(building.outlinePoints[0].latitude, closeTo(45.5, 1e-6));

      final polygon = payload.buildingOutlines.first;
      expect(polygon.polygonId.value, "t-poly");

      final marker = payload.buildingMarkers.first;
      expect(marker.markerId.value, "t-marker");
    });

    test("carries error message on failure", () async {
      final BuildingMapDataDTO payload = await mdi.loadBuildingsWithMapElements(
        "test/assets/building_testdata2.json",
        AppTheme.concordiaMaroon,
      );

      expect(payload.buildings.isEmpty, true);
      expect(payload.buildingOutlines.isEmpty, true);
      expect(payload.buildingMarkers.isEmpty, true);
      expect(payload.errorMessage, "Failed to load building data.");
    });

    test("polygons are properly produced from building objects", () {
      final b = Building(
        id: "p",
        name: "Polygon Test",
        description: "Test polygon building",
        street: "123 St.",
        postalCode: "P0L Y00",
        location: Coordinate(latitude: 0.0, longitude: 0.0),
        hours: OpeningHoursDetail(),
        campus: Campus.sgw,
        outlinePoints: [
          Coordinate(latitude: 0.0, longitude: 0.0),
          Coordinate(latitude: 0.0, longitude: 1.0),
          Coordinate(latitude: 1.0, longitude: 0.0),
        ],
        buildingFeatures: [],
        images: [],
      );

      final polygons = mdi.generateBuildingPolygons([
        b,
      ], AppTheme.concordiaMaroon);
      expect(polygons.length, 1);

      final poly = polygons.first;
      expect(poly.polygonId.value, "p-poly");
      expect(poly.points.length, 3);
      expect(poly.points[1].latitude, 0.0);
      expect(poly.points[1].longitude, 1.0);
      expect(poly.strokeColor, AppTheme.concordiaMaroon);
    });

    test("the centroid of the polygon is properly computed", () {
      final List<Coordinate> points = [
        Coordinate(latitude: 0.0, longitude: 0.0),
        Coordinate(latitude: 0.0, longitude: 1.0),
        Coordinate(latitude: 1.0, longitude: 0.0),
      ];

      final b = Building(
        id: "c",
        name: "Centroid Test",
        description: "Test centroid building",
        street: "1 Test St.",
        postalCode: "C0R N34",
        location: Coordinate(latitude: 0.0, longitude: 0.0),
        hours: OpeningHoursDetail(),
        campus: Campus.sgw,
        outlinePoints: points,
        buildingFeatures: [],
        images: [],
      );

      final markers = mdi.generateBuildingMarkers([b]);
      final LatLng marker = markers.first.position;

      // centroid of triangle (0,0),(0,1),(1,0) is (1/3, 1/3)
      expect(marker.latitude, closeTo(1 / 3, 1e-6));
      expect(marker.longitude, closeTo(1 / 3, 1e-6));
    });
  });
}
