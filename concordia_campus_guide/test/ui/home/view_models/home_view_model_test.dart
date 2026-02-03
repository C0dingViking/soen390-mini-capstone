import 'dart:io';
import 'package:concordia_campus_guide/data/repositories/building_repository.dart';
import 'package:concordia_campus_guide/domain/interactors/map_data_interactor.dart';
import 'package:concordia_campus_guide/ui/core/themes/app_theme.dart';
import 'package:concordia_campus_guide/ui/home/view_models/home_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();


  group('Home View Model', () {
    late HomeViewModel hvm;

    setUp(() {
      Logger.level = Level.off;
      final repo = BuildingRepository(
        buildingLoader: (path) async {
          return File(path).readAsString();
        },
      );
      hvm = HomeViewModel(mapInteractor: MapDataInteractor(buildingRepo: repo));
    });

    test('initializes building data correctly', () async {
      expect(hvm.isLoading, false);
      expect(hvm.buildings.isEmpty, true);
      expect(hvm.buildingOutlines.isEmpty, true);
      expect(hvm.buildingMarkers.isEmpty, true);

      await hvm.initializeBuildingsData('test/assets/building_testdata.json');

      expect(hvm.isLoading, false);
      expect(hvm.buildings.length, 1);
      expect(hvm.buildingOutlines.length, 1);
      expect(hvm.buildingMarkers.length, 1);
    });

    test('handles file not found failure gracefully', () async {
      await hvm.initializeBuildingsData('fnf.json');

      expect(hvm.isLoading, false);
      expect(hvm.buildings.isEmpty, true);
      expect(hvm.buildingOutlines.isEmpty, true);
      expect(hvm.buildingMarkers.isEmpty, true);
    });

    test('handles malformed data load gracefully', () async {
      await hvm.initializeBuildingsData('test/assets/building_testdata2.json');

      expect(hvm.isLoading, false);
      expect(hvm.buildings.isEmpty, true);
      expect(hvm.buildingOutlines.isEmpty, true);
      expect(hvm.buildingMarkers.isEmpty, true);
    });

    test('updates building outline color and regenerates polygons', () async {
      await hvm.initializeBuildingsData('test/assets/building_testdata.json');
      final initialPolygons = hvm.buildingOutlines;

      expect(hvm.buildingOutlines, isNotEmpty);
      for (var polygon in hvm.buildingOutlines) {
        expect(polygon.strokeColor, equals(AppTheme.concordiaMaroon));
      }

      // the buildingOutlineColor setter automatically regenerates the polygons
      hvm.buildingOutlineColor = AppTheme.concordiaDarkBlue;

      expect(hvm.buildingOutlines, isNot(equals(initialPolygons)));
      for (var polygon in hvm.buildingOutlines) {
        expect(polygon.strokeColor, equals(AppTheme.concordiaDarkBlue));
      }
    });

  });
}
