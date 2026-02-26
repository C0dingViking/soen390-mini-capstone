import "dart:io";

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
      );
    });

    test("loads a set of floorplans with correct data", () async {
      final floorplans = await repo.loadBuildingFloorplans("test/assets/testSvgs");

      expect(floorplans.length, 2);

      final Floorplan? floorplan1 = floorplans[1];
      expect(floorplan1, isNotNull);
      expect(floorplan1!.buildingId, "mb");
      expect(floorplan1.floorNumber, 1);
      expect(floorplan1.rooms.length, 2);
      expect(floorplan1.rooms[0].name, "126");
      expect(floorplan1.rooms[0].points.length, 4);
      expect(floorplan1.rooms[1].name, "125");

      final Floorplan? floorplan2 = floorplans[2];
      expect(floorplan2, isNotNull);
      expect(floorplan2!.buildingId, "mb");
      expect(floorplan2.floorNumber, 2);
      expect(floorplan2.rooms.length, 4);
      expect(floorplan2.rooms[3].points.length, 5); // equal to the number of path tokens
    });

    test("fails gracefully if file is not found", () async {
      final floorplans = await repo.loadBuildingFloorplans("test/assets/nonexistent_directory");
      expect(floorplans, isEmpty);
    });

    test("fails gracefully if file is named incorrectly", () async {
      final floorplans = await repo.loadBuildingFloorplans("test/assets/wrongname_2.svg");
      expect(floorplans, isEmpty);
    });
  });
}
