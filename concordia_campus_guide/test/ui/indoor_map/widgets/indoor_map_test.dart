import "dart:math";
import "dart:ui" show PointerDeviceKind;
import "dart:collection";

import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:concordia_campus_guide/domain/interactors/calendar_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/directions_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/places_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:concordia_campus_guide/domain/models/indoor_pathfinding.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/indoor_map/view_models/indoor_view_model.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_map.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_search_bar.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter/material.dart";
import "package:flutter_google_maps_webservices/places.dart";
import "package:flutter_test/flutter_test.dart";
import "package:googleapis/calendar/v3.dart" as calendar;
import "package:provider/provider.dart";

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
    final String calendarId = "primary",
  }) async => [];

  @override
  Future<List<calendar.Event>> getEventsInRange({
    required final DateTime startDate,
    required final DateTime endDate,
    final String calendarId = "primary",
  }) async => [];

  @override
  Future<List<calendar.CalendarListEntry>> getUserCalendars() async => [];
}

class _FakeCalendarInteractor extends CalendarInteractor {
  _FakeCalendarInteractor() : super(calendarRepo: _FakeGoogleCalendarRepository());
}

class _TestHomeViewModel extends HomeViewModel {
  _TestHomeViewModel()
    : super(
        mapInteractor: MapDataInteractor(
          buildingRepo: BuildingRepository(buildingLoader: (_) async => "{}"),
        ),
        placesInteractor: _FakePlacesInteractor(),
        directionsInteractor: _FakeDirectionsInteractor(),
        calendarInteractor: _FakeCalendarInteractor(),
      );

  void seedBuildings(final Map<String, Building> seededBuildings) {
    buildings = seededBuildings;
  }
}

class TestIndoorViewModel extends IndoorViewModel {
  bool initCalled = false;
  String? initPath;

  TestIndoorViewModel() : super(floorplanInteractor: FloorplanInteractor()) {
    // provide a dummy floorplan so the widget's initial build doesn't crash
    selectedFloorplan = Floorplan(
      buildingId: "T",
      floorNumber: "1",
      svgPath: "",
      canvasWidth: 100,
      canvasHeight: 100,
    );
    // Initialize loaded room names with test data
    loadedRoomNames = ["T 110", "T 111", "T 112", "T 210", "H 820"];
    availableFloors = ["1", "2"];
  }

  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    initCalled = true;
    initPath = path;

    final normalizedPath = path.toUpperCase();

    if (normalizedPath == "H") {
      availableFloors = ["8"];
      loadedFloorplans = {
        "8": Floorplan(
          buildingId: normalizedPath,
          floorNumber: "8",
          svgPath: "testfloor8.svg",
          canvasWidth: 100,
          canvasHeight: 100,
          rooms: [
            IndoorMapRoom(
              name: "820",
              doorLocation: const Point<double>(0, 0),
              points: const [
                Point<double>(0, 0),
                Point<double>(100, 0),
                Point<double>(100, 100),
                Point<double>(0, 100),
              ],
            ),
          ],
          pois: [],
        ),
      };
      selectedFloorplan = loadedFloorplans!["8"];
      notifyListeners();
      return;
    }

    if (normalizedPath == "X") {
      availableFloors = ["1", "2"];
      loadedFloorplans = {
        "1": Floorplan(
          buildingId: normalizedPath,
          floorNumber: "1",
          svgPath: "testfloor1.svg",
          canvasWidth: 100,
          canvasHeight: 100,
          rooms: [
            IndoorMapRoom(
              name: "111",
              doorLocation: const Point<double>(10, 10),
              points: const [
                Point<double>(100, 0),
                Point<double>(200, 0),
                Point<double>(200, 100),
                Point<double>(100, 100),
              ],
            ),
          ],
          pois: const [
            PointOfInterest(
              name: "elevator-1",
              type: PoiType.elevator,
              location: Point<double>(15, 15),
            ),
            PointOfInterest(
              name: "stairs-1",
              type: PoiType.stairs,
              location: Point<double>(20, 20),
            ),
          ],
        ),
        "2": Floorplan(
          buildingId: normalizedPath,
          floorNumber: "2",
          svgPath: "testfloor2.svg",
          canvasWidth: 100,
          canvasHeight: 100,
          rooms: [
            IndoorMapRoom(
              name: "210",
              doorLocation: const Point<double>(0, 0),
              points: const [
                Point<double>(0, 0),
                Point<double>(100, 0),
                Point<double>(100, 100),
                Point<double>(0, 100),
              ],
            ),
          ],
          pois: const [
            PointOfInterest(
              name: "stairs-2",
              type: PoiType.stairs,
              location: Point<double>(25, 25),
            ),
          ],
        ),
      };
      selectedFloorplan = loadedFloorplans!["1"];
      notifyListeners();
      return;
    }

    if (normalizedPath == "Y") {
      availableFloors = ["1", "2"];
      loadedFloorplans = {
        "1": Floorplan(
          buildingId: normalizedPath,
          floorNumber: "1",
          svgPath: "testfloor1.svg",
          canvasWidth: 100,
          canvasHeight: 100,
          rooms: [
            IndoorMapRoom(
              name: "111",
              doorLocation: const Point<double>(10, 10),
              points: const [
                Point<double>(0, 0),
                Point<double>(100, 0),
                Point<double>(100, 100),
                Point<double>(0, 100),
              ],
            ),
          ],
          pois: const [
            PointOfInterest(
              name: "stairs-down-1",
              type: PoiType.stairsDown,
              location: Point<double>(20, 20),
            ),
            PointOfInterest(
              name: "stairs-up-1",
              type: PoiType.stairsUp,
              location: Point<double>(30, 30),
            ),
          ],
        ),
        "2": Floorplan(
          buildingId: normalizedPath,
          floorNumber: "2",
          svgPath: "testfloor2.svg",
          canvasWidth: 100,
          canvasHeight: 100,
          rooms: [
            IndoorMapRoom(
              name: "210",
              doorLocation: const Point<double>(40, 40),
              points: const [
                Point<double>(0, 0),
                Point<double>(100, 0),
                Point<double>(100, 100),
                Point<double>(0, 100),
              ],
            ),
          ],
          pois: const [],
        ),
      };
      selectedFloorplan = loadedFloorplans!["1"];
      notifyListeners();
      return;
    }

