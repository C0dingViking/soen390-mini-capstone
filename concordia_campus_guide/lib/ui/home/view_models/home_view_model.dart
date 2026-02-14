import "dart:async";
import "package:concordia_campus_guide/utils/coordinate_extensions.dart";
import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/building_map_data.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/domain/models/search_suggestion.dart";
import "package:concordia_campus_guide/domain/interactors/places_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/directions_interactor.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:concordia_campus_guide/data/services/location_service.dart";
import "package:concordia_campus_guide/utils/campus.dart";

enum SearchField { start, destination }

class HomeViewModel extends ChangeNotifier {
  final MapDataInteractor mapInteractor;
  final PlacesInteractor placesInteractor;
  final DirectionsInteractor directionsInteractor;
  Color _buildingOutlineColor = AppTheme.concordiaMaroon;

  HomeViewModel({
    required this.mapInteractor,
    required this.placesInteractor,
    required this.directionsInteractor,
  });

  Map<String, Building> buildings = {};
  Set<Polygon> buildingOutlines = {};
  Set<Marker> buildingMarkers = {};
  Building? currentBuilding;
  StreamSubscription<Coordinate>? _locationSubscription;
  bool isLoading = false;
  String? errorMessage;
  bool isSearchingPlaces = false;
  bool isResolvingPlace = false;
  bool isResolvingStartLocation = false;
  Marker? searchStartMarker;
  Marker? searchDestinationMarker;
  Coordinate? startCoordinate;
  Coordinate? destinationCoordinate;
  bool isLoadingRoutes = false;
  String? routeErrorMessage;
  Map<RouteMode, RouteOption> routeOptions = {};
  RouteMode selectedRouteMode = RouteMode.walking;
  Set<Polyline> routePolylines = {};
  int _routeRequestId = 0;

  List<SearchSuggestion> searchResults = [];
  String _searchQuery = "";
  Timer? _searchDebounce;

  bool myLocationEnabled = false;

  static const Coordinate sgw = Coordinate(latitude: 45.4972, longitude: -73.5786);
  static const Coordinate loyola = Coordinate(latitude: 45.45823348665408, longitude: -73.64067095332564);
  final List<Coordinate> campuses = [sgw, loyola];

  int selectedCampusIndex = 0;
  Coordinate? cameraTarget;

  set buildingOutlineColor(final Color color) {
    _buildingOutlineColor = color;
    if (buildings.isNotEmpty) {
      buildingOutlines = mapInteractor.generateBuildingPolygons(buildings.values, color);
    }
    notifyListeners();
  }

  Future<void> initializeBuildingsData(final String path) async {
  isLoading = true;
  errorMessage = null;
  notifyListeners();

  final BuildingMapDataDTO payload = await mapInteractor.loadBuildingsWithMapElements(path, _buildingOutlineColor);

  if (payload.errorMessage == null) {
    buildings = payload.buildings;
    buildingOutlines = payload.buildingOutlines;
    buildingMarkers = payload.buildingMarkers;
    // start location service and subscribe to updates
    await LocationService.instance.start();
    _locationSubscription?.cancel();
    _locationSubscription = LocationService.instance.positionStream.listen(_handleLocationUpdate);
  } else {
    errorMessage = payload.errorMessage;
    logger.e(
      "HomeViewModel: something went wrong loading building data",
      error: payload.errorMessage
    );
  }

  isLoading = false;
  notifyListeners();
}

  Future<void> goToCurrentLocation() async {
    errorMessage = null;
    notifyListeners();
    try {
      // ask LocationService for current position and ensure streaming
      final posCoord = await LocationService.instance.getCurrentPosition();
      bool changed = false;
      if (!(cameraTarget?.isApproximatelyEqual(posCoord) ?? false)) {
        cameraTarget = posCoord;
        changed = true;
      }
      if (!myLocationEnabled) {
        myLocationEnabled = true;
        changed = true;
      }
      if (changed) notifyListeners();

      await LocationService.instance.start();
    } catch (e) {
      errorMessage = "Error: $e";
      notifyListeners();
    }
  }

