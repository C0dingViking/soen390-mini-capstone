import "dart:io";
import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/data/services/location_service.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/places_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/directions_interactor.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:flutter_test/flutter_test.dart";
import "package:logger/logger.dart";
import "package:geolocator_platform_interface/geolocator_platform_interface.dart";

class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission checkPermissionResult = LocationPermission.always;
  LocationPermission requestPermissionResult = LocationPermission.always;
  bool throwOnGet = false;
  double lat = 0.0;
  double lng = 0.0;
  List<Position> positionsToStream = [];

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => checkPermissionResult;

  @override
  Future<LocationPermission> requestPermission() async => requestPermissionResult;

  @override
  Future<Position> getCurrentPosition({final LocationSettings? locationSettings}) async {
    if (throwOnGet) throw Exception("boom");
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }

  @override
  Stream<Position> getPositionStream({final LocationSettings? locationSettings}) {
    return Stream.fromIterable(positionsToStream);
  }
}

class _FakePlacesInteractor extends PlacesInteractor {
  @override
  Future<List<PlaceSuggestion>> searchPlaces(final String query) async => [];

  @override
  Future<Coordinate?> resolvePlace(final String placeId) async => null;

  @override
  Future<Coordinate?> resolvePlaceSuggestion(final PlaceSuggestion suggestion) async => null;
}

class _FakeDirectionsInteractor extends DirectionsInteractor {
  @override
  Future<List<RouteOption>> getRouteOptions(
    final Coordinate start,
    final Coordinate destination, {
    final DateTime? departureTime,
    final DateTime? arrivalTime,
  }) async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group("Home View Model", () {
    late HomeViewModel hvm;
    late GeolocatorPlatform previousPlatform;
    late _FakeGeolocator fakeGeolocator;

    setUp(() {
      Logger.level = Level.off;
      final repo = BuildingRepository(
        buildingLoader: (final path) async {
          return File(path).readAsString();
        },
      );
      hvm = HomeViewModel(
        mapInteractor: MapDataInteractor(buildingRepo: repo),
        placesInteractor: _FakePlacesInteractor(),
        directionsInteractor: _FakeDirectionsInteractor(),
      );
      previousPlatform = GeolocatorPlatform.instance;
      fakeGeolocator = _FakeGeolocator();
      GeolocatorPlatform.instance = fakeGeolocator;
    });

    tearDown(() {
      GeolocatorPlatform.instance = previousPlatform;
      hvm.dispose();
      LocationService.resetForTesting();
    });

    test("initializes building data correctly", () async {
      expect(hvm.isLoading, false);
      expect(hvm.buildings.isEmpty, true);
      expect(hvm.buildingOutlines.isEmpty, true);
      expect(hvm.buildingMarkers.isEmpty, true);
      await hvm.initializeBuildingsData("test/assets/building_testdata.json");
      expect(hvm.isLoading, false);
      expect(hvm.buildings.length, 1);
      expect(hvm.buildingOutlines.length, 1);
      expect(hvm.buildingMarkers.length, 1);
    });

    test("handles file not found failure gracefully", () async {
      await hvm.initializeBuildingsData("fnf.json");
      expect(hvm.isLoading, false);
      expect(hvm.buildings.isEmpty, true);
      expect(hvm.buildingOutlines.isEmpty, true);
      expect(hvm.buildingMarkers.isEmpty, true);
    });

    test("handles malformed data load gracefully", () async {
      await hvm.initializeBuildingsData("test/assets/building_testdata2.json");
      expect(hvm.isLoading, false);
      expect(hvm.buildings.isEmpty, true);
      expect(hvm.buildingOutlines.isEmpty, true);
      expect(hvm.buildingMarkers.isEmpty, true);
    });

    test("updates building outline color and regenerates polygons", () async {
      await hvm.initializeBuildingsData("test/assets/building_testdata.json");
      final initialPolygons = hvm.buildingOutlines;
      expect(hvm.buildingOutlines, isNotEmpty);
      for (var polygon in hvm.buildingOutlines) {
        expect(polygon.strokeColor, equals(AppTheme.concordiaMaroon));
      }
      hvm.buildingOutlineColor = AppTheme.concordiaDarkBlue;
      expect(hvm.buildingOutlines, isNot(equals(initialPolygons)));
      for (var polygon in hvm.buildingOutlines) {
        expect(polygon.strokeColor, equals(AppTheme.concordiaDarkBlue));
      }
    });

    test("toggleCampus updates selectedCampusIndex and cameraTarget", () {
      expect(hvm.selectedCampusIndex, 0);
      expect(hvm.cameraTarget, isNull);
      hvm.toggleCampus();
      expect(hvm.selectedCampusIndex, 1);
      expect(hvm.cameraTarget?.latitude, HomeViewModel.loyola.latitude);
      expect(hvm.cameraTarget?.longitude, HomeViewModel.loyola.longitude);
      hvm.toggleCampus();
      expect(hvm.selectedCampusIndex, 0);
      expect(hvm.cameraTarget?.latitude, HomeViewModel.sgw.latitude);
      expect(hvm.cameraTarget?.longitude, HomeViewModel.sgw.longitude);
    });

    test("clearCameraTarget clears cameraTarget", () {
      hvm.cameraTarget = HomeViewModel.sgw;
      expect(hvm.cameraTarget, isNotNull);
      hvm.clearCameraTarget();
      expect(hvm.cameraTarget, isNull);
    });

    test("goToCurrentLocation when service disabled sets error", () async {
      fakeGeolocator.serviceEnabled = false;
      await hvm.goToCurrentLocation();
      expect(hvm.errorMessage, equals("Error: Location services disabled"));
      expect(hvm.myLocationEnabled, isFalse);
      expect(hvm.cameraTarget, isNull);
    });

    test("goToCurrentLocation when permission denied and request denied", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.denied;
      fakeGeolocator.requestPermissionResult = LocationPermission.denied;
      await hvm.goToCurrentLocation();
      expect(hvm.errorMessage, equals("Error: Location permission denied"));
    });

    test("goToCurrentLocation when permission denied forever", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.deniedForever;
      await hvm.goToCurrentLocation();
      expect(hvm.errorMessage, equals("Error: Location permission deniedForever. Please enable it in settings."));
    });