    if (normalizedPath == "Z") {
      availableFloors = ["1"];
      loadedFloorplans = {
        "1": Floorplan(
          buildingId: normalizedPath,
          floorNumber: "1",
          svgPath: "testfloor1.svg",
          canvasWidth: 100,
          canvasHeight: 100,
          rooms: [
            IndoorMapRoom(
              name: "111",
              doorLocation: const Point<double>(10, 10),
              points: const [
                Point<double>(0, 0),
                Point<double>(100, 0),
                Point<double>(100, 100),
                Point<double>(0, 100),
              ],
            ),
          ],
          pois: const [],
          transitions: const [
            FloorTransition(
              id: "invalidtoken",
              location: Point<double>(50, 50),
              type: TransitionType.stairs,
              groupTag: "invalidtoken",
            ),
            FloorTransition(
              id: "t-mainLobby",
              location: Point<double>(60, 60),
              type: TransitionType.stairs,
              groupTag: "mainLobby",
            ),
          ],
        ),
      };
      selectedFloorplan = loadedFloorplans!["1"];
      notifyListeners();
      return;
    }

    if (normalizedPath == "W") {
      availableFloors = ["1"];
      loadedFloorplans = {
        "1": Floorplan(
          buildingId: normalizedPath,
          floorNumber: "1",
          svgPath: "testfloor1.svg",
          canvasWidth: 100,
          canvasHeight: 100,
          rooms: [
            IndoorMapRoom(
              name: "111",
              doorLocation: const Point<double>(10, 10),
              points: const [
                Point<double>(0, 0),
                Point<double>(100, 0),
                Point<double>(100, 100),
                Point<double>(0, 100),
              ],
            ),
          ],
          pois: const [
            PointOfInterest(
              name: "washroom-1",
              type: PoiType.washroomMale,
              location: Point<double>(25, 25),
            ),
            PointOfInterest(
              name: "elevator-1",
              type: PoiType.elevator,
              location: Point<double>(20, 20),
            ),
          ],
        ),
      };
      selectedFloorplan = loadedFloorplans!["1"];
      notifyListeners();
      return;
    }

    availableFloors = ["1", "2"];
    loadedFloorplans = {
      "1": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "1",
        svgPath: "testfloor1.svg",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
          IndoorMapRoom(
            name: "111",
            doorLocation: const Point<double>(10, 10),
            points: const [
              Point<double>(100, 0),
              Point<double>(200, 0),
              Point<double>(200, 100),
              Point<double>(100, 100),
            ],
          ),
        ],
        pois: const [
          PointOfInterest(
            name: "buildingEntrance-1",
            type: PoiType.buildingEntrance,
            location: Point<double>(5, 5),
          ),
          PointOfInterest(
            name: "elevator-1",
            type: PoiType.elevator,
            location: Point<double>(15, 15),
          ),
          PointOfInterest(name: "stairs-1", type: PoiType.stairs, location: Point<double>(20, 20)),
        ],
      ),
      "2": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "2",
        svgPath: "testfloor2.svg",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "210",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
        ],
        pois: const [
          PointOfInterest(name: "stairs-2", type: PoiType.stairs, location: Point<double>(25, 25)),
        ],
      ),
    };
    selectedFloorplan = loadedFloorplans!["1"];

    notifyListeners();
  }

  @override
  Future<void> initializeRoomNames() async {
    loadedRoomNames = ["T 110", "T 111", "T 112", "T 210", "H 820"];
    notifyListeners();
  }
}

class DelayedTestIndoorViewModel extends TestIndoorViewModel {
  final Duration delay;

  DelayedTestIndoorViewModel(this.delay);

  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    await Future<void>.delayed(delay);
    await super.initializeBuildingFloorplans(path);
  }
}

class ThrowingInterFloorPathIndoorViewModel extends TestIndoorViewModel {
  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    final normalizedPath = path.toUpperCase();

    availableFloors = ["1", "2"];
    loadedFloorplans = {
      "1": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "1",
        svgPath: "testfloor1.svg",
        canvasWidth: 300,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(20, 25),
            points: const [
              Point<double>(10, 15),
              Point<double>(30, 15),
              Point<double>(30, 35),
              Point<double>(10, 35),
            ],
          ),
        ],
        corridors: const [
          Corridor(
            bounds: [
              Point<double>(0, 0),
              Point<double>(300, 0),
              Point<double>(300, 50),
              Point<double>(0, 50),
            ],
          ),
        ],
        transitions: const [
          FloorTransition(
            id: "t1-stairs-1",
            location: Point<double>(280, 25),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ],
      ),
      "2": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "2",
        svgPath: "testfloor2.svg",
        canvasWidth: 300,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "210",
            doorLocation: const Point<double>(20, 25),
            points: const [
              Point<double>(10, 15),
              Point<double>(30, 15),
              Point<double>(30, 35),
              Point<double>(10, 35),
            ],
          ),
        ],
        corridors: const [
          Corridor(
            bounds: [
              Point<double>(0, 0),
              Point<double>(300, 0),
              Point<double>(300, 50),
              Point<double>(0, 50),
            ],
          ),
        ],
        transitions: const [
          FloorTransition(
            id: "t2-stairs-1",
            location: Point<double>(280, 25),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ],
      ),
    };

    selectedFloorplan = loadedFloorplans!["1"];
    notifyListeners();
  }

  @override
  void setInterFloorPath(final List<IndoorFloorPathSegment> segments) {
    throw Exception("forced setInterFloorPath failure");
  }
}

class UnresolvableInterFloorLocationIndoorViewModel extends TestIndoorViewModel {
  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    final normalizedPath = path.toUpperCase();

    availableFloors = ["1", "2"];
    loadedRoomNames = ["$normalizedPath 11", "$normalizedPath 21"];
    loadedFloorplans = {
      "1": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "1",
        svgPath: "testfloor1.svg",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(10, 10),
            points: const [
              Point<double>(0, 0),
              Point<double>(20, 0),
              Point<double>(20, 20),
              Point<double>(0, 20),
            ],
          ),
        ],
        pois: const [],
        transitions: const [],
      ),
      "2": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "2",
        svgPath: "testfloor2.svg",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "210",
            doorLocation: const Point<double>(10, 10),
            points: const [
              Point<double>(0, 0),
              Point<double>(20, 0),
              Point<double>(20, 20),
              Point<double>(0, 20),
            ],
          ),
        ],
        pois: const [],
        transitions: const [],
      ),
    };

    selectedFloorplan = loadedFloorplans!["1"];
    notifyListeners();
  }
}

class _MissingLookupFloorplanMap extends MapBase<String, Floorplan> {
  final Map<String, Floorplan> _backing;
  final String missingKey;

  _MissingLookupFloorplanMap({
    required final Map<String, Floorplan> backing,
    required this.missingKey,
  }) : _backing = backing;

  @override
  Floorplan? operator [](final Object? key) {
    if (key == missingKey) {
      return null;
    }
    return _backing[key];
  }

  @override
  void operator []=(final String key, final Floorplan value) {
    _backing[key] = value;
  }

  @override
  void clear() {
    _backing.clear();
  }

  @override
  Iterable<String> get keys => _backing.keys;

  @override
  Floorplan? remove(final Object? key) {
    return _backing.remove(key);
  }

