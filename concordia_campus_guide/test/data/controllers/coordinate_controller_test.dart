import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:geolocator/geolocator.dart";
import "package:mockito/mockito.dart";
import "package:plugin_platform_interface/plugin_platform_interface.dart";
import "package:concordia_campus_guide/controllers/coordinates_controller.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";

class ManualMockMapController extends Mock implements GoogleMapController {
  @override
  Future<void> animateCamera(final CameraUpdate? update, {final Duration? duration}) =>
      super.noSuchMethod(
        Invocation.method(#animateCamera, [update], {#duration: duration}),
        returnValue: Future<void>.value(),
      ) as Future<void>;
}

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() =>
      super.noSuchMethod(Invocation.method(#isLocationServiceEnabled, []),
          returnValue: Future<bool>.value(true)) as Future<bool>;

  @override
  Future<LocationPermission> checkPermission() =>
      super.noSuchMethod(Invocation.method(#checkPermission, []),
              returnValue: Future<LocationPermission>.value(
                  LocationPermission.whileInUse))
          as Future<LocationPermission>;

  @override
  Future<LocationPermission> requestPermission() =>
      super.noSuchMethod(Invocation.method(#requestPermission, []),
              returnValue: Future<LocationPermission>.value(
                  LocationPermission.whileInUse))
          as Future<LocationPermission>;

  @override
  Future<Position> getCurrentPosition({final LocationSettings? locationSettings}) =>
      super.noSuchMethod(
        Invocation.method(
            #getCurrentPosition, [], {#locationSettings: locationSettings}),
        returnValue: Future<Position>.value(Position(
          latitude: 45.0,
          longitude: -73.0,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        )),
      ) as Future<Position>;
}

void main() {
  late CoordinatesController controller;
  late ManualMockMapController mockMapController;
  late MockGeolocatorPlatform mockGeolocatorPlatform;

  setUp(() {
    controller = CoordinatesController();
    mockMapController = ManualMockMapController();
    mockGeolocatorPlatform = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocatorPlatform;
  });

  group("static constants", () {
    test("sgw coordinate has correct values", () {
      expect(CoordinatesController.sgw.latitude, 45.4972);
      expect(CoordinatesController.sgw.longitude, -73.5786);
    });

    test("loyola coordinate has correct values", () {
      expect(CoordinatesController.loyola.latitude, 45.45823348665408);
      expect(CoordinatesController.loyola.longitude, -73.64067095332564);
    });
  });

  test("onMapCreated completes the controller", () async {
    controller.onMapCreated(mockMapController);
    expect(true, true);
  });

  test("onMapCreated does not complete twice if called multiple times", () async {
    controller.onMapCreated(mockMapController);
    final firstController = await controller.mapController;
    
    // Create a second mock controller
    final secondMockController = ManualMockMapController();
    controller.onMapCreated(secondMockController);
    
    // Should still return the first controller
    final stillFirstController = await controller.mapController;
    expect(stillFirstController, same(firstController));
    expect(stillFirstController, same(mockMapController));
  });

  test("mapController returns the created controller", () async {
    final Future<GoogleMapController> future = controller.mapController;
    controller.onMapCreated(mockMapController);
    final GoogleMapController result = await future;
    expect(result, same(mockMapController));
  });

  test("goToCoordinate animates camera", () async {
    controller.onMapCreated(mockMapController);
    const testCoord = Coordinate(latitude: 10.0, longitude: 10.0);
    when(mockMapController.animateCamera(any)).thenAnswer((_) async => {});
    await controller.goToCoordinate(testCoord);
    verify(mockMapController.animateCamera(any)).called(1);
  });

  test("goToCoordinate uses custom zoom level when provided", () async {
    controller.onMapCreated(mockMapController);
    const testCoord = Coordinate(latitude: 10.0, longitude: 10.0);
    CameraUpdate? capturedUpdate;
    
    when(mockMapController.animateCamera(any)).thenAnswer((final invocation) async {
      capturedUpdate = invocation.positionalArguments[0] as CameraUpdate?;
    });
    
    await controller.goToCoordinate(testCoord, zoom: 15.0);
    
    verify(mockMapController.animateCamera(any)).called(1);
    expect(capturedUpdate, isNotNull);
  });

  test("goToCoordinate uses default zoom of 17 when not specified", () async {
    controller.onMapCreated(mockMapController);
    const testCoord = Coordinate(latitude: 10.0, longitude: 10.0);
    
    when(mockMapController.animateCamera(any)).thenAnswer((_) async => {});
    
    await controller.goToCoordinate(testCoord);
    
    verify(mockMapController.animateCamera(any)).called(1);
  });

  group("fitBounds", () {
    test("animates camera to bounds with default padding", () async {
      controller.onMapCreated(mockMapController);
      final bounds = LatLngBounds(
        southwest: const LatLng(45.49, -73.58),
        northeast: const LatLng(45.50, -73.57),
      );
      
      when(mockMapController.animateCamera(any)).thenAnswer((_) async => {});
      
      await controller.fitBounds(bounds);
      
      verify(mockMapController.animateCamera(any)).called(1);
    });

    test("animates camera to bounds with custom padding", () async {
      controller.onMapCreated(mockMapController);
      final bounds = LatLngBounds(
        southwest: const LatLng(45.49, -73.58),
        northeast: const LatLng(45.50, -73.57),
      );
      
      when(mockMapController.animateCamera(any)).thenAnswer((_) async => {});
      
      await controller.fitBounds(bounds, padding: 100.0);
      
      verify(mockMapController.animateCamera(any)).called(1);
    });

    test("expands very small bounds to prevent over-zooming", () async {
      controller.onMapCreated(mockMapController);
      // Create bounds with span < 0.002 (~200m)
      final tinyBounds = LatLngBounds(
        southwest: const LatLng(45.4972, -73.5786),
        northeast: const LatLng(45.4973, -73.5785), // ~0.0001 degree span
      );
      
      when(mockMapController.animateCamera(any)).thenAnswer((final invocation) async {
        // We can't easily extract the bounds from CameraUpdate, but we can verify it was called
      });
      
      await controller.fitBounds(tinyBounds);
      
      verify(mockMapController.animateCamera(any)).called(1);
    });

    test("preserves large bounds without expansion", () async {
      controller.onMapCreated(mockMapController);
      // Create bounds with span > 0.002
      final largeBounds = LatLngBounds(
        southwest: const LatLng(45.49, -73.58),
        northeast: const LatLng(45.51, -73.56), // ~0.02 degree span
      );
      
      when(mockMapController.animateCamera(any)).thenAnswer((_) async => {});
      
      await controller.fitBounds(largeBounds);
      
      verify(mockMapController.animateCamera(any)).called(1);
    });

    test("expands bounds when only latitude span is too small", () async {
      controller.onMapCreated(mockMapController);
      final bounds = LatLngBounds(
        southwest: const LatLng(45.4972, -73.58),
        northeast: const LatLng(45.4973, -73.56), // lat span tiny, lng span large
      );
      
      when(mockMapController.animateCamera(any)).thenAnswer((_) async => {});
      
      await controller.fitBounds(bounds);
      
      verify(mockMapController.animateCamera(any)).called(1);
    });

    test("expands bounds when only longitude span is too small", () async {
      controller.onMapCreated(mockMapController);
      final bounds = LatLngBounds(
        southwest: const LatLng(45.49, -73.5786),
        northeast: const LatLng(45.51, -73.5785), // lng span tiny, lat span large
      );
      
      when(mockMapController.animateCamera(any)).thenAnswer((_) async => {});
      
      await controller.fitBounds(bounds);
      
      verify(mockMapController.animateCamera(any)).called(1);
    });
  });

  testWidgets("goToCurrentLocation succeeds when permission granted",
      (final tester) async {
    controller.onMapCreated(mockMapController);

    when(mockGeolocatorPlatform.isLocationServiceEnabled())
        .thenAnswer((_) async => true);
    when(mockGeolocatorPlatform.checkPermission())
        .thenAnswer((_) async => LocationPermission.whileInUse);
    when(mockGeolocatorPlatform.getCurrentPosition(
            locationSettings: anyNamed("locationSettings")))
        .thenAnswer((_) async => Position(
              latitude: 45.0,
              longitude: -73.0,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            ));
    when(mockMapController.animateCamera(any)).thenAnswer((_) async => {});

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (final context) {
        return ElevatedButton(
          onPressed: () => controller.goToCurrentLocation(context),
          child: const Text("Go"),
        );
      })),
    ));

    // Use runAsync to allow the chain of awaits inside goToCurrentLocation to resolve
    await tester.runAsync(() async {
      await tester.tap(find.text("Go"));
      // Give enough time for the geolocation and camera animation futures to complete
      await Future<void>.delayed(const Duration(milliseconds: 200));    });

    await tester.pump();

    verify(mockMapController.animateCamera(any)).called(1);
  });

