import 'dart:io';

import 'package:concordia_campus_guide/data/repositories/building_repository.dart';
import 'package:concordia_campus_guide/ui/core/themes/app_theme.dart';
import 'package:concordia_campus_guide/ui/home/view_models/home_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();


  group('Home View Model', () {
    late HomeViewModel hvm;

    setUp(() {
      final repo = BuildingRepository(
        loader: (path) async {
          return File(path).readAsString();
        },
      );
      hvm = HomeViewModel(buildingRepo: repo);
    });

    test('initializes building data correctly', () async {
      expect(hvm.isLoading, false);
      expect(hvm.errorMessage, null);
      expect(hvm.buildings.isEmpty, true);
      expect(hvm.buildingPolygons.isEmpty, true);

      await hvm.initializeBuildingsData('test/assets/building_repository_test.json');

      expect(hvm.isLoading, false);
      expect(hvm.errorMessage, null);
      expect(hvm.buildings.length, 1);
      expect(hvm.buildingPolygons.length, 1);
    });

    test('handles building data load failure gracefully', () async {
      await hvm.initializeBuildingsData('fnf.json');

      expect(hvm.isLoading, false);
      expect(hvm.errorMessage, "Failed to load building data.");
      expect(hvm.buildings.isEmpty, true);
      expect(hvm.buildingPolygons.isEmpty, true);
    });

    test('updates building outline color and regenerates polygons', () async {
      await hvm.initializeBuildingsData('test/assets/building_repository_test.json');
      final initialPolygons = hvm.buildingPolygons;

      expect(hvm.buildingPolygons, isNotEmpty);
      for (var polygon in hvm.buildingPolygons) {
        expect(polygon.strokeColor, equals(AppTheme.concordiaDarkBlue));
      }

      // the buildingOutlineColor setter automatically regenerates the polygons
      hvm.buildingOutlineColor = AppTheme.concordiaMaroon;

      expect(hvm.buildingPolygons, isNot(equals(initialPolygons)));
      for (var polygon in hvm.buildingPolygons) {
        expect(polygon.strokeColor, equals(AppTheme.concordiaMaroon));
      }
    });

  });
}