  @override
  Iterable<Floorplan> get values => _backing.values;

  @override
  Iterable<MapEntry<String, Floorplan>> get entries => _backing.entries;
}

class MissingInterFloorplanLookupIndoorViewModel extends TestIndoorViewModel {
  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    final normalizedPath = path.toUpperCase();

    final floor1 = Floorplan(
      buildingId: normalizedPath,
      floorNumber: "1",
      svgPath: "testfloor1.svg",
      canvasWidth: 100,
      canvasHeight: 100,
      rooms: [
        IndoorMapRoom(
          name: "110",
          doorLocation: const Point<double>(10, 10),
          points: const [
            Point<double>(0, 0),
            Point<double>(20, 0),
            Point<double>(20, 20),
            Point<double>(0, 20),
          ],
        ),
      ],
    );
    final floor2 = Floorplan(
      buildingId: normalizedPath,
      floorNumber: "2",
      svgPath: "testfloor2.svg",
      canvasWidth: 100,
      canvasHeight: 100,
      rooms: [
        IndoorMapRoom(
          name: "210",
          doorLocation: const Point<double>(10, 10),
          points: const [
            Point<double>(0, 0),
            Point<double>(20, 0),
            Point<double>(20, 20),
            Point<double>(0, 20),
          ],
        ),
      ],
    );

    loadedBuildingId = normalizedPath;
    availableFloors = ["1", "2"];
    loadedRoomNames = ["$normalizedPath 110", "$normalizedPath 210"];
    loadedFloorplans = _MissingLookupFloorplanMap(
      backing: {"1": floor1, "2": floor2},
      missingKey: "2",
    );
    selectedFloorplan = floor1;
    notifyListeners();
  }
}

class NoValidStartExitIndoorViewModel extends TestIndoorViewModel {
  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    final normalizedPath = path.toUpperCase();

    availableFloors = ["1", "2"];
    loadedFloorplans = {
      "1": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "1",
        svgPath: "testfloor1.svg",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(10, 10),
            points: const [
              Point<double>(0, 0),
              Point<double>(20, 0),
              Point<double>(20, 20),
              Point<double>(0, 20),
            ],
          ),
        ],
        pois: const [],
        transitions: const [],
      ),
      "2": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "2",
        svgPath: "testfloor2.svg",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "210",
            doorLocation: const Point<double>(10, 10),
            points: const [
              Point<double>(0, 0),
              Point<double>(20, 0),
              Point<double>(20, 20),
              Point<double>(0, 20),
            ],
          ),
        ],
        pois: const [],
        transitions: const [],
      ),
    };

    selectedFloorplan = loadedFloorplans!["1"];
    notifyListeners();
  }
}

class DestinationFloorplansMissingIndoorViewModel extends TestIndoorViewModel {
  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    final normalizedPath = path.toUpperCase();

    availableFloors = ["1", "2"];
    loadedFloorplans = {
      "1": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "1",
        svgPath: "testfloor1.svg",
        canvasWidth: 120,
        canvasHeight: 120,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(20, 20),
            points: const [
              Point<double>(10, 10),
              Point<double>(30, 10),
              Point<double>(30, 30),
              Point<double>(10, 30),
            ],
          ),
        ],
        corridors: const [
          Corridor(
            bounds: [
              Point<double>(0, 0),
              Point<double>(120, 0),
              Point<double>(120, 120),
              Point<double>(0, 120),
            ],
          ),
        ],
        pois: const [
          PointOfInterest(
            name: "buildingEntrance-1",
            type: PoiType.buildingEntrance,
            location: Point<double>(90, 90),
          ),
        ],
      ),
      "2": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "2",
        svgPath: "testfloor2.svg",
        canvasWidth: 120,
        canvasHeight: 120,
        rooms: [
          IndoorMapRoom(
            name: "210",
            doorLocation: const Point<double>(20, 20),
            points: const [
              Point<double>(10, 10),
              Point<double>(30, 10),
              Point<double>(30, 30),
              Point<double>(10, 30),
            ],
          ),
        ],
        corridors: const [
          Corridor(
            bounds: [
              Point<double>(0, 0),
              Point<double>(120, 0),
              Point<double>(120, 120),
              Point<double>(0, 120),
            ],
          ),
        ],
      ),
    };

    selectedFloorplan = loadedFloorplans!["1"];
    notifyListeners();
  }

  @override
  Future<void> initializeRoomNames() async {
    loadedRoomNames = ["T 110", "T 210", "Q 100"];
    notifyListeners();
  }
}

class ThrowingSameFloorSetPathIndoorViewModel extends TestIndoorViewModel {
  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    final normalizedPath = path.toUpperCase();

    availableFloors = ["1"];
    loadedFloorplans = {
      "1": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "1",
        svgPath: "testfloor1.svg",
        canvasWidth: 120,
        canvasHeight: 120,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(20, 20),
            points: const [
              Point<double>(10, 10),
              Point<double>(30, 10),
              Point<double>(30, 30),
              Point<double>(10, 30),
            ],
          ),
          IndoorMapRoom(
            name: "111",
            doorLocation: const Point<double>(100, 100),
            points: const [
              Point<double>(90, 90),
              Point<double>(110, 90),
              Point<double>(110, 110),
              Point<double>(90, 110),
            ],
          ),
        ],
        corridors: const [
          Corridor(
            bounds: [
              Point<double>(0, 0),
              Point<double>(120, 0),
              Point<double>(120, 120),
              Point<double>(0, 120),
            ],
          ),
        ],
      ),
    };

    selectedFloorplan = loadedFloorplans!["1"];
    notifyListeners();
  }

  @override
  void setIndoorPath(final List<Point<double>> path, {final List<Point<double>>? traversedNodes}) {
    throw Exception("forced same-floor setIndoorPath failure");
  }
}

class UnresolvableSameFloorLocationIndoorViewModel extends TestIndoorViewModel {
  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    final normalizedPath = path.toUpperCase();

    availableFloors = ["1"];
    loadedRoomNames = ["$normalizedPath 110", "$normalizedPath 11"];
    loadedFloorplans = {
      "1": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "1",
        svgPath: "testfloor1.svg",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(10, 10),
            points: const [
              Point<double>(0, 0),
              Point<double>(20, 0),
              Point<double>(20, 20),
              Point<double>(0, 20),
            ],
          ),
        ],
        pois: const [],
        transitions: const [],
      ),
    };

    selectedFloorplan = loadedFloorplans!["1"];
    notifyListeners();
  }
}

class FailingChangeFloorIndoorViewModel extends TestIndoorViewModel {
  @override
  bool changeFloor(final String floorNumber) {
    return false;
  }
}