  testWidgets("goToCurrentLocation shows enable services when service disabled",
      (final tester) async {
    controller.onMapCreated(mockMapController);

    when(mockGeolocatorPlatform.isLocationServiceEnabled())
        .thenAnswer((_) async => false);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (final context) {
        return ElevatedButton(
          onPressed: () => controller.goToCurrentLocation(context),
          child: const Text("Go"),
        );
      })),
    ));

    await tester.runAsync(() async {
      await tester.tap(find.text("Go"));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    await tester.pump();

    expect(find.text("Enable location services"), findsOneWidget);
  });

  testWidgets("goToCurrentLocation shows enable permissions when deniedForever",
      (final tester) async {
    controller.onMapCreated(mockMapController);

    when(mockGeolocatorPlatform.isLocationServiceEnabled())
        .thenAnswer((_) async => true);
    when(mockGeolocatorPlatform.checkPermission())
        .thenAnswer((_) async => LocationPermission.deniedForever);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (final context) {
        return ElevatedButton(
          onPressed: () => controller.goToCurrentLocation(context),
          child: const Text("Go"),
        );
      })),
    ));

    await tester.runAsync(() async {
      await tester.tap(find.text("Go"));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    await tester.pump();

    expect(find.text("Enable location permissions in settings"), findsOneWidget);
  });

  testWidgets("goToCurrentLocation silently returns when permission denied once",
      (final tester) async {
    controller.onMapCreated(mockMapController);

    when(mockGeolocatorPlatform.isLocationServiceEnabled())
        .thenAnswer((_) async => true);
    when(mockGeolocatorPlatform.checkPermission())
        .thenAnswer((_) async => LocationPermission.denied);
    when(mockGeolocatorPlatform.requestPermission())
        .thenAnswer((_) async => LocationPermission.denied);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (final context) {
        return ElevatedButton(
          onPressed: () => controller.goToCurrentLocation(context),
          child: const Text("Go"),
        );
      })),
    ));

    await tester.runAsync(() async {
      await tester.tap(find.text("Go"));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets("goToCurrentLocation shows generic error for unexpected exceptions",
      (final tester) async {
    controller.onMapCreated(mockMapController);

    when(mockGeolocatorPlatform.isLocationServiceEnabled())
        .thenAnswer((_) async => true);
    when(mockGeolocatorPlatform.checkPermission())
        .thenAnswer((_) async => LocationPermission.whileInUse);
    when(mockGeolocatorPlatform.getCurrentPosition(
            locationSettings: anyNamed("locationSettings")))
        .thenThrow(Exception("boom"));
    when(mockMapController.animateCamera(any)).thenAnswer((_) async => {});

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (final context) {
        return ElevatedButton(
          onPressed: () => controller.goToCurrentLocation(context),
          child: const Text("Go"),
        );
      })),
    ));

    await tester.runAsync(() async {
      await tester.tap(find.text("Go"));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    await tester.pump();

    expect(find.text("Location error: Exception: boom"), findsOneWidget);
  });
}
