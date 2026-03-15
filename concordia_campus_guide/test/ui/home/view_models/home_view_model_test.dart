import "dart:io";
import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:concordia_campus_guide/data/services/location_service.dart";
import "package:concordia_campus_guide/domain/interactors/calendar_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/places_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/directions_interactor.dart";
import "package:googleapis/calendar/v3.dart" as calendar;
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/domain/models/search_suggestion.dart";
import "package:concordia_campus_guide/domain/models/academic_class.dart";
import "package:concordia_campus_guide/domain/models/room.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_google_maps_webservices/places.dart" as gmw;
import "package:google_maps_flutter/google_maps_flutter.dart";
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

class _FakeGoogleCalendarRepository implements GoogleCalendarRepository {
  @override
  Future<List<calendar.Event>> getUpcomingEvents({
    final int maxResults = 10,
    final DateTime? timeMin,
    final DateTime? timeMax,
  }) async => [];

  @override
  Future<List<calendar.Event>> getEventsInRange({
    required final DateTime startDate,
    required final DateTime endDate,
  }) async => [];
}

class _FakeCalendarInteractor extends CalendarInteractor {
  _FakeCalendarInteractor() : super(calendarRepo: _FakeGoogleCalendarRepository());
}

class _TrackingPlacesInteractor extends PlacesInteractor {
  int searchCount = 0;
  int nearbySearchCount = 0;
  String? lastQuery;
  String? lastNearbyQuery;
  Coordinate? lastNearbyOrigin;
  int? lastNearbyMaxResults;
  List<PlaceSuggestion> searchResults = [];
  List<PlaceSuggestion> nearbyResults = [];
  PlaceSuggestion? lastResolvedSuggestion;
  Coordinate? resolveResult;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(final String query) async {
    searchCount++;
    lastQuery = query;
    return searchResults;
  }

  @override
  Future<List<PlaceSuggestion>> searchNearbyPlaces(
    final String query,
    final Coordinate origin, {
    final int maxResults = 5,
  }) async {
    nearbySearchCount++;
    lastNearbyQuery = query;
    lastNearbyOrigin = origin;
    lastNearbyMaxResults = maxResults;
    return nearbyResults;
  }

  @override
  Future<Coordinate?> resolvePlaceSuggestion(final PlaceSuggestion suggestion) async {
    lastResolvedSuggestion = suggestion;
    return resolveResult;
  }
}

class _ConfigurableDirectionsInteractor extends DirectionsInteractor {
  List<RouteOption> options = [];
  Coordinate? lastStart;
  Coordinate? lastDestination;
  DateTime? lastDepartureTime;
  DateTime? lastArrivalTime;
  int callCount = 0;

