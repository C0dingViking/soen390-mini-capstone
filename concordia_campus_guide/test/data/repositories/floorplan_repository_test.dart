import "dart:io";
import "dart:math";

import "package:concordia_campus_guide/data/repositories/floorplan_repository.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:flutter_test/flutter_test.dart";
import "package:logger/logger.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Floorplan Repository", () {
    late FloorplanRepository repo;

    setUp(() {
      Logger.level = Level.off;
      repo = FloorplanRepository(
        floorplanLoader: (final path) async {
          return File(path).readAsString();
        },
        manifestPath: "test/assets/test_floorplan_manifest.json",
      );
    });

    test("loads a set of floorplans with correct data", () async {
      final floorplans = await repo.loadBuildingFloorplans("testSvgs");

      expect(floorplans.length, 2);

      final Floorplan? floorplan1 = floorplans[1];
      expect(floorplan1, isNotNull);
      expect(floorplan1!.buildingId, "vl");
      expect(floorplan1.floorNumber, 1);
      expect(floorplan1.rooms.length, 2);
      expect(floorplan1.rooms[0].name, "202-1");
      expect(floorplan1.rooms[0].points.length, 4);
      expect(floorplan1.rooms[1].name, "240");
      expect(floorplan1.pois.length, 2);
      expect(floorplan1.pois[0].name, "stairs-2");
      expect(floorplan1.pois[0].location, Point(753.37836, 768.33722));
      expect(floorplan1.pois[1].name, "stairs-1");

      final Floorplan? floorplan2 = floorplans[2];
      expect(floorplan2, isNotNull);
      expect(floorplan2!.buildingId, "vl");
      expect(floorplan2.floorNumber, 2);
      expect(floorplan2.rooms.length, 1);
      expect(floorplan2.rooms[0].name, "205");
      expect(floorplan2.pois.length, 2);
      expect(floorplan2.pois[0].name, "washroomMale-1");
      expect(floorplan2.pois[1].name, "washroomFemale-1");
    });

    test("fails gracefully if file is not found", () async {
      final floorplans = await repo.loadBuildingFloorplans("test/assets/nonexistent_directory");
      expect(floorplans, isEmpty);
    });

    test("fails gracefully if manifest format is invalid", () async {
      final invalidRepo = FloorplanRepository(
        floorplanLoader: (final path) async {
          return "{}"; // empty manifest
        },
        manifestPath: "test/assets/invalid_manifest.json",
      );

      final floorplans = await invalidRepo.loadBuildingFloorplans("testSvgs");
      expect(floorplans, isEmpty);
    });
  });
}