  void toggleCampus() {
    selectedCampusIndex = (selectedCampusIndex + 1) % campuses.length;
    cameraTarget = campuses[selectedCampusIndex];
    notifyListeners();
  }

  void clearCameraTarget() {
    cameraTarget = null;
    notifyListeners();
  }

  Set<Marker> get mapMarkers {
    final markers = <Marker>{...buildingMarkers};
    if (searchStartMarker != null) markers.add(searchStartMarker!);
    if (searchDestinationMarker != null) markers.add(searchDestinationMarker!);
    return markers;
  }

  void updateSearchQuery(final String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();

    final buildingSuggestions = _buildingSuggestions(query);
    searchResults = buildingSuggestions;
    isSearchingPlaces = false;
    notifyListeners();

    final trimmed = query.trim();
    if (trimmed.length < 3) return;

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (trimmed != _searchQuery.trim()) return;
      isSearchingPlaces = true;
      notifyListeners();

      final places = await placesInteractor.searchPlaces(trimmed);
      if (trimmed != _searchQuery.trim()) {
        isSearchingPlaces = false;
        notifyListeners();
        return;
      }

      final combined = <SearchSuggestion>[
        ...buildingSuggestions,
        ...places.map(SearchSuggestion.place),
      ];

      searchResults = combined;
      isSearchingPlaces = false;
      notifyListeners();
    });
  }

  void clearSearchResults() {
    _searchDebounce?.cancel();
    _searchQuery = "";
    if (searchResults.isNotEmpty || isSearchingPlaces) {
      searchResults = [];
      isSearchingPlaces = false;
      notifyListeners();
    }
  }

  void clearRouteSelection() {
    _routeRequestId++;
    startCoordinate = null;
    destinationCoordinate = null;
    searchStartMarker = null;
    searchDestinationMarker = null;
    routeOptions = {};
    routePolylines = {};
    routeErrorMessage = null;
    isLoadingRoutes = false;
    notifyListeners();
  }

  Future<void> selectSearchSuggestion(
    final SearchSuggestion suggestion,
    final SearchField field,
  ) async {
    if (suggestion.type == SearchSuggestionType.building) {
      final building = suggestion.building;
      if (building == null) return;
      _applySelection(
        field: field,
        coordinate: building.location,
        label: building.name,
        campus: building.campus,
      );
      await _loadRoutesIfReady();
      searchResults = [];
      notifyListeners();
      return;
    }

    final place = suggestion.place;
    if (place == null) return;

    errorMessage = null;
    isResolvingPlace = true;
    notifyListeners();

    final coordinate = await placesInteractor.resolvePlaceSuggestion(place);
    isResolvingPlace = false;

    if (coordinate == null) {
      errorMessage = "Unable to resolve that address.";
      notifyListeners();
      return;
    }

    _applySelection(
      field: field,
      coordinate: coordinate,
      label: suggestion.title,
      campus: null,
    );
    await _loadRoutesIfReady();
    searchResults = [];
    notifyListeners();
  }

  Future<void> setStartToCurrentLocation() async {
    errorMessage = null;
    isResolvingStartLocation = true;
    notifyListeners();

    try {
      final posCoord = await LocationService.instance.getCurrentPosition();
      _applySelection(
        field: SearchField.start,
        coordinate: posCoord,
        label: "Current location",
        campus: null,
      );
      await _loadRoutesIfReady();

      myLocationEnabled = true;
      isResolvingStartLocation = false;
      notifyListeners();

      await LocationService.instance.start();
    } catch (e) {
      isResolvingStartLocation = false;
      errorMessage = "Error: $e";
      notifyListeners();
    }
  }

  void stopLocationTracking() {
    LocationService.instance.dispose();
    myLocationEnabled = false;
    notifyListeners();
  }

  void _handleLocationUpdate(final Coordinate posCoord) {
    bool changed = false;

    // only update cameraTarget if significantly different
    if (!(cameraTarget?.isApproximatelyEqual(posCoord) ?? false)) {
      cameraTarget = posCoord;
      changed = true;
    }

    if (!myLocationEnabled) {
      myLocationEnabled = true;
      changed = true;
    }

    // find building at current location using domain interactor
    final Building? found = mapInteractor.findBuildingAt(posCoord, buildings);

    if (found?.id != currentBuilding?.id) {
      currentBuilding = found;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  int _campusIndexFor(final Campus campus) {
    return campus == Campus.sgw ? 0 : 1;
  }

  void _applySelection({
    required final SearchField field,
    required final Coordinate coordinate,
    required final String label,
    final Campus? campus,
  }) {
    if (campus != null) {
      selectedCampusIndex = _campusIndexFor(campus);
    }

    if (field == SearchField.start) {
      startCoordinate = coordinate;
      searchStartMarker = Marker(
        markerId: const MarkerId("search-start"),
        position: coordinate.toLatLng(),
        infoWindow: InfoWindow(title: label),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
      if (destinationCoordinate == null) cameraTarget = coordinate;
    } else {
      destinationCoordinate = coordinate;
      searchDestinationMarker = Marker(
        markerId: const MarkerId("search-destination"),
        position: coordinate.toLatLng(),
        infoWindow: InfoWindow(title: label),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
      cameraTarget = coordinate;
    }
  }

  Future<void> _loadRoutesIfReady() async {
    if (startCoordinate == null || destinationCoordinate == null) return;
    final requestId = ++_routeRequestId;

    isLoadingRoutes = true;
    routeErrorMessage = null;
    notifyListeners();

    final options = await directionsInteractor.getRouteOptions(
      startCoordinate!,
      destinationCoordinate!,
    );

    if (requestId != _routeRequestId) return;

    if (options.isEmpty) {
      routeErrorMessage = "No routes available.";
      isLoadingRoutes = false;
      routeOptions = {};
      routePolylines = {};
      notifyListeners();
      return;
    }

    routeOptions = {for (final option in options) option.mode: option};
    if (!routeOptions.containsKey(selectedRouteMode)) {
      selectedRouteMode = options.first.mode;
    }

    _updateRoutePolylines();
    isLoadingRoutes = false;
    notifyListeners();
  }

  void selectRouteMode(final RouteMode mode) {
    if (selectedRouteMode == mode) return;
    selectedRouteMode = mode;
    _updateRoutePolylines();
    notifyListeners();
  }

  void _updateRoutePolylines() {
    final option = routeOptions[selectedRouteMode];
    if (option == null || option.polyline.isEmpty) {
      routePolylines = {};
      return;
    }

    final points = option.polyline.map((final c) => c.toLatLng()).toList();
    routePolylines = {
      Polyline(
        polylineId: PolylineId("route-${selectedRouteMode.name}"),
        points: points,
        color: AppTheme.concordiaMaroon,
        width: 5,
      ),
    };
  }

  List<SearchSuggestion> _buildingSuggestions(final String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final matches = buildings.values.where((final b) {
      final name = b.name.toLowerCase();
      final id = b.id.toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();

    matches.sort((final a, final b) {
      final rankA = _matchRank(a, q);
      final rankB = _matchRank(b, q);
      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.name.compareTo(b.name);
    });

    return matches.take(6).map((final building) {
      final campusLabel = building.campus == Campus.sgw ? "SGW" : "LOY";
      return SearchSuggestion.building(
        building,
        subtitle: "$campusLabel - ${building.id.toUpperCase()}",
      );
    }).toList();
  }

  int _matchRank(final Building building, final String query) {
    final name = building.name.toLowerCase();
    final id = building.id.toLowerCase();
    if (name.startsWith(query)) return 0;
    if (name.contains(query)) return 1;
    if (id.startsWith(query)) return 2;
    if (id.contains(query)) return 3;
    return 4;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _locationSubscription?.cancel();
    LocationService.instance.dispose();
    super.dispose();
  }
}