    test("goToCurrentLocation success sets cameraTarget and enables location", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.whileInUse;
      fakeGeolocator.lat = 12.34;
      fakeGeolocator.lng = 56.78;
      await hvm.goToCurrentLocation();
      expect(hvm.errorMessage, isNull);
      expect(hvm.cameraTarget, isNotNull);
      expect(hvm.cameraTarget!.latitude, equals(12.34));
      expect(hvm.cameraTarget!.longitude, equals(56.78));
      expect(hvm.myLocationEnabled, isTrue);
    });

    test("goToCurrentLocation when getCurrentPosition throws sets error message", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.whileInUse;
      fakeGeolocator.throwOnGet = true;
      await hvm.goToCurrentLocation();
      expect(hvm.errorMessage, contains("boom"));
    });

    group("Building detection with location stream", () {
      test("initializeBuildingsData starts location tracking", () async {
        fakeGeolocator.serviceEnabled = true;
        fakeGeolocator.checkPermissionResult = LocationPermission.always;
        fakeGeolocator.positionsToStream = [
          Position(
            latitude: 45.5,
            longitude: -73.5,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          ),
        ];

        await hvm.initializeBuildingsData("test/assets/building_testdata.json");

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(hvm.myLocationEnabled, isTrue);
        expect(hvm.cameraTarget, isNotNull);
        expect(hvm.cameraTarget!.latitude, 45.5);
      });

      test("currentBuilding is null when user is outside all buildings", () async {
        fakeGeolocator.serviceEnabled = true;
        fakeGeolocator.checkPermissionResult = LocationPermission.always;
        // Position far from any building
        fakeGeolocator.positionsToStream = [
          Position(
            latitude: 0.0,
            longitude: 0.0,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          ),
        ];

        await hvm.initializeBuildingsData("test/assets/building_testdata.json");

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(hvm.currentBuilding, isNull);
      });

      test("stopLocationTracking stops position updates", () async {
        fakeGeolocator.serviceEnabled = true;
        fakeGeolocator.checkPermissionResult = LocationPermission.always;
        fakeGeolocator.positionsToStream = [
          Position(
            latitude: 45.5,
            longitude: -73.5,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          ),
        ];

        await hvm.initializeBuildingsData("test/assets/building_testdata.json");

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(hvm.myLocationEnabled, isTrue);

        hvm.stopLocationTracking();

        expect(hvm.myLocationEnabled, isFalse);
      });

      test("goToCurrentLocation starts streaming position updates", () async {
        fakeGeolocator.serviceEnabled = true;
        fakeGeolocator.checkPermissionResult = LocationPermission.always;
        fakeGeolocator.lat = 45.4973;
        fakeGeolocator.lng = -73.5786;
        fakeGeolocator.positionsToStream = [
          Position(
            latitude: 45.4973,
            longitude: -73.5786,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          ),
        ];

        await hvm.initializeBuildingsData("test/assets/building_testdata.json");
        await hvm.goToCurrentLocation();

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(hvm.cameraTarget, isNotNull);
        expect(hvm.myLocationEnabled, isTrue);
      });

      test("loaded buildings have bbox precomputed and isInsideBBox works", () async {
        fakeGeolocator.serviceEnabled = true;
        fakeGeolocator.checkPermissionResult = LocationPermission.always;

        await hvm.initializeBuildingsData("test/assets/building_testdata.json");

        // get first building and ensure bbox fields are present
        final b = hvm.buildings.values.first;
        expect(b.minLatitude, isNotNull);
        expect(b.maxLatitude, isNotNull);
        expect(b.minLongitude, isNotNull);
        expect(b.maxLongitude, isNotNull);

        // a far away coordinate should be outside the bbox
        final outside = Coordinate(latitude: 0.0, longitude: 0.0);
        expect(b.isInsideBBox(outside), isFalse);
      });

      test("cameraTarget only updates when coordinate changes (identical positions)", () async {
        fakeGeolocator.serviceEnabled = true;
        fakeGeolocator.checkPermissionResult = LocationPermission.always;
        final pos = Position(
          latitude: 45.5,
          longitude: -73.5,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        // two identical positions should cause only one cameraTarget update
        fakeGeolocator.positionsToStream = [pos, pos];

        int notifyCount = 0;
        hvm.addListener(() => notifyCount++);

        await hvm.initializeBuildingsData("test/assets/building_testdata.json");

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // initializeBuildingsData triggers two notifications (start + end),
        // plus one from the first position update -> total 3
        expect(notifyCount, equals(3));
        expect(hvm.cameraTarget, isNotNull);
        expect(hvm.cameraTarget!.latitude, equals(45.5));
      });

      test("cameraTarget updates again when coordinate changes (different positions)", () async {
        fakeGeolocator.serviceEnabled = true;
        fakeGeolocator.checkPermissionResult = LocationPermission.always;
        final pos1 = Position(
          latitude: 45.5,
          longitude: -73.5,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
        final pos2 = Position(
          latitude: 45.5009,
          longitude: -73.5009,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        // two different positions should cause two cameraTarget updates
        fakeGeolocator.positionsToStream = [pos1, pos2];

        int notifyCount = 0;
        hvm.addListener(() => notifyCount++);

        await hvm.initializeBuildingsData("test/assets/building_testdata.json");

        await Future<void>.delayed(const Duration(milliseconds: 150));

        // start + end + two position updates = 4
        expect(notifyCount, equals(4));
        expect(hvm.cameraTarget, isNotNull);
        expect(hvm.cameraTarget!.latitude, equals(45.5009));
      });
    });
  });
}
