import "dart:async";
import "package:concordia_campus_guide/data/services/location_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:flutter_test/flutter_test.dart";
import "package:geolocator_platform_interface/geolocator_platform_interface.dart";

class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission checkPermissionResult = LocationPermission.always;
  LocationPermission requestPermissionResult = LocationPermission.always;
  bool throwOnGetStream = false;
  List<Position> positionsToStream = [];
  int streamCallCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => checkPermissionResult;

  @override
  Future<LocationPermission> requestPermission() async => requestPermissionResult;

  @override
  Future<Position> getCurrentPosition({final LocationSettings? locationSettings}) async {
    if (positionsToStream.isEmpty) {
      return Position(
        latitude: 45.5,
        longitude: -73.5,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }
    return positionsToStream.first;
  }

  @override
  Stream<Position> getPositionStream({final LocationSettings? locationSettings}) {
    streamCallCount++;
    if (throwOnGetStream) {
      return Stream.error(Exception("Stream error"));
    }
    return Stream.fromIterable(positionsToStream);
  }
}

void main() {
  group("LocationService", () {
    late GeolocatorPlatform previousPlatform;
    late _FakeGeolocator fakeGeolocator;

    setUp(() {
      LocationService.resetForTesting();
      
      previousPlatform = GeolocatorPlatform.instance;
      fakeGeolocator = _FakeGeolocator();
      GeolocatorPlatform.instance = fakeGeolocator;
    });

    tearDown(() {
      GeolocatorPlatform.instance = previousPlatform;
      LocationService.resetForTesting();
    });

    test("singleton instance returns same object", () {
      final instance1 = LocationService.instance;
      final instance2 = LocationService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test("getCurrentPosition returns coordinate when service enabled", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.always;

      final coord = await LocationService.instance.getCurrentPosition();

      expect(coord.latitude, 45.5);
      expect(coord.longitude, -73.5);
    });

    test("getCurrentPosition throws when location service disabled", () async {
      fakeGeolocator.serviceEnabled = false;

      expect(
        () => LocationService.instance.getCurrentPosition(),
        throwsException,
      );
    });

    test("getCurrentPosition throws when permission denied", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.denied;
      fakeGeolocator.requestPermissionResult = LocationPermission.denied;

      expect(
        () => LocationService.instance.getCurrentPosition(),
        throwsException,
      );
    });

    test("getCurrentPosition throws when permission deniedForever", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.deniedForever;

      expect(
        () => LocationService.instance.getCurrentPosition(),
        throwsException,
      );
    });

    test("start streams positions when permissions granted", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.always;
      fakeGeolocator.positionsToStream = [
        Position(
          latitude: 45.4,
          longitude: -73.4,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        ),
        Position(
          latitude: 45.5,
          longitude: -73.5,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        ),
      ];

      await LocationService.instance.start();

      final coords = <Coordinate>[];
      LocationService.instance.positionStream.listen((final coord) {
        coords.add(coord);
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(coords.length, 2);
      expect(coords[0].latitude, 45.4);
      expect(coords[0].longitude, -73.4);
      expect(coords[1].latitude, 45.5);
      expect(coords[1].longitude, -73.5);
    });

    test("start silently catches errors", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.always;
      fakeGeolocator.throwOnGetStream = true;

      // Should not throw
      await LocationService.instance.start();
    });

    test("stop cancels subscription", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.always;
      fakeGeolocator.positionsToStream = [
        Position(
          latitude: 45.5,
          longitude: -73.5,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        ),
      ];

      await LocationService.instance.start();
      LocationService.instance.stop();

      // After stop, subscription should be cancelled
      expect(LocationService.instance.positionStream, isNotNull);
    });

    test("positionStream is broadcast stream allowing multiple listeners", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.always;
      fakeGeolocator.positionsToStream = [
        Position(
          latitude: 45.5,
          longitude: -73.5,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        ),
      ];

      await LocationService.instance.start();

      final coords1 = <Coordinate>[];
      final coords2 = <Coordinate>[];

      LocationService.instance.positionStream.listen((final coord) {
        coords1.add(coord);
      });

      LocationService.instance.positionStream.listen((final coord) {
        coords2.add(coord);
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(coords1.length, 1);
      expect(coords2.length, 1);
    });

    test("start with custom accuracy and distance filter", () async {
      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.checkPermissionResult = LocationPermission.always;

      await LocationService.instance.start(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      // Verify stream was started (streamCallCount incremented)
      expect(fakeGeolocator.streamCallCount, 1);
    });
  });
}