class DestinationNoEntryFloorplanInteractor extends FloorplanInteractor {
  @override
  Future<Map<String, Floorplan>> loadFloorplans(final String directoryId) async {
    if (directoryId.toLowerCase() != "n") {
      return {};
    }

    return {
      "1": Floorplan(
        buildingId: "N",
        floorNumber: "1",
        svgPath: "n-floor-1.svg",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "100",
            doorLocation: const Point<double>(10, 10),
            points: const [
              Point<double>(0, 0),
              Point<double>(20, 0),
              Point<double>(20, 20),
              Point<double>(0, 20),
            ],
          ),
        ],
        pois: const [
          PointOfInterest(
            name: "washroom-1",
            type: PoiType.washroomMale,
            location: Point<double>(50, 50),
          ),
        ],
        transitions: const [],
      ),
    };
  }
}

class DestinationNoEntryIndoorViewModel extends TestIndoorViewModel {
  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    final normalizedPath = path.toUpperCase();

    availableFloors = ["1"];
    loadedFloorplans = {
      "1": Floorplan(
        buildingId: normalizedPath,
        floorNumber: "1",
        svgPath: "testfloor1.svg",
        canvasWidth: 120,
        canvasHeight: 120,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(20, 20),
            points: const [
              Point<double>(10, 10),
              Point<double>(30, 10),
              Point<double>(30, 30),
              Point<double>(10, 30),
            ],
          ),
        ],
        corridors: const [
          Corridor(
            bounds: [
              Point<double>(0, 0),
              Point<double>(120, 0),
              Point<double>(120, 120),
              Point<double>(0, 120),
            ],
          ),
        ],
        pois: const [
          PointOfInterest(
            name: "buildingEntrance-1",
            type: PoiType.buildingEntrance,
            location: Point<double>(90, 90),
          ),
        ],
      ),
    };

    selectedFloorplan = loadedFloorplans!["1"];
    notifyListeners();
  }

  @override
  Future<void> initializeRoomNames() async {
    loadedRoomNames = ["T 110", "N 100"];
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestIndoorViewModel ivm;

  Building makeTestBuilding(final bool supportsFloors) => Building(
    id: "T",
    name: "Test Building",
    description: "A building used for testing",
    campus: Campus.sgw,
    hours: OpeningHoursDetail(openNow: true),
    images: ["image.png"],
    location: Coordinate(latitude: 45.497, longitude: -73.578),
    outlinePoints: [],
    postalCode: "H3G 1M8",
    street: "123 Test St",
    supportedIndoorFloors: (supportsFloors) ? [1, 2] : [],
  );

  Building makeTestBuildingWithId(final String id) => Building(
    id: id,
    name: "Test Building",
    description: "A building used for testing",
    campus: Campus.sgw,
    hours: OpeningHoursDetail(openNow: true),
    images: ["image.png"],
    location: Coordinate(latitude: 45.497, longitude: -73.578),
    outlinePoints: [],
    postalCode: "H3G 1M8",
    street: "123 Test St",
    supportedIndoorFloors: const [1, 2],
  );

  Building makeCampusBuilding(final String id) => Building(
    id: id,
    name: "Building $id",
    description: "Campus building for tests",
    campus: Campus.sgw,
    hours: OpeningHoursDetail(openNow: true),
    images: ["image.png"],
    location: Coordinate(latitude: 45.497, longitude: -73.578),
    outlinePoints: [],
    postalCode: "H3G 1M8",
    street: "123 Test St",
    supportedIndoorFloors: const [1, 2],
  );

  setUp(() {
    ivm = TestIndoorViewModel();
  });

  Future<void> pumpHomeScreen(
    final WidgetTester tester,
    final bool supportsFloors, {
    final Building? building,
    final String? initialStartRoomLabel,
    final String? initialDestinationRoomLabel,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<IndoorViewModel>.value(
          value: ivm,
          child: IndoorMapView(
            building: building ?? makeTestBuilding(supportsFloors),
            initialStartRoomLabel: initialStartRoomLabel,
            initialDestinationRoomLabel: initialDestinationRoomLabel,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group("IndoorMap Widget Tests", () {
    testWidgets("initializes view model with correct building ID", (final tester) async {
      await pumpHomeScreen(tester, true);
      expect(ivm.initCalled, isTrue);
      expect(ivm.initPath, equals("T"));
      expect(find.text("Current location"), findsAtLeastNWidgets(1));
      expect(find.text("Choose destination"), findsOneWidget);
    });

    testWidgets("displays loading indicator when view model is loading", (final tester) async {
      ivm.isLoading = true;
      await pumpHomeScreen(tester, true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("prefills destination and start from building entrance on outdoor handoff", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true, initialDestinationRoomLabel: "T 111");
      await tester.pumpAndSettle();

      expect(find.text("T 111"), findsOneWidget);
      expect(find.text("T buildingEntrance-1"), findsOneWidget);
    });

    testWidgets("auto-starts navigation when both initial start and destination are provided", (
      final tester,
    ) async {
      await pumpHomeScreen(
        tester,
        true,
        initialStartRoomLabel: "T 210",
        initialDestinationRoomLabel: "T 110",
      );
      await tester.pumpAndSettle();

      expect(ivm.selectedFloorplan!.floorNumber, "2");
      expect(find.text("2"), findsOneWidget);
    });

    testWidgets("does not auto-start navigation when destination is missing", (final tester) async {
      await pumpHomeScreen(tester, true, initialStartRoomLabel: "T 110");
      await tester.pumpAndSettle();

      expect(ivm.indoorPath, isNull);
      expect(find.text("Start Navigation"), findsNothing);
    });

    testWidgets("re-applies initial destination when destination field is empty after load", (
      final tester,
    ) async {
      final delayedIvm = DelayedTestIndoorViewModel(const Duration(milliseconds: 40));

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<IndoorViewModel>.value(
            value: delayedIvm,
            child: IndoorMapView(
              building: makeTestBuilding(true),
              initialDestinationRoomLabel: "T 111",
            ),
          ),
        ),
      );
      await tester.pump();

      final destinationField = find.byType(TextField).last;
      await tester.enterText(destinationField, "");
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      final destinationTextField = tester.widgetList<TextField>(find.byType(TextField)).last;
      expect(destinationTextField.controller?.text, "T 111");
      expect(find.text("T buildingEntrance-1"), findsOneWidget);
    });

    testWidgets("falls back to elevator on lowest floor when no building entrance exists", (
      final tester,
    ) async {
      await pumpHomeScreen(
        tester,
        true,
        building: makeTestBuildingWithId("X"),
        initialDestinationRoomLabel: "X 111",
      );
      await tester.pumpAndSettle();

      expect(find.text("X 111"), findsOneWidget);
      expect(find.text("X elevator-1"), findsOneWidget);
    });

    testWidgets("falls back to stairs on lowest floor when no entrance or elevator exists", (
      final tester,
    ) async {
      await pumpHomeScreen(
        tester,
        true,
        building: makeTestBuildingWithId("Y"),
        initialDestinationRoomLabel: "Y 111",
      );
      await tester.pumpAndSettle();

      expect(find.text("Y 111"), findsOneWidget);
      expect(find.text("Y stairs-down-1"), findsOneWidget);
    });

    testWidgets("falls back to transition token when no entrance, elevator, or stairs exists", (
      final tester,
    ) async {
      await pumpHomeScreen(
        tester,
        true,
        building: makeTestBuildingWithId("Z"),
        initialDestinationRoomLabel: "Z 111",
      );
      await tester.pumpAndSettle();

      expect(find.text("Z 111"), findsOneWidget);
      expect(find.text("Z mainLobby"), findsOneWidget);
    });

    testWidgets("queryable rooms include stairsUp/stairsDown", (final tester) async {
      await pumpHomeScreen(tester, true, building: makeTestBuildingWithId("Y"));
      await tester.pumpAndSettle();

      final searchBarY = tester.widget<IndoorSearchBar>(find.byType(IndoorSearchBar));
      expect(searchBarY.queryableRooms, contains("Y stairs-down-1"));
      expect(searchBarY.queryableRooms, contains("Y stairs-up-1"));
    });

    testWidgets("queryable rooms include other building rooms", (final tester) async {
      await pumpHomeScreen(tester, true, building: makeTestBuildingWithId("T"));
      await tester.pumpAndSettle();

      final searchBar = tester.widget<IndoorSearchBar>(find.byType(IndoorSearchBar));
      expect(searchBar.queryableRooms, contains("H 820"));
    });

    testWidgets("queryable rooms include transition tokens and exclude invalid transitions", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true, building: makeTestBuildingWithId("Z"));
      await tester.pumpAndSettle();

      final searchBarZ = tester.widget<IndoorSearchBar>(find.byType(IndoorSearchBar));
      expect(searchBarZ.queryableRooms, contains("Z mainLobby"));
      expect(
        searchBarZ.queryableRooms.where((final room) => room.contains("invalidtoken")),
        isEmpty,
      );
    });

    testWidgets("queryable rooms exclude non-queryable POIs", (final tester) async {
      await pumpHomeScreen(tester, true, building: makeTestBuildingWithId("W"));
      await tester.pumpAndSettle();

      final searchBarW = tester.widget<IndoorSearchBar>(find.byType(IndoorSearchBar));
      expect(searchBarW.queryableRooms, contains("W elevator-1"));
      expect(searchBarW.queryableRooms, isNot(contains("W washroom-1")));
    });

    testWidgets("shows handoff bar when inter-building plan is provided", (final tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<IndoorViewModel>.value(
            value: ivm,
            child: IndoorMapView(
              building: makeTestBuilding(true),
              initialStartRoomLabel: "T 110",
              initialDestinationRoomLabel: "T buildingEntrance-1",
              interBuildingDestinationBuildingId: "H",
              interBuildingDestinationEntryLabel: "H buildingEntrance-1",
              interBuildingDestinationRoomLabel: "H 820",
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Continue outdoors to H."), findsOneWidget);
      expect(find.byKey(const Key("continue_outdoor_navigation_button")), findsOneWidget);
    });

    testWidgets("continue outdoors clears indoor path and updates home navigation labels", (
      final tester,
    ) async {
      final homeVm = _TestHomeViewModel();
      homeVm.seedBuildings({"T": makeCampusBuilding("T"), "H": makeCampusBuilding("H")});

      ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HomeViewModel>.value(value: homeVm),
            ChangeNotifierProvider<IndoorViewModel>.value(value: ivm),
          ],
          child: MaterialApp(
            home: IndoorMapView(
              building: makeTestBuilding(true),
              initialStartRoomLabel: "T 110",
              initialDestinationRoomLabel: "T buildingEntrance-1",
              interBuildingDestinationBuildingId: "H",
              interBuildingDestinationEntryLabel: "H buildingEntrance-1",
              interBuildingDestinationRoomLabel: "H 820",
            ),
          ),
        ),
      );
      await tester.pump();

      final continueButton = find.byKey(const Key("continue_outdoor_navigation_button"));
      final buttonWidget = tester.widget<ElevatedButton>(continueButton);
      buttonWidget.onPressed?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));

      expect(ivm.indoorPath, isNull);
      expect(homeVm.selectedStartLabel, "Building T");
      expect(homeVm.selectedDestinationLabel, "H 820");
    });

    testWidgets("shows error popup when inter-building start has no valid exit point", (
      final tester,
    ) async {
      ivm = NoValidStartExitIndoorViewModel();
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "H 820");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(find.text("Navigation Error"), findsAtLeastNWidgets(1));
      expect(
        find.text("No valid exit point found in the starting building."),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets("shows error popup when destination building has no floor plans", (
      final tester,
    ) async {
      ivm = DestinationFloorplansMissingIndoorViewModel();
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "Q 100");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Navigation Error"), findsAtLeastNWidgets(1));
      expect(
        find.text("No floor plans available for the destination building."),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets("shows error popup when destination building has no valid entry point", (
      final tester,
    ) async {
      final destinationInteractor = DestinationNoEntryFloorplanInteractor();
      ivm = DestinationNoEntryIndoorViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<IndoorViewModel>.value(
            value: ivm,
            child: IndoorMapView(
              building: makeTestBuilding(true),
              floorplanInteractor: destinationInteractor,
            ),
          ),
        ),
      );
      await tester.pump();

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "N 100");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Navigation Error"), findsAtLeastNWidgets(1));
      expect(
        find.text("No valid entry point found in the destination building."),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets("pops back to previous screen when load fails", (final tester) async {
      ivm.loadFailed = true;
      await tester.pumpWidget(
        ChangeNotifierProvider<IndoorViewModel>.value(
          value: ivm,
          child: MaterialApp(
            initialRoute: "/indoor",
            routes: {
              "/": (final context) => const Scaffold(body: Text("Previous Screen")),
              "/indoor": (final context) => IndoorMapView(building: makeTestBuilding(false)),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Failed to load floor plans for this building. Please try again later."),
        findsOneWidget,
      );
      await tester.tap(find.text("Dismiss"));
      await tester.pumpAndSettle();

      expect(find.text("Previous Screen"), findsOneWidget);
      expect(find.byType(IndoorMapView), findsNothing);
    });

    test("maps tap position to clicked room name", () {
      final floorplan = Floorplan(
        buildingId: "T",
        floorNumber: "1",
        svgPath: "",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
        ],
      );

      final roomName = resolveRoomNameFromTapPosition(
        const Offset(50, 50),
        const Size(100, 100),
        floorplan,
      );

      expect(roomName, equals("110"));
    });

    test("returns null when tap is outside room area", () {
      final floorplan = Floorplan(
        buildingId: "T",
        floorNumber: "1",
        svgPath: "",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
        ],
      );

      final roomName = resolveRoomNameFromTapPosition(
        const Offset(150, 50),
        const Size(100, 100),
        floorplan,
      );

      expect(roomName, isNull);
    });

    test("returns null for taps in letterboxed area outside SVG content", () {
      final floorplan = Floorplan(
        buildingId: "T",
        floorNumber: "1",
        svgPath: "",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
        ],
      );

      final roomName = resolveRoomNameFromTapPosition(
        const Offset(50, 25),
        const Size(100, 200),
        floorplan,
      );

      expect(roomName, isNull);
    });

    test("returns null when viewport size is invalid", () {
      final floorplan = Floorplan(
        buildingId: "T",
        floorNumber: "1",
        svgPath: "",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(0, 0),
            points: const [
              Point<double>(0, 0),
              Point<double>(100, 0),
              Point<double>(100, 100),
              Point<double>(0, 100),
            ],
          ),
        ],
      );

      final roomName = resolveRoomNameFromTapPosition(
        const Offset(50, 50),
        const Size(0, 0),
        floorplan,
      );

      expect(roomName, isNull);
    });

    test("returns null when room polygon has fewer than three points", () {
      final floorplan = Floorplan(
        buildingId: "T",
        floorNumber: "1",
        svgPath: "",
        canvasWidth: 100,
        canvasHeight: 100,
        rooms: [
          IndoorMapRoom(
            name: "110",
            doorLocation: const Point<double>(0, 0),
            points: const [Point<double>(0, 0), Point<double>(100, 100)],
          ),
        ],
      );

      final roomName = resolveRoomNameFromTapPosition(
        const Offset(50, 50),
        const Size(100, 100),
        floorplan,
      );

      expect(roomName, isNull);
    });

    testWidgets("floor picker displays the current floor", (final tester) async {
      await pumpHomeScreen(tester, true);

      expect(find.text("1"), findsOneWidget);
    });

    testWidgets("floor picker switches to the next floor when up is tapped", (final tester) async {
      await pumpHomeScreen(tester, true);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(ivm.selectedFloorplan!.floorNumber, "2");
      expect(find.text("2"), findsOneWidget);
    });

    testWidgets("floor picker switches to the prev. floor when down is hit", (final tester) async {
      await pumpHomeScreen(tester, true);

      // go to second floor and back to test
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
      await tester.pumpAndSettle();

      expect(ivm.selectedFloorplan!.floorNumber, "1");
      expect(find.text("1"), findsOneWidget);
    });

    testWidgets("floor picker hides the up arrow if you can't go higher", (final tester) async {
      await pumpHomeScreen(tester, true);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(ivm.selectedFloorplan!.floorNumber, "2");
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets("floor picker hides the down arrow if you can't go lower", (final tester) async {
      await pumpHomeScreen(tester, true);

      expect(ivm.selectedFloorplan!.floorNumber, "1");
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets("tap on map populates destination field", (final tester) async {
      await pumpHomeScreen(tester, true);

      final gestureFinder = find
          .ancestor(of: find.byType(InteractiveViewer), matching: find.byType(GestureDetector))
          .first;

      final gestureWidget = tester.widget<GestureDetector>(gestureFinder);
      final size = tester.getSize(gestureFinder);
      final tapPosition = Offset(size.width / 2, size.height / 2);

      gestureWidget.onTapUp!(
        TapUpDetails(localPosition: tapPosition, kind: PointerDeviceKind.touch),
      );
      await tester.pump();

      final destinationTextField = tester.widgetList<TextField>(find.byType(TextField)).last;
      expect(destinationTextField.controller?.text, "T 110");
    });

    testWidgets("Start Navigation switches to floor of current location", (final tester) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 210");
      await tester.enterText(destinationField, "T 110");
      await tester.pumpAndSettle();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(ivm.selectedFloorplan!.floorNumber, "2");
      expect(find.text("2"), findsOneWidget);
    });

    testWidgets("Start Navigation accepts POI start labels parsed from floorplans", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T buildingEntrance-1");
      await tester.enterText(destinationField, "T 110");
      await tester.pumpAndSettle();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(ivm.selectedFloorplan!.buildingId, "T");
      expect(ivm.selectedFloorplan!.floorNumber, "1");
      expect(find.text("1"), findsOneWidget);
    });

    testWidgets("Start Navigation accepts transition start labels parsed from floorplans", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true, building: makeTestBuildingWithId("Z"));

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "Z mainLobby");
      await tester.enterText(destinationField, "Z 111");
      await tester.pumpAndSettle();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(find.byType(IndoorMapView), findsOneWidget);
      expect(ivm.selectedFloorplan!.buildingId, "Z");
    });
  });

  group("Same-floor navigation (lines 179-211)", () {
    testWidgets("shows popup when changing to same-floor start fails", (final tester) async {
      ivm = FailingChangeFloorIndoorViewModel();
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "T 111");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(find.text("Navigation Error"), findsAtLeastNWidgets(1));
      expect(find.text("Failed to change floor. Please try again."), findsAtLeastNWidgets(1));
    });

    testWidgets("shows popup when floorplans are unavailable at navigation time", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      ivm.loadedFloorplans = {};

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "T 111");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pump();

      expect(find.text("No floor plans available for current location."), findsOneWidget);
    });

    testWidgets("hides Start Navigation when any typed location is invalid", (final tester) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "X 999");
      await tester.pump();
      await tester.pump();

      expect(find.text("Start Navigation"), findsNothing);
    });

    testWidgets("same-floor route between two valid rooms on floor 1", (final tester) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "T 111");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // After navigation, should still be on floor 1
      expect(ivm.selectedFloorplan!.floorNumber, "1");
    });

    testWidgets("same-floor route does not crash on pathfinding errors", (final tester) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "T 111");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // The view is still intact regardless of pathfinding outcome
      expect(find.byType(IndoorMapView), findsOneWidget);
    });

    testWidgets("shows location error popup when same-floor locations cannot be resolved", (
      final tester,
    ) async {
      ivm = UnresolvableSameFloorLocationIndoorViewModel();
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "T 11");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(find.text("Navigation Error"), findsAtLeastNWidgets(1));
      expect(
        find.text("Unable to locate one or both locations on this floor."),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets("shows generic error popup when same-floor route computation fails unexpectedly", (
      final tester,
    ) async {
      ivm = ThrowingSameFloorSetPathIndoorViewModel();
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "T 111");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(find.text("Navigation Error"), findsAtLeastNWidgets(1));
      expect(
        find.text("Failed to compute indoor route. Please try again."),
        findsAtLeastNWidgets(1),
      );
    });
  });

  group("Segment navigation bar (lines 367-453)", () {
    testWidgets("inter-floor nav bar is hidden when no inter-floor route is active", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
    });

    testWidgets("inter-floor route between floors 1 and 2 exercises the inter-floor branch", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 210");
      await tester.enterText(destinationField, "T 110");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(IndoorMapView), findsOneWidget);
    });

    testWidgets("shows location error popup when inter-floor locations cannot be resolved", (
      final tester,
    ) async {
      ivm = UnresolvableInterFloorLocationIndoorViewModel();
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 11");
      await tester.enterText(destinationField, "T 21");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(find.text("Navigation Error"), findsAtLeastNWidgets(1));
      expect(find.text("Unable to locate one or both locations."), findsAtLeastNWidgets(1));
    });

    testWidgets("shows floorplan missing popup when one inter-floor floorplan lookup fails", (
      final tester,
    ) async {
      ivm = MissingInterFloorplanLookupIndoorViewModel();
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.enterText(destinationField, "T 210");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(find.text("Navigation Error"), findsAtLeastNWidgets(1));
      expect(
        find.text("Floor plan data is missing for one of the floors."),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets("shows generic error popup when inter-floor route computation flow fails", (
      final tester,
    ) async {
      ivm = ThrowingInterFloorPathIndoorViewModel();
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 210");
      await tester.enterText(destinationField, "T 110");
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text("Start Navigation"));
      await tester.pumpAndSettle();

      expect(find.text("Navigation Error"), findsAtLeastNWidgets(1));
      expect(
        find.text("Failed to compute inter-floor route. Please try again."),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets("segment nav bar displays step count when inter-floor route is active", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t2-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      expect(find.textContaining("Step 1 of 2"), findsOneWidget);
    });

    testWidgets("segment description: exit only → Start → <transition>", (final tester) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-elevator-1",
            location: const Point<double>(50, 50),
            type: TransitionType.elevator,
            groupTag: "elevator-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t2-elevator-1",
            location: const Point<double>(50, 50),
            type: TransitionType.elevator,
            groupTag: "elevator-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // First segment has no entry, has exit → "Floor 1: Start → Elevator"
      expect(find.textContaining("Start"), findsWidgets);
      expect(find.textContaining("Elevator"), findsWidgets);
    });

    testWidgets("segment description: both entry and exit transitions", (final tester) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-elevator-1",
            location: const Point<double>(50, 50),
            type: TransitionType.elevator,
            groupTag: "elevator-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(75, 75)],
          entryTransition: FloorTransition(
            id: "t2-elevator-1",
            location: const Point<double>(50, 50),
            type: TransitionType.elevator,
            groupTag: "elevator-1",
          ),
          exitTransition: FloorTransition(
            id: "t2-escalator-1",
            location: const Point<double>(75, 75),
            type: TransitionType.escalator,
            groupTag: "escalator-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "3",
          path: [const Point<double>(75, 75), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t3-escalator-1",
            location: const Point<double>(75, 75),
            type: TransitionType.escalator,
            groupTag: "escalator-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // Advance to segment 2 which has both entry (elevator) and exit (escalator)
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      await tester.pump();

      // "Floor 2: Elevator → Escalator"
      expect(find.textContaining("Elevator"), findsWidgets);
      expect(find.textContaining("Escalator"), findsWidgets);
    });

    testWidgets("segment description: entry only → <transition> → Destination", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "3",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t3-escalator-1",
            location: const Point<double>(50, 50),
            type: TransitionType.escalator,
            groupTag: "escalator-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // Advance to last segment — entry only → "Floor 3: Escalator → Destination"
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining("Escalator"), findsWidgets);
      expect(find.textContaining("Destination"), findsWidgets);
    });

    testWidgets("segment description: no transitions → just floor number", (final tester) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: null,
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // Advance to segment 2 which has no transitions
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      await tester.pump();

      // Both transitions null → description is just "Floor 2"
      expect(find.textContaining("Floor 2"), findsWidgets);
    });

    testWidgets("tapping next segment advances to next step", (final tester) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t2-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining("Step 2 of 2"), findsOneWidget);
    });

    testWidgets("tapping previous segment goes back to prior step", (final tester) async {
      await pumpHomeScreen(tester, true);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t2-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // Go forward then back
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining("Step 2 of 2"), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining("Step 1 of 2"), findsOneWidget);
    });
  });

  group("Inter-floor segment bar visibility in build (lines 568-573)", () {
    testWidgets("segment navigation bar appears only when isInterFloorRoute is true", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      // Initially no inter-floor route → bar not shown
      expect(find.textContaining("Step"), findsNothing);

      final segments = <IndoorFloorPathSegment>[
        IndoorFloorPathSegment(
          floorNumber: "1",
          path: [const Point<double>(0, 0), const Point<double>(50, 50)],
          entryTransition: null,
          exitTransition: FloorTransition(
            id: "t1-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
        ),
        IndoorFloorPathSegment(
          floorNumber: "2",
          path: [const Point<double>(50, 50), const Point<double>(100, 100)],
          entryTransition: FloorTransition(
            id: "t2-stairs-1",
            location: const Point<double>(50, 50),
            type: TransitionType.stairs,
            groupTag: "stairs-1",
          ),
          exitTransition: null,
        ),
      ];

      ivm.setInterFloorPath(segments);
      await tester.pump();
      await tester.pump();

      // The segment bar is now rendered
      expect(ivm.isInterFloorRoute, isTrue);
      expect(find.textContaining("Step 1 of 2"), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });
  });

  group("End indoor navigation behavior", () {
    testWidgets("End Navigation button is hidden when no indoor navigation is displayed", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      expect(find.text("End Navigation"), findsNothing);
    });

    testWidgets("End Navigation button appears when indoor navigation is displayed", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
      await tester.pump();

      expect(find.text("End Navigation"), findsOneWidget);
    });

    testWidgets("pressing End Navigation ends indoor navigation", (final tester) async {
      await pumpHomeScreen(tester, true);

      ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
      await tester.pump();

      await tester.tap(find.text("End Navigation"));
      await tester.pump();

      expect(ivm.indoorPath, isNull);
      expect(find.text("End Navigation"), findsNothing);
    });

    testWidgets(
      "clearing start or destination ends navigation when indoor navigation is displayed",
      (final tester) async {
        await pumpHomeScreen(tester, true);

        final startField = find.byType(TextField).first;
        final destinationField = find.byType(TextField).last;

        await tester.enterText(startField, "T 110");
        await tester.enterText(destinationField, "T 111");
        await tester.pump();

        ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
        await tester.pump();

        await tester.tap(find.descendant(of: startField, matching: find.byIcon(Icons.close)));
        await tester.pump();

        expect(ivm.indoorPath, isNull);

        ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
        await tester.pump();

        await tester.tap(find.descendant(of: destinationField, matching: find.byIcon(Icons.close)));
        await tester.pump();

        expect(ivm.indoorPath, isNull);
      },
    );
  });

  // Lines 641-670: _AnimatedIndoorPath widget

  group("AnimatedIndoorPath (lines 641-670)", () {
    testWidgets("indoor path painter is shown when indoorPath is set", (final tester) async {
      await pumpHomeScreen(tester, true);

      // Set an indoor path so the _AnimatedIndoorPath widget is built,
      // which creates an AnimationController with ..repeat().
      // Use pump() instead of pumpAndSettle() because the repeating
      // animation never settles.
      ivm.setIndoorPath([
        const Point<double>(0, 0),
        const Point<double>(50, 50),
        const Point<double>(100, 100),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets("indoor path painter is absent when indoorPath is null", (final tester) async {
      await pumpHomeScreen(tester, true);

      ivm.clearIndoorPath();
      await tester.pump();
      await tester.pump();

      expect(find.byType(IndoorMapView), findsOneWidget);
    });

    testWidgets("indoor path painter updates when path changes", (final tester) async {
      await pumpHomeScreen(tester, true);

      ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
      await tester.pump();
      await tester.pump();

      ivm.setIndoorPath([
        const Point<double>(10, 10),
        const Point<double>(90, 90),
        const Point<double>(50, 25),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(IndoorMapView), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets("clearing indoor path removes the path painter", (final tester) async {
      await pumpHomeScreen(tester, true);

      ivm.setIndoorPath([const Point<double>(0, 0), const Point<double>(50, 50)]);
      await tester.pump();
      await tester.pump();

      final customPaintCountBefore = tester.widgetList(find.byType(CustomPaint)).length;

      ivm.clearIndoorPath();
      await tester.pump();
      await tester.pump();

      final customPaintCountAfter = tester.widgetList(find.byType(CustomPaint)).length;

      expect(customPaintCountAfter, lessThanOrEqualTo(customPaintCountBefore));
    });
  });

  group("Room highlighting for start and end room selection (RoomHighlightPainter)", () {
    testWidgets("clearing start field immediately clears start room highlight", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;

      await tester.enterText(startField, "T 110");
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedStartRoomName, equals("110"));

      await tester.enterText(startField, "");
      await tester.pump();

      expect(ivm.selectedStartRoomName, isNull);
    });

    testWidgets("clearing destination field immediately clears end room highlight", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final destinationField = find.byType(TextField).last;

      await tester.enterText(destinationField, "T 110");
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedEndRoomName, equals("110"));

      await tester.enterText(destinationField, "");
      await tester.pump();

      expect(ivm.selectedEndRoomName, isNull);
    });

    testWidgets("entering valid 'BUILDING ROOM' format for start selects start room on blur", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;

      await tester.enterText(startField, "T 110");
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedStartRoomName, equals("110"));
    });

    testWidgets("entering valid 'BUILDING ROOM' format for destination selects end room on blur", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final destinationField = find.byType(TextField).last;

      await tester.enterText(destinationField, "T 210");
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedEndRoomName, equals("210"));
    });

    testWidgets("both start and end rooms can be selected simultaneously and highlighted", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedStartRoomName, equals("110"));

      await tester.enterText(destinationField, "T 111");
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedStartRoomName, equals("110"));
      expect(ivm.selectedEndRoomName, equals("111"));

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets("start room name parsing extracts room number after building ID", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;

      await tester.enterText(startField, "H 820");
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedStartRoomName, equals("820"));
    });

    testWidgets("end room name parsing extracts room number after building ID", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final destinationField = find.byType(TextField).last;

      await tester.enterText(destinationField, "H 820");
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedEndRoomName, equals("820"));
    });

    testWidgets("empty start field on blur does not select any start room", (final tester) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;

      await tester.tap(startField);
      await tester.pump();
      await tester.tap(find.byType(Scaffold));
      await tester.pump();

      expect(ivm.selectedStartRoomName, isNull);
    });

    testWidgets("whitespace-only start text clears selection on blur", (final tester) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;

      await tester.enterText(startField, "T 110");
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(ivm.selectedStartRoomName, equals("110"));

      await tester.enterText(startField, "   ");
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(ivm.selectedStartRoomName, isNull);
    });

    testWidgets("start room becomes unavailable after floor change clears selection", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;

      await tester.enterText(startField, "T 110");
      await tester.pump();
      await tester.tap(find.byType(Scaffold));
      await tester.pump();

      expect(ivm.selectedStartRoomName, equals("110"));

      ivm.resetFloorplanLoadState();
      ivm.loadedRoomNames = [];
      await tester.pump();

      expect(ivm.selectedStartRoomName, isNull);
    });

    testWidgets("end room becomes unavailable after floor change clears selection", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final destinationField = find.byType(TextField).last;

      await tester.enterText(destinationField, "T 110");
      await tester.pump();
      await tester.tap(find.byType(Scaffold));
      await tester.pump();

      expect(ivm.selectedEndRoomName, equals("110"));

      ivm.resetFloorplanLoadState();
      ivm.loadedRoomNames = [];
      await tester.pump();

      expect(ivm.selectedEndRoomName, isNull);
    });

    testWidgets("room highlight painter is shown when only start room is selected", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;

      await tester.enterText(startField, "T 110");
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedStartRoomName, equals("110"));
      expect(ivm.selectedEndRoomName, isNull);
    });

    testWidgets("room highlight painter is shown when only end room is selected", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final destinationField = find.byType(TextField).last;

      await tester.enterText(destinationField, "T 111");
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedStartRoomName, isNull);
      expect(ivm.selectedEndRoomName, equals("111"));
    });

    testWidgets("room highlight painter is absent when no rooms are selected", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      expect(ivm.selectedStartRoomName, isNull);
      expect(ivm.selectedEndRoomName, isNull);

      final startField = find.byType(TextField).first;
      await tester.enterText(startField, "");
      await tester.pump();

      expect(ivm.selectedStartRoomName, isNull);
      expect(ivm.selectedEndRoomName, isNull);
    });

    testWidgets("clearing start room while end room is selected keeps highlight painter", (
      final tester,
    ) async {
      await pumpHomeScreen(tester, true);

      final startField = find.byType(TextField).first;
      final destinationField = find.byType(TextField).last;

      await tester.enterText(startField, "T 110");
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pump();

      await tester.enterText(destinationField, "T 111");
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(ivm.selectedStartRoomName, equals("110"));
      expect(ivm.selectedEndRoomName, equals("111"));

      await tester.enterText(startField, "");
      await tester.pump();

      expect(ivm.selectedStartRoomName, isNull);
      expect(ivm.selectedEndRoomName, equals("111"));
    });
  });
}
