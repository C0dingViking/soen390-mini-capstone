import "dart:io";

import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:logger/logger.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Building Repository", () {
    late BuildingRepository repo;

    setUp(() {
      Logger.level = Level.off;
      repo = BuildingRepository(
        buildingLoader: (final path) async {
          return File(path).readAsString();
        },
      );
    });

    test("loads a building with correct data", () async {
      final buildings = await repo.loadBuildings(
        "test/assets/building_testdata.json",
      );
      final building = buildings["t"];

      expect(buildings.length, 1);

      // verify the data is parsed correctly
      expect(building, isNotNull);
      expect(building!.id, "t");
      expect(building.name, "Test Building (T)");
      expect(building.street, "1234 Test St.");
      expect(building.postalCode, "TE5 TM3");
      expect(building.location.latitude, 45.67);
      expect(building.location.longitude, -73.21);
      expect(building.campus, Campus.sgw);

      expect(building.outlinePoints.length, 3);
      expect(building.outlinePoints[0].latitude, 45.5);
      expect(building.outlinePoints[0].longitude, -73.2);
      expect(building.outlinePoints[1].latitude, 45.6);
      expect(building.outlinePoints[1].longitude, -73.3);
      expect(building.outlinePoints[2].latitude, 45.7);
      expect(building.outlinePoints[2].longitude, -73.4);

      expect(building.googlePlacesId, "ChIJTest123456789");

      expect(building.description, "A test building for unit testing purposes");

      expect(building.buildingFeatures, isNotNull);
      expect(building.buildingFeatures!.length, 5);
      expect(building.buildingFeatures![0].name, "elevator");
      expect(building.buildingFeatures![1].name, "wheelChairAccess");
      expect(building.buildingFeatures![2].name, "bathroom");
      expect(building.buildingFeatures![3].name, "food");
      expect(building.buildingFeatures![4].name, "shuttleBus");

      final schedule = building.getSchedule();
      expect(schedule, isNotNull);
      expect(schedule.length, 5);

      expect(schedule[0].open?.day, 1);
      expect(schedule[0].open?.time, "0800");
      expect(schedule[0].close?.day, 1);
      expect(schedule[0].close?.time, "2200");

      expect(schedule[1].open?.day, 2);
      expect(schedule[1].open?.time, "0800");
      expect(schedule[1].close?.day, 2);
      expect(schedule[1].close?.time, "2200");

      expect(schedule[2].open?.day, 3);
      expect(schedule[2].open?.time, "0800");
      expect(schedule[2].close?.day, 3);
      expect(schedule[2].close?.time, "2200");

      expect(schedule[3].open?.day, 4);
      expect(schedule[3].open?.time, "0800");
      expect(schedule[3].close?.day, 4);
      expect(schedule[3].close?.time, "2200");

      expect(schedule[4].open?.day, 5);
      expect(schedule[4].open?.time, "0800");
      expect(schedule[4].close?.day, 5);
      expect(schedule[4].close?.time, "1800");
    });

    test("fails gracefully if file is not found", () async {
      final buildings = await repo.loadBuildings("fnf.json");
      expect(buildings.length, 0);
    });

    test("fails gracefully if file is malformed", () async {
      final buildings = await repo.loadBuildings(
        "test/assets/building_testdata2.json",
      );
      expect(buildings.length, 0);
    });

    test("filters out invalid building features", () async {
      final buildings = await repo.loadBuildings(
        "test/assets/building_testdata_invalid_features.json",
      );
      final building = buildings["t2"];

      expect(buildings.length, 1);
      expect(building, isNotNull);

      expect(building!.buildingFeatures, isNotNull);
      expect(building.buildingFeatures!.length, 5);
      expect(building.buildingFeatures![0].name, "elevator");
      expect(building.buildingFeatures![1].name, "wheelChairAccess");
      expect(building.buildingFeatures![2].name, "bathroom");
      expect(building.buildingFeatures![3].name, "food");
      expect(building.buildingFeatures![4].name, "shuttleBus");

      // Verify invalid features are not present
      final featureNames = building.buildingFeatures!
          .map((final f) => f.name)
          .toList();
      expect(featureNames.contains("invalidFeature"), false);
      expect(featureNames.contains("nonExistentFeature"), false);
    });
  });
}