  @override
  Future<List<RouteOption>> getRouteOptions(
    final Coordinate start,
    final Coordinate destination, {
    final DateTime? departureTime,
    final DateTime? arrivalTime,
  }) async {
    callCount++;
    lastStart = start;
    lastDestination = destination;
    lastDepartureTime = departureTime;
    lastArrivalTime = arrivalTime;
    return options;
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
        calendarInteractor: _FakeCalendarInteractor(),
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
      expect(
        hvm.errorMessage,
        equals("Error: Location permission deniedForever. Please enable it in settings."),
      );
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

  group("HomeViewModel search and routing", () {
    late HomeViewModel hvm;
    late _TrackingPlacesInteractor places;
    late _ConfigurableDirectionsInteractor directions;
    late GeolocatorPlatform previousPlatform;
    late _FakeGeolocator fakeGeolocator;

    setUp(() {
      places = _TrackingPlacesInteractor();
      directions = _ConfigurableDirectionsInteractor();
      hvm = HomeViewModel(
        mapInteractor: MapDataInteractor(
          buildingRepo: BuildingRepository(buildingLoader: (_) async => "{}"),
        ),
        placesInteractor: places,
        directionsInteractor: directions,
        calendarInteractor: _FakeCalendarInteractor(),
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

    test("updateSearchQuery returns building suggestions without places", () {
      hvm.buildings = {
        "H": Building(
          id: "H",
          googlePlacesId: null,
          name: "Hall Building",
          description: "Desc",
          street: "Street",
          postalCode: "H3Z 2Y7",
          location: const Coordinate(latitude: 45.0, longitude: -73.0),
          hours: gmw.OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [],
          images: [],
          buildingFeatures: null,
        ),
        "LB": Building(
          id: "LB",
          googlePlacesId: null,
          name: "Library",
          description: "Desc",
          street: "Street",
          postalCode: "H3Z 2Y7",
          location: const Coordinate(latitude: 45.1, longitude: -73.1),
          hours: gmw.OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [],
          images: [],
          buildingFeatures: null,
        ),
      };

      hvm.updateSearchQuery("ha");

      expect(hvm.searchResults.length, 1);
      expect(hvm.searchResults.first.type, SearchSuggestionType.building);
      expect(places.searchCount, 0);
      expect(hvm.isSearchingPlaces, isFalse);
    });

    test("updateSearchQuery merges building and place results", () async {
      hvm.buildings = {
        "H": Building(
          id: "H",
          googlePlacesId: null,
          name: "Hall Building",
          description: "Desc",
          street: "Street",
          postalCode: "H3Z 2Y7",
          location: const Coordinate(latitude: 45.0, longitude: -73.0),
          hours: gmw.OpeningHoursDetail(),
          campus: Campus.sgw,
          outlinePoints: [],
          images: [],
          buildingFeatures: null,
        ),
      };
      places.searchResults = [
        const PlaceSuggestion(
          placeId: "place-1",
          description: "Hall Place",
          mainText: "Hall Place",
          secondaryText: "Montreal",
        ),
      ];

      hvm.setActiveSearchField(SearchField.start);
      hvm.updateSearchQuery("hal");
      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(places.searchCount, 1);
      expect(places.nearbySearchCount, 0);
      expect(hvm.searchResults.length, 2);
      expect(hvm.searchResults.where((final s) => s.type == SearchSuggestionType.place).length, 1);
    });

    test("destination search shows nearby place results and markers", () async {
      places.nearbyResults = [
        const PlaceSuggestion(
          placeId: "nearby-1",
          description: "Coffee Shop, Montreal",
          mainText: "Coffee Shop",
          secondaryText: "Montreal",
          coordinate: Coordinate(latitude: 45.001, longitude: -73.001),
          distanceMeters: 140,
        ),
      ];
      fakeGeolocator.lat = 45.0;
      fakeGeolocator.lng = -73.0;
      hvm.setActiveSearchField(SearchField.destination);

      hvm.updateSearchQuery("coffee");
      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(places.nearbySearchCount, 1);
      expect(places.lastNearbyQuery, "coffee");
      expect(places.lastNearbyMaxResults, 5);
      expect(hvm.nearbySearchResults.length, 1);
      expect(
        hvm.mapMarkers.any((final marker) => marker.markerId.value == "nearby-nearby-1"),
        isTrue,
      );
    });

    test("clearSearchResults resets search state", () {
      hvm.searchResults = [
        SearchSuggestion.place(
          PlaceSuggestion(
            placeId: "place-1",
            description: "Desc",
            mainText: "Main",
            secondaryText: "Secondary",
          ),
        ),
      ];
      hvm.isSearchingPlaces = true;

      hvm.clearSearchResults();

      expect(hvm.searchResults, isEmpty);
      expect(hvm.isSearchingPlaces, isFalse);
    });

    test("clearRouteSelection resets route state", () {
      hvm.startCoordinate = const Coordinate(latitude: 45.0, longitude: -73.0);
      hvm.destinationCoordinate = const Coordinate(latitude: 45.1, longitude: -73.1);
      hvm.selectedStartLabel = "Start";
      hvm.selectedDestinationLabel = "Dest";
      hvm.searchStartMarker = Marker(
        markerId: const MarkerId("search-start"),
        position: const LatLng(45.0, -73.0),
      );
      hvm.searchDestinationMarker = Marker(
        markerId: const MarkerId("search-destination"),
        position: const LatLng(45.1, -73.1),
      );
      hvm.routeOptions = {
        RouteMode.walking: RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 1000,
          durationSeconds: 600,
          polyline: const [],
        ),
      };
      hvm.routeBounds = LatLngBounds(
        southwest: const LatLng(45.0, -73.0),
        northeast: const LatLng(45.1, -73.1),
      );
      hvm.isLoadingRoutes = true;
      hvm.routeErrorMessage = "Err";

      hvm.clearRouteSelection();

      expect(hvm.startCoordinate, isNull);
      expect(hvm.destinationCoordinate, isNull);
      expect(hvm.selectedStartLabel, isNull);
      expect(hvm.selectedDestinationLabel, isNull);
      expect(hvm.searchStartMarker, isNull);
      expect(hvm.searchDestinationMarker, isNull);
      expect(hvm.routeOptions, isEmpty);
      expect(hvm.routePolylines, isEmpty);
      expect(hvm.transitChangeCircles, isEmpty);
      expect(hvm.routeBounds, isNull);
      expect(hvm.routeErrorMessage, isNull);
      expect(hvm.isLoadingRoutes, isFalse);
    });

    test("setSearchBarExpanded and requestUnfocusSearchBar update state", () {
      expect(hvm.isSearchBarExpanded, isFalse);
      hvm.setSearchBarExpanded(true);
      expect(hvm.isSearchBarExpanded, isTrue);

      final signal = hvm.unfocusSearchBarSignal;
      hvm.requestUnfocusSearchBar();
      expect(hvm.unfocusSearchBarSignal, signal + 1);
    });

    test("mapMarkers returns building and search markers", () {
      hvm.buildingMarkers = {
        const Marker(markerId: MarkerId("b-1"), position: LatLng(45.0, -73.0)),
      };
      hvm.searchStartMarker = const Marker(
        markerId: MarkerId("search-start"),
        position: LatLng(45.1, -73.1),
      );
      hvm.searchDestinationMarker = const Marker(
        markerId: MarkerId("search-destination"),
        position: LatLng(45.2, -73.2),
      );

      expect(hvm.mapMarkers.length, 3);
    });

    test("selectSearchSuggestion applies building selection", () async {
      final building = Building(
        id: "H",
        googlePlacesId: null,
        name: "Hall Building",
        description: "Desc",
        street: "Street",
        postalCode: "H3Z 2Y7",
        location: const Coordinate(latitude: 45.0, longitude: -73.0),
        hours: gmw.OpeningHoursDetail(),
        campus: Campus.loyola,
        outlinePoints: [],
        images: [],
        buildingFeatures: null,
      );
      final suggestion = SearchSuggestion.building(building);

      await hvm.selectSearchSuggestion(suggestion, SearchField.start);

      expect(hvm.startCoordinate, isNotNull);
      expect(hvm.selectedStartLabel, equals("Hall Building"));
      expect(hvm.searchStartMarker?.markerId.value, equals("search-start"));
      expect(hvm.selectedCampusIndex, 1);
    });

    test("selectSearchSuggestion resolves place and loads routes", () async {
      hvm.startCoordinate = const Coordinate(latitude: 45.0, longitude: -73.0);
      final place = const PlaceSuggestion(
        placeId: "place-1",
        description: "Hall Place",
        mainText: "Hall Place",
        secondaryText: "Montreal",
      );
      final suggestion = SearchSuggestion.place(place);
      places.resolveResult = const Coordinate(latitude: 45.1, longitude: -73.1);
      directions.options = [
        RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 900,
          durationSeconds: 540,
          polyline: const [
            Coordinate(latitude: 45.0, longitude: -73.0),
            Coordinate(latitude: 45.1, longitude: -73.1),
          ],
        ),
      ];

      await hvm.selectSearchSuggestion(suggestion, SearchField.destination);

      expect(places.lastResolvedSuggestion, equals(place));
      expect(hvm.destinationCoordinate, isNotNull);
      expect(hvm.selectedDestinationLabel, equals("Hall Place"));
      expect(hvm.routeOptions.containsKey(RouteMode.walking), isTrue);
      expect(hvm.routePolylines.length, 1);
      expect(hvm.routeBounds, isNotNull);
    });

    test("tapping nearby marker starts directions", () async {
      fakeGeolocator.lat = 45.0;
      fakeGeolocator.lng = -73.0;
      places.resolveResult = const Coordinate(latitude: 45.1, longitude: -73.1);
      directions.options = [
        RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 900,
          durationSeconds: 540,
          polyline: const [
            Coordinate(latitude: 45.0, longitude: -73.0),
            Coordinate(latitude: 45.1, longitude: -73.1),
          ],
        ),
      ];
      hvm.nearbySearchResults = const [
        PlaceSuggestion(
          placeId: "nearby-1",
          description: "Restaurant, Montreal",
          mainText: "Restaurant",
          secondaryText: "Montreal",
          coordinate: Coordinate(latitude: 45.1, longitude: -73.1),
          distanceMeters: 90,
          source: PlaceSuggestionSource.nearby,
        ),
      ];

      final marker = hvm.mapMarkers.firstWhere(
        (final value) => value.markerId.value == "nearby-nearby-1",
      );

      expect(marker.onTap, isNotNull);
      marker.onTap!.call();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(places.lastResolvedSuggestion?.placeId, equals("nearby-1"));
      expect(hvm.startCoordinate, isNotNull);
      expect(hvm.startCoordinate!.latitude, 45.0);
      expect(hvm.startCoordinate!.longitude, -73.0);
      expect(hvm.selectedStartLabel, equals("Current location"));
      expect(hvm.destinationCoordinate, isNotNull);
      expect(hvm.destinationCoordinate!.latitude, 45.1);
      expect(hvm.destinationCoordinate!.longitude, -73.1);
      expect(hvm.selectedDestinationLabel, equals("Restaurant"));
      expect(hvm.routeOptions.containsKey(RouteMode.walking), isTrue);
      expect(
        directions.lastDestination,
        equals(const Coordinate(latitude: 45.1, longitude: -73.1)),
      );
    });

    test("selectSearchSuggestion for nearby place loads routes", () async {
      fakeGeolocator.lat = 45.0;
      fakeGeolocator.lng = -73.0;
      final place = const PlaceSuggestion(
        placeId: "nearby-1",
        description: "Restaurant, Montreal",
        mainText: "Restaurant",
        secondaryText: "Montreal",
        coordinate: Coordinate(latitude: 45.1, longitude: -73.1),
        distanceMeters: 90,
        source: PlaceSuggestionSource.nearby,
      );
      final suggestion = SearchSuggestion.place(place);
      hvm.searchResults = [suggestion];
      places.resolveResult = const Coordinate(latitude: 45.1, longitude: -73.1);
      directions.options = [
        RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 900,
          durationSeconds: 540,
          polyline: const [
            Coordinate(latitude: 45.0, longitude: -73.0),
            Coordinate(latitude: 45.1, longitude: -73.1),
          ],
        ),
      ];

      await hvm.selectSearchSuggestion(suggestion, SearchField.destination);

      expect(places.lastResolvedSuggestion, equals(place));
      expect(hvm.startCoordinate, isNotNull);
      expect(hvm.startCoordinate!.latitude, 45.0);
      expect(hvm.startCoordinate!.longitude, -73.0);
      expect(hvm.selectedStartLabel, equals("Current location"));
      expect(hvm.destinationCoordinate, isNotNull);
      expect(hvm.destinationCoordinate!.latitude, 45.1);
      expect(hvm.destinationCoordinate!.longitude, -73.1);
      expect(hvm.selectedDestinationLabel, equals("Restaurant"));
      expect(hvm.cameraTarget, equals(const Coordinate(latitude: 45.1, longitude: -73.1)));
      expect(hvm.routeOptions.containsKey(RouteMode.walking), isTrue);
      expect(hvm.routePolylines.length, 1);
      expect(hvm.searchResults, isEmpty);
      expect(hvm.nearbySearchResults, isEmpty);
      expect(hvm.cameraTarget, isNotNull);
      expect(hvm.cameraTarget!.latitude, 45.1);
      expect(hvm.cameraTarget!.longitude, -73.1);
      expect(
        directions.lastDestination,
        equals(const Coordinate(latitude: 45.1, longitude: -73.1)),
      );
    });

    test("setDepartureTime and setArrivalTime update time state", () {
      hvm.routeOptions = {
        RouteMode.walking: RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 1000,
          durationSeconds: 600,
          polyline: const [
            Coordinate(latitude: 45.0, longitude: -73.0),
            Coordinate(latitude: 45.1, longitude: -73.1),
          ],
        ),
      };
      hvm.selectedRouteMode = RouteMode.walking;

      final departAt = DateTime(2025, 1, 1, 9, 0);
      hvm.setDepartureTime(departAt);
      expect(hvm.departureMode, DepartureMode.departAt);
      expect(hvm.selectedDepartureTime, departAt);
      expect(hvm.selectedArrivalTime, isNull);

      final arriveBy = DateTime(2025, 1, 1, 10, 0);
      hvm.setArrivalTime(arriveBy);
      expect(hvm.departureMode, DepartureMode.arriveBy);
      expect(hvm.selectedArrivalTime, arriveBy);
      expect(hvm.selectedDepartureTime, isNull);
      expect(hvm.suggestedDepartureTime, DateTime(2025, 1, 1, 9, 50));
    });

    test("setDepartureMode now clears time state", () {
      hvm.departureMode = DepartureMode.departAt;
      hvm.selectedDepartureTime = DateTime(2025, 1, 1, 9, 0);
      hvm.selectedArrivalTime = DateTime(2025, 1, 1, 10, 0);
      hvm.suggestedDepartureTime = DateTime(2025, 1, 1, 9, 30);

      hvm.setDepartureMode(DepartureMode.now);

      expect(hvm.departureMode, DepartureMode.now);
      expect(hvm.selectedDepartureTime, isNull);
      expect(hvm.selectedArrivalTime, isNull);
      expect(hvm.suggestedDepartureTime, isNull);
    });

    test("loadRoutes sets error when options empty", () async {
      hvm.startCoordinate = const Coordinate(latitude: 45.0, longitude: -73.0);
      hvm.destinationCoordinate = const Coordinate(latitude: 45.1, longitude: -73.1);
      directions.options = [];

      hvm.setDepartureMode(DepartureMode.departAt);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(hvm.routeErrorMessage, equals("No routes available."));
      expect(hvm.isLoadingRoutes, isFalse);
      expect(hvm.routeOptions, isEmpty);
      expect(hvm.routePolylines, isEmpty);
      expect(hvm.transitChangeCircles, isEmpty);
      expect(hvm.routeBounds, isNull);
    });

    test("selectRouteMode updates polylines for transit", () {
      final transitOption = RouteOption(
        mode: RouteMode.transit,
        distanceMeters: 1200,
        durationSeconds: 900,
        polyline: const [
          Coordinate(latitude: 45.0, longitude: -73.0),
          Coordinate(latitude: 45.1, longitude: -73.1),
        ],
        steps: [
          RouteStep(
            instruction: "Walk",
            distanceMeters: 100,
            durationSeconds: 120,
            travelMode: "WALKING",
            polyline: const [
              Coordinate(latitude: 45.0, longitude: -73.0),
              Coordinate(latitude: 45.02, longitude: -73.02),
            ],
          ),
          RouteStep(
            instruction: "Bus",
            distanceMeters: 1000,
            durationSeconds: 600,
            travelMode: "TRANSIT",
            transitDetails: const TransitDetails(
              lineName: "Line 105",
              shortName: "105",
              mode: TransitMode.bus,
              departureStop: "Stop A",
              arrivalStop: "Stop B",
              numStops: 3,
            ),
            polyline: const [
              Coordinate(latitude: 45.02, longitude: -73.02),
              Coordinate(latitude: 45.1, longitude: -73.1),
            ],
          ),
        ],
      );
      hvm.routeOptions = {
        RouteMode.walking: RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 400,
          durationSeconds: 300,
          polyline: const [
            Coordinate(latitude: 45.0, longitude: -73.0),
            Coordinate(latitude: 45.01, longitude: -73.01),
          ],
        ),
        RouteMode.transit: transitOption,
      };
      hvm.selectedRouteMode = RouteMode.walking;

      hvm.selectRouteMode(RouteMode.transit);

      expect(hvm.routePolylines.length, 2);
      expect(hvm.transitChangeCircles.length, 1);
      expect(hvm.routeBounds, isNotNull);
    });

