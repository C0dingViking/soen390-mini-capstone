import 'dart:io';

import 'package:concordia_campus_guide/data/repositories/building_repository.dart';
import 'package:concordia_campus_guide/utils/campus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Building Repository', () {
    late BuildingRepository repo;

    setUp(() {
      repo = BuildingRepository(
          loader: (path) async {
            return File(path).readAsString();
          },
        );
    });

    test('loads a building with correct data', () async {
      final buildings = await repo.loadBuildings('test/assets/building_repository_test.json');
      final building = buildings['t'];

      expect(buildings.length, 1);

      // verify the data is parsed correctly
      expect(building, isNotNull);
      expect(building!.id, 't');
      expect(building.name, 'Test Building (T)');
      expect(building.street, '1234 Test St.');
      expect(building.postalCode, 'TE5 TM3');
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
    });

    test('fails gracefully if file is not found', () async {
      final buildings = await repo.loadBuildings('fnf.json');
      expect(buildings.length, 0);
    });

    test('fails gracefully if file is malformed', () async {
      final buildings = await repo.loadBuildings('test/assets/building_repository_test2.json');
      expect(buildings.length, 0);
    });

  });
}