    test("transit change circle radius grows when zooming out", () {
      final transitOption = RouteOption(
        mode: RouteMode.transit,
        distanceMeters: 1200,
        durationSeconds: 900,
        polyline: const [
          Coordinate(latitude: 45.0, longitude: -73.0),
          Coordinate(latitude: 45.1, longitude: -73.1),
        ],
        steps: [
          RouteStep(
            instruction: "Walk",
            distanceMeters: 100,
            durationSeconds: 120,
            travelMode: "WALKING",
            polyline: const [
              Coordinate(latitude: 45.0, longitude: -73.0),
              Coordinate(latitude: 45.02, longitude: -73.02),
            ],
          ),
          RouteStep(
            instruction: "Bus",
            distanceMeters: 1000,
            durationSeconds: 600,
            travelMode: "TRANSIT",
            transitDetails: const TransitDetails(
              lineName: "Line 105",
              shortName: "105",
              mode: TransitMode.bus,
              departureStop: "Stop A",
              arrivalStop: "Stop B",
              numStops: 3,
            ),
            polyline: const [
              Coordinate(latitude: 45.02, longitude: -73.02),
              Coordinate(latitude: 45.1, longitude: -73.1),
            ],
          ),
        ],
      );

      hvm.routeOptions = {
        RouteMode.walking: const RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 400,
          durationSeconds: 300,
          polyline: [
            Coordinate(latitude: 45.0, longitude: -73.0),
            Coordinate(latitude: 45.01, longitude: -73.01),
          ],
        ),
        RouteMode.transit: transitOption,
      };
      hvm.selectedRouteMode = RouteMode.walking;
      hvm.selectRouteMode(RouteMode.transit);

      final zoomedInRadius = hvm.transitChangeCircles.first.radius;

      hvm.onMapCameraMove(const CameraPosition(target: LatLng(45.0, -73.0), zoom: 10));
      final zoomedOutRadius = hvm.transitChangeCircles.first.radius;

      expect(zoomedOutRadius, greaterThan(zoomedInRadius));
      expect(zoomedOutRadius, greaterThanOrEqualTo(150));
    });

    test("onMapCameraMove keeps circles empty for non-transit mode", () {
      hvm.routeOptions = {
        RouteMode.walking: const RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 400,
          durationSeconds: 300,
          polyline: [
            Coordinate(latitude: 45.0, longitude: -73.0),
            Coordinate(latitude: 45.01, longitude: -73.01),
          ],
        ),
      };
      hvm.selectedRouteMode = RouteMode.walking;

      hvm.onMapCameraMove(const CameraPosition(target: LatLng(45.0, -73.0), zoom: 9));

      expect(hvm.transitChangeCircles, isEmpty);
    });

    test("refreshRoutes re-fetches routes with same origin/destination", () async {
      final interactor = _ConfigurableDirectionsInteractor();
      final start = Coordinate(latitude: 45.0, longitude: -73.0);
      final dest = Coordinate(latitude: 45.1, longitude: -73.1);
      final walkingOption = RouteOption(
        mode: RouteMode.walking,
        distanceMeters: 1000,
        durationSeconds: 600,
        polyline: const [],
      );
      interactor.options = [walkingOption];

      final hvmWithInteractor = HomeViewModel(
        mapInteractor: MapDataInteractor(
          buildingRepo: BuildingRepository(buildingLoader: (final path) async => "{}"),
        ),
        placesInteractor: _FakePlacesInteractor(),
        directionsInteractor: interactor,
        calendarInteractor: _FakeCalendarInteractor(),
      );

      // Set initial coordinates and load routes
      hvmWithInteractor.startCoordinate = start;
      hvmWithInteractor.destinationCoordinate = dest;

      // Initial routes load
      await hvmWithInteractor.refreshRoutes();
      expect(interactor.callCount, 1);
      expect(hvmWithInteractor.routeOptions.isNotEmpty, true);

      // Refresh routes again
      await hvmWithInteractor.refreshRoutes();
      expect(interactor.callCount, 2);
      expect(interactor.lastStart, equals(start));
      expect(interactor.lastDestination, equals(dest));
      expect(hvmWithInteractor.routeOptions.isNotEmpty, true);

      hvmWithInteractor.dispose();
    });

    test("refreshRoutes sets loading state during fetch", () async {
      final interactor = _ConfigurableDirectionsInteractor();
      final start = Coordinate(latitude: 45.0, longitude: -73.0);
      final dest = Coordinate(latitude: 45.1, longitude: -73.1);
      interactor.options = [
        RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 1000,
          durationSeconds: 600,
          polyline: const [],
        ),
      ];

      final hvmWithInteractor = HomeViewModel(
        mapInteractor: MapDataInteractor(
          buildingRepo: BuildingRepository(buildingLoader: (final path) async => "{}"),
        ),
        placesInteractor: _FakePlacesInteractor(),
        directionsInteractor: interactor,
        calendarInteractor: _FakeCalendarInteractor(),
      );

      hvmWithInteractor.startCoordinate = start;
      hvmWithInteractor.destinationCoordinate = dest;

      await hvmWithInteractor.refreshRoutes();
      expect(hvmWithInteractor.isLoadingRoutes, false);

      final refreshFuture = hvmWithInteractor.refreshRoutes();
      // Check that loading started
      expect(hvmWithInteractor.isLoadingRoutes, true);

      await refreshFuture;
      // Check that loading finished
      expect(hvmWithInteractor.isLoadingRoutes, false);

      hvmWithInteractor.dispose();
    });

    test("setStartToCurrentLocation success sets start coordinate and enables location", () async {
      final geolocator = _FakeGeolocator();
      geolocator.serviceEnabled = true;
      geolocator.checkPermissionResult = LocationPermission.always;
      geolocator.lat = 45.4972;
      geolocator.lng = -73.5786;
      final previousPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = geolocator;

      try {
        directions.options = [
          RouteOption(
            mode: RouteMode.walking,
            distanceMeters: 500,
            durationSeconds: 300,
            polyline: const [
              Coordinate(latitude: 45.4972, longitude: -73.5786),
              Coordinate(latitude: 45.5, longitude: -73.57),
            ],
          ),
        ];
        hvm.destinationCoordinate = const Coordinate(latitude: 45.5, longitude: -73.57);
        hvm.selectedDestinationLabel = "Destination";

        await hvm.setStartToCurrentLocation();

        expect(hvm.startCoordinate, isNotNull);
        expect(hvm.startCoordinate!.latitude, equals(45.4972));
        expect(hvm.startCoordinate!.longitude, equals(-73.5786));
        expect(hvm.selectedStartLabel, equals("Current location"));
        expect(hvm.isResolvingStartLocation, isFalse);
        expect(hvm.errorMessage, isNull);
        expect(hvm.myLocationEnabled, isTrue);
        expect(hvm.routeOptions.isNotEmpty, isTrue);
      } finally {
        GeolocatorPlatform.instance = previousPlatform;
        LocationService.resetForTesting();
      }
    });

    test("setStartToCurrentLocation error sets error message", () async {
      final geolocator = _FakeGeolocator();
      geolocator.serviceEnabled = true;
      geolocator.checkPermissionResult = LocationPermission.always;
      geolocator.throwOnGet = true;
      final previousPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = geolocator;

      try {
        await hvm.setStartToCurrentLocation();

        expect(hvm.isResolvingStartLocation, isFalse);
        expect(hvm.errorMessage, contains("boom"));
        expect(hvm.startCoordinate, isNull);
      } finally {
        GeolocatorPlatform.instance = previousPlatform;
        LocationService.resetForTesting();
      }
    });

    test("selectSearchSuggestion with unresolvable place shows error", () async {
      final place = const PlaceSuggestion(
        placeId: "place-1",
        description: "Hall Place",
        mainText: "Hall Place",
        secondaryText: "Montreal",
      );
      final suggestion = SearchSuggestion.place(place);
      places.resolveResult = null;

      await hvm.selectSearchSuggestion(suggestion, SearchField.destination);

      expect(hvm.errorMessage, equals("Unable to resolve that address."));
      expect(hvm.destinationCoordinate, isNull);
      expect(hvm.isResolvingPlace, isFalse);
    });

    test("exitNavigation clears routes and search bar", () {
      hvm.startCoordinate = const Coordinate(latitude: 45.0, longitude: -73.0);
      hvm.destinationCoordinate = const Coordinate(latitude: 45.1, longitude: -73.1);
      hvm.selectedStartLabel = "Start";
      hvm.isSearchBarExpanded = true;
      final signal = hvm.unfocusSearchBarSignal;

      hvm.exitNavigation();

      expect(hvm.startCoordinate, isNull);
      expect(hvm.destinationCoordinate, isNull);
      expect(hvm.selectedStartLabel, isNull);
      expect(hvm.isSearchBarExpanded, isFalse);
      expect(hvm.unfocusSearchBarSignal, signal + 1);
    });

    test("selectRouteMode for shuttle updates polylines with shuttle styling", () {
      final shuttleOption = RouteOption(
        mode: RouteMode.shuttle,
        distanceMeters: 2000,
        durationSeconds: 1800,
        polyline: const [
          Coordinate(latitude: 45.0, longitude: -73.0),
          Coordinate(latitude: 45.1, longitude: -73.1),
        ],
        steps: [
          RouteStep(
            instruction: "Walk to shuttle stop",
            distanceMeters: 100,
            durationSeconds: 120,
            travelMode: "WALKING",
            polyline: const [
              Coordinate(latitude: 45.0, longitude: -73.0),
              Coordinate(latitude: 45.01, longitude: -73.01),
            ],
          ),
          RouteStep(
            instruction: "Take shuttle",
            distanceMeters: 1500,
            durationSeconds: 1800,
            travelMode: "SHUTTLE",
            transitDetails: const TransitDetails(
              lineName: "Campus Shuttle",
              shortName: "SH",
              mode: TransitMode.bus,
              departureStop: "SGW",
              arrivalStop: "LOY",
            ),
            polyline: const [
              Coordinate(latitude: 45.01, longitude: -73.01),
              Coordinate(latitude: 45.1, longitude: -73.1),
            ],
          ),
        ],
      );
      hvm.routeOptions = {
        RouteMode.walking: RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 3000,
          durationSeconds: 1800,
          polyline: const [
            Coordinate(latitude: 45.0, longitude: -73.0),
            Coordinate(latitude: 45.1, longitude: -73.1),
          ],
          steps: [],
        ),
        RouteMode.shuttle: shuttleOption,
      };
      hvm.selectedRouteMode = RouteMode.walking;

      hvm.selectRouteMode(RouteMode.shuttle);

      expect(hvm.selectedRouteMode, equals(RouteMode.shuttle));
      expect(hvm.routePolylines.length, 2);
      expect(hvm.routeBounds, isNotNull);
    });

    test("refreshRoutes passes time parameters to directions interactor", () async {
      final interactor = _ConfigurableDirectionsInteractor();
      interactor.options = [
        RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 1000,
          durationSeconds: 600,
          polyline: const [],
        ),
      ];

      final hvmWithInteractor = HomeViewModel(
        mapInteractor: MapDataInteractor(
          buildingRepo: BuildingRepository(buildingLoader: (final path) async => "{}"),
        ),
        placesInteractor: _FakePlacesInteractor(),
        directionsInteractor: interactor,
        calendarInteractor: _FakeCalendarInteractor(),
      );

      final start = Coordinate(latitude: 45.0, longitude: -73.0);
      final dest = Coordinate(latitude: 45.1, longitude: -73.1);
      final departTime = DateTime(2025, 1, 15, 9, 0);

      hvmWithInteractor.startCoordinate = start;
      hvmWithInteractor.destinationCoordinate = dest;
      hvmWithInteractor.departureMode = DepartureMode.departAt;
      hvmWithInteractor.selectedDepartureTime = departTime;

      await hvmWithInteractor.refreshRoutes();

      expect(interactor.lastStart, equals(start));
      expect(interactor.lastDestination, equals(dest));
      expect(interactor.lastDepartureTime, equals(departTime));
      expect(interactor.lastArrivalTime, isNull);

      hvmWithInteractor.dispose();
    });

    test("setSearchBarExpanded does not notify if already set to same value", () {
      hvm.isSearchBarExpanded = false;
      int notifyCount = 0;
      hvm.addListener(() => notifyCount++);

      hvm.setSearchBarExpanded(false);
      expect(notifyCount, 0);

      hvm.setSearchBarExpanded(true);
      expect(notifyCount, 1);
    });

    test("selectRouteMode does not update if already selected", () {
      hvm.routeOptions = {
        RouteMode.walking: RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 1000,
          durationSeconds: 600,
          polyline: const [],
          steps: [],
        ),
      };
      hvm.selectedRouteMode = RouteMode.walking;
      int notifyCount = 0;
      hvm.addListener(() => notifyCount++);

      hvm.selectRouteMode(RouteMode.walking);
      expect(notifyCount, 0);
    });

    test("stopLocationTracking disables location and disposes service", () async {
      final geolocator = _FakeGeolocator();
      geolocator.serviceEnabled = true;
      geolocator.checkPermissionResult = LocationPermission.always;
      geolocator.lat = 45.5;
      geolocator.lng = -73.5;
      final previousPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = geolocator;

      try {
        hvm.myLocationEnabled = true;
        expect(hvm.myLocationEnabled, isTrue);

        hvm.stopLocationTracking();

        expect(hvm.myLocationEnabled, isFalse);
      } finally {
        GeolocatorPlatform.instance = previousPlatform;
        LocationService.resetForTesting();
      }
    });

    test("setDepartureMode now clears all time-related state", () {
      hvm.departureMode = DepartureMode.departAt;
      hvm.selectedDepartureTime = DateTime(2025, 1, 1, 9, 0);
      hvm.selectedArrivalTime = DateTime(2025, 1, 1, 10, 0);
      hvm.suggestedDepartureTime = DateTime(2025, 1, 1, 9, 30);

      hvm.setDepartureMode(DepartureMode.now);

      expect(hvm.departureMode, equals(DepartureMode.now));
      expect(hvm.selectedDepartureTime, isNull);
      expect(hvm.selectedArrivalTime, isNull);
      expect(hvm.suggestedDepartureTime, isNull);
    });

    test("selectRouteMode updates suggested departure when arrival time set", () {
      final arrivalTime = DateTime(2025, 1, 1, 10, 0);
      const walkDurationSeconds = 1800; // 30 minutes
      const bikeDurationSeconds = 1200; // 20 minutes

      hvm.selectedArrivalTime = arrivalTime;
      hvm.routeOptions = {
        RouteMode.walking: RouteOption(
          mode: RouteMode.walking,
          distanceMeters: 1000,
          durationSeconds: walkDurationSeconds,
          polyline: const [],
        ),
        RouteMode.bicycling: RouteOption(
          mode: RouteMode.bicycling,
          distanceMeters: 1000,
          durationSeconds: bikeDurationSeconds,
          polyline: const [],
        ),
      };
      hvm.selectedRouteMode = RouteMode.bicycling;

      // Switch to walking - this should trigger _calculateSuggestedDeparture
      hvm.selectRouteMode(RouteMode.walking);

      expect(hvm.selectedRouteMode, equals(RouteMode.walking));
      expect(hvm.suggestedDepartureTime, equals(DateTime(2025, 1, 1, 9, 30)));
    });

    test("clearCameraTarget sets cameraTarget to null", () {
      hvm.cameraTarget = const Coordinate(latitude: 45.0, longitude: -73.0);
      expect(hvm.cameraTarget, isNotNull);

      hvm.clearCameraTarget();

      expect(hvm.cameraTarget, isNull);
    });
  });

  group("HomeViewModel next class", () {
    late HomeViewModel hvm;
    late _TrackingPlacesInteractor trackingPlacesInteractor;
    late GeolocatorPlatform previousPlatform;
    late _FakeGeolocator fakeGeolocator;

    setUp(() {
      trackingPlacesInteractor = _TrackingPlacesInteractor();
      hvm = HomeViewModel(
        mapInteractor: MapDataInteractor(
          buildingRepo: BuildingRepository(buildingLoader: (final path) async => "{}"),
        ),
        placesInteractor: trackingPlacesInteractor,
        directionsInteractor: _FakeDirectionsInteractor(),
        calendarInteractor: _FakeCalendarInteractor(),
      );
      previousPlatform = GeolocatorPlatform.instance;
      fakeGeolocator = _FakeGeolocator()
        ..lat = 45.4972
        ..lng = -73.5786;
      GeolocatorPlatform.instance = fakeGeolocator;
    });

    tearDown(() {
      GeolocatorPlatform.instance = previousPlatform;
      hvm.dispose();
      LocationService.resetForTesting();
    });

    test("toggleNextClassFabVisibility toggles only when value changes", () {
      expect(hvm.showNextClassFab, isFalse);

      hvm.toggleNextClassFabVisibility(true);
      expect(hvm.showNextClassFab, isTrue);

      hvm.toggleNextClassFabVisibility(true);
      expect(hvm.showNextClassFab, isTrue);

      hvm.toggleNextClassFabVisibility(false);
      expect(hvm.showNextClassFab, isFalse);
    });

    test("clearNextClassDialog clears dialog flag", () {
      hvm.clearNextClassDialog();

      expect(hvm.showNextClassDialog, isFalse);
    });

    test("setDestinationToUpcomingClassBuilding sets destination and camera target", () async {
      final building = Building(
        id: "MB",
        googlePlacesId: null,
        name: "J.W. McConnell Building",
        description: "Engineering building",
        street: "1400 De Maisonneuve Blvd. W",
        postalCode: "H3G 1M8",
        location: const Coordinate(latitude: 45.4972, longitude: -73.5786),
        hours: gmw.OpeningHoursDetail(),
        campus: Campus.sgw,
        outlinePoints: const [],
        images: const [],
      );
      hvm.buildings = {"MB": building};
      hvm.upcomingClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime(2026, 1, 5, 13, 0),
        DateTime(2026, 1, 5, 14, 0),
        Room("235", "2", Campus.sgw, "mb"),
      );

      await hvm.setDestinationToUpcomingClassBuilding();

      expect(hvm.isSearchBarExpanded, isTrue);
      expect(hvm.startCoordinate, isNotNull);
      expect(hvm.selectedStartLabel, equals("Current location"));
      expect(hvm.destinationCoordinate, equals(building.location));
      expect(hvm.selectedDestinationLabel, equals(building.name));
      expect(hvm.cameraTarget, equals(building.location));
      expect(hvm.selectedCampusIndex, equals(0));
    });

    test("setDestinationToUpcomingClassBuilding shows info when building is missing", () async {
      hvm.upcomingClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime(2026, 1, 5, 13, 0),
        DateTime(2026, 1, 5, 14, 0),
        Room("235", "2", Campus.sgw, "x"),
      );

      await hvm.setDestinationToUpcomingClassBuilding();

      expect(hvm.isSearchBarExpanded, isTrue);
      expect(hvm.startCoordinate, isNotNull);
      expect(hvm.destinationCoordinate, isNull);
      expect(hvm.generateInfoMessage, equals("Unable to find X on the map."));
    });

    test("setDestinationToUpcomingClassBuilding falls back to first places suggestion", () async {
      trackingPlacesInteractor.searchResults = const [
        PlaceSuggestion(
          placeId: "place-1",
          description: "Concordia University EV Building, Montreal",
          mainText: "Concordia University EV Building",
          secondaryText: "Montreal, QC",
        ),
      ];
      trackingPlacesInteractor.resolveResult = const Coordinate(
        latitude: 45.4958,
        longitude: -73.5779,
      );
      hvm.upcomingClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime(2026, 1, 5, 13, 0),
        DateTime(2026, 1, 5, 14, 0),
        Room("235", "2", Campus.sgw, "ev"),
      );

      await hvm.setDestinationToUpcomingClassBuilding();

      expect(hvm.isSearchBarExpanded, isTrue);
      expect(hvm.startCoordinate, isNotNull);
      expect(trackingPlacesInteractor.lastQuery, equals("ev"));
      expect(hvm.destinationCoordinate, equals(trackingPlacesInteractor.resolveResult));
      expect(hvm.selectedDestinationLabel, equals("Concordia University EV Building"));
      expect(hvm.cameraTarget, equals(trackingPlacesInteractor.resolveResult));
      expect(hvm.generateInfoMessage, isNull);
    });

    test("falls back for Richard Renaud Science Complex location", () async {
      const buildingName = "Richard Renaud Science Complex";
      trackingPlacesInteractor.searchResults = const [
        PlaceSuggestion(
          placeId: "place-richard-renaud",
          description: "Richard Renaud Science Complex, Montreal",
          mainText: "Richard Renaud Science Complex",
          secondaryText: "Loyola Campus",
        ),
      ];
      trackingPlacesInteractor.resolveResult = const Coordinate(
        latitude: 45.4583,
        longitude: -73.6407,
      );
      hvm.upcomingClass = AcademicClass(
        "BIOL 201 LAB A",
        DateTime(2026, 1, 5, 13, 0),
        DateTime(2026, 1, 5, 15, 0),
        Room("S110", "S1", Campus.loyola, buildingName),
      );

      await hvm.setDestinationToUpcomingClassBuilding();

      expect(trackingPlacesInteractor.lastQuery, equals(buildingName));
      expect(hvm.destinationCoordinate, equals(trackingPlacesInteractor.resolveResult));
      expect(hvm.selectedDestinationLabel, equals("Richard Renaud Science Complex"));
      expect(hvm.generateInfoMessage, isNull);
    });

    test("falls back for HINGSTON B BUILDING location", () async {
      const buildingName = "HINGSTON B BUILDING";
      trackingPlacesInteractor.searchResults = const [
        PlaceSuggestion(
          placeId: "place-hingston-b",
          description: "Hingston Hall B, Montreal",
          mainText: "Hingston Hall B",
          secondaryText: "Loyola Campus",
        ),
      ];
      trackingPlacesInteractor.resolveResult = const Coordinate(
        latitude: 45.4590,
        longitude: -73.6401,
      );
      hvm.upcomingClass = AcademicClass(
        "CHEM 205 LEC A",
        DateTime(2026, 1, 5, 10, 0),
        DateTime(2026, 1, 5, 11, 15),
        Room("130", "1", Campus.loyola, buildingName),
      );

      await hvm.setDestinationToUpcomingClassBuilding();

      expect(trackingPlacesInteractor.lastQuery, equals(buildingName));
      expect(hvm.destinationCoordinate, equals(trackingPlacesInteractor.resolveResult));
      expect(hvm.selectedDestinationLabel, equals("Hingston Hall B"));
      expect(hvm.generateInfoMessage, isNull);
    });
  });
}
