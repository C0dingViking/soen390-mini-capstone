import "dart:async";
import "package:concordia_campus_guide/utils/coordinate_extensions.dart";
import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/building_map_data.dart";
import "package:concordia_campus_guide/domain/models/search_suggestion.dart";
import "package:concordia_campus_guide/domain/interactors/places_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/directions_interactor.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:concordia_campus_guide/data/services/location_service.dart";
import "package:concordia_campus_guide/utils/campus.dart";

enum SearchField { start, destination }

enum DepartureMode { now, departAt, arriveBy }

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
  String? selectedStartLabel;
  String? selectedDestinationLabel;
  bool isLoadingRoutes = false;
  String? routeErrorMessage;
  Map<RouteMode, RouteOption> routeOptions = {};
  RouteMode selectedRouteMode = RouteMode.walking;
  Set<Polyline> routePolylines = {};
  Set<Circle> transitChangeCircles = {};
  int _routeRequestId = 0;

  DepartureMode departureMode = DepartureMode.now;
  DateTime? selectedDepartureTime;
  DateTime? selectedArrivalTime;
  DateTime? suggestedDepartureTime;

  List<SearchSuggestion> searchResults = [];
  String _searchQuery = "";
  Timer? _searchDebounce;

  bool myLocationEnabled = false;
  bool isSearchBarExpanded = false;
  int _unfocusSearchBarSignal = 0;

  int get unfocusSearchBarSignal => _unfocusSearchBarSignal;

  static const Coordinate sgw = Coordinate(latitude: 45.4972, longitude: -73.5786);
  static const Coordinate loyola = Coordinate(latitude: 45.45823348665408, longitude: -73.64067095332564);
  final List<Coordinate> campuses = [sgw, loyola];

  int selectedCampusIndex = 0;
  Coordinate? cameraTarget;
  LatLngBounds? routeBounds;
  bool _suppressNextCameraTarget = false;

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

  void clearRouteBounds() {
    routeBounds = null;
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
    selectedStartLabel = null;
    selectedDestinationLabel = null;
    searchStartMarker = null;
    searchDestinationMarker = null;
    routeOptions = {};
    routePolylines = {};
    transitChangeCircles = {};
    routeBounds = null;
    routeErrorMessage = null;
    isLoadingRoutes = false;
    notifyListeners();
  }

  void setSearchBarExpanded(final bool value) {
    if (isSearchBarExpanded == value) return;
    isSearchBarExpanded = value;
    notifyListeners();
  }

  void requestUnfocusSearchBar() {
    _unfocusSearchBarSignal++;
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
      _suppressNextCameraTarget = true;
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

  void setDepartureMode(final DepartureMode mode) {
    if (departureMode == mode) return;
    departureMode = mode;
    if (mode == DepartureMode.now) {
      selectedDepartureTime = null;
      selectedArrivalTime = null;
      suggestedDepartureTime = null;
    }
    _loadRoutesIfReady();
  }

  void setDepartureTime(final DateTime time) {
    selectedDepartureTime = time;
    selectedArrivalTime = null;
    suggestedDepartureTime = null;
    departureMode = DepartureMode.departAt;
    _loadRoutesIfReady();
  }

  void setArrivalTime(final DateTime time) {
    selectedArrivalTime = time;
    selectedDepartureTime = null;
    departureMode = DepartureMode.arriveBy;
    _calculateSuggestedDeparture();
    _loadRoutesIfReady();
  }

  void _calculateSuggestedDeparture() {
    if (selectedArrivalTime == null || routeOptions.isEmpty) return;
    
    final selectedOption = routeOptions[selectedRouteMode];
    if (selectedOption == null || selectedOption.durationSeconds == null) return;
    
    final durationSeconds = selectedOption.durationSeconds!;
    suggestedDepartureTime = selectedArrivalTime!.subtract(
      Duration(seconds: durationSeconds),
    );
    notifyListeners();
  }

  void _handleLocationUpdate(final Coordinate posCoord) {
    bool changed = false;

    // only update cameraTarget if significantly different
    if (_suppressNextCameraTarget) {
      _suppressNextCameraTarget = false;
    } else if (!(cameraTarget?.isApproximatelyEqual(posCoord) ?? false)) {
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
      selectedStartLabel = label;
      searchStartMarker = Marker(
        markerId: const MarkerId("search-start"),
        position: coordinate.toLatLng(),
        infoWindow: InfoWindow(title: label),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      );
    } else {
      destinationCoordinate = coordinate;
      selectedDestinationLabel = label;
      searchDestinationMarker = Marker(
        markerId: const MarkerId("search-destination"),
        position: coordinate.toLatLng(),
        infoWindow: InfoWindow(title: label),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      );
    }
  }

  Future<void> _loadRoutesIfReady() async {
    if (startCoordinate == null || destinationCoordinate == null) return;
    final requestId = ++_routeRequestId;

    isLoadingRoutes = true;
    routeErrorMessage = null;
    notifyListeners();

    // Determine time parameters based on departure mode
    DateTime? departureParam;
    DateTime? arrivalParam;
    
    if (departureMode == DepartureMode.departAt) {
      departureParam = selectedDepartureTime;
    } else if (departureMode == DepartureMode.arriveBy) {
      arrivalParam = selectedArrivalTime;
    }

    final options = await directionsInteractor.getRouteOptions(
      startCoordinate!,
      destinationCoordinate!,
      departureTime: departureParam,
      arrivalTime: arrivalParam,
    );

    if (requestId != _routeRequestId) return;

    if (options.isEmpty) {
      routeErrorMessage = "No routes available.";
      isLoadingRoutes = false;
      routeOptions = {};
      routePolylines = {};
      transitChangeCircles = {};
      routeBounds = null;
      notifyListeners();
      return;
    }

    routeOptions = {for (final option in options) option.mode: option};
    if (!routeOptions.containsKey(selectedRouteMode)) {
      selectedRouteMode = options.first.mode;
    }

    _updateRoutePolylines();
    _calculateSuggestedDeparture();
    isLoadingRoutes = false;
    notifyListeners();
  }

  void selectRouteMode(final RouteMode mode) {
    if (selectedRouteMode == mode) return;
    selectedRouteMode = mode;
    _updateRoutePolylines();
    _calculateSuggestedDeparture();
    notifyListeners();
  }

  void _updateRoutePolylines() {
    final option = routeOptions[selectedRouteMode];
    if (option == null || option.polyline.isEmpty) {
      routePolylines = {};
      transitChangeCircles = {};
      routeBounds = null;
      return;
    }

    // Special handling for transit routes - show distinct segments
    if (selectedRouteMode == RouteMode.transit && option.steps.isNotEmpty) {
      _updateTransitPolylines(option);
      return;
    }

    // For non-transit routes, use single polyline with mode-specific styling
    final points = option.polyline.map((final c) => c.toLatLng()).toList();
    
    Color polylineColor;
    int polylineWidth;
    List<PatternItem> polylinePattern;
    
    switch (selectedRouteMode) {
      case RouteMode.walking:
        polylineColor = AppTheme.concordiaTurquoise;
        polylineWidth = 4;
        polylinePattern = [
          PatternItem.dot,
          PatternItem.gap(10),
        ]; // Dotted line for pedestrian paths
        break;
      case RouteMode.bicycling:
        polylineColor = AppTheme.concordiaTurquoise;
        polylineWidth = 5;
        polylinePattern = []; // Solid line
        break;
      case RouteMode.driving:
        polylineColor = AppTheme.concordiaMaroon;
        polylineWidth = 6;
        polylinePattern = []; // Solid line
        break;
      case RouteMode.transit:
        polylineColor = AppTheme.concordiaDarkBlue;
        polylineWidth = 5;
        polylinePattern = [
          PatternItem.dash(20),
          PatternItem.gap(10),
        ]; // Dashed line for transit
        break;
    }
    
    routePolylines = {
      Polyline(
        polylineId: PolylineId("route-${selectedRouteMode.name}"),
        points: points,
        color: polylineColor,
        width: polylineWidth,
        patterns: polylinePattern,
      ),
    };
    transitChangeCircles = {}; // Clear circles for non-transit modes
    routeBounds = _calculateBounds(points);
  }

  void _updateTransitPolylines(final RouteOption option) {
    final polylines = <Polyline>{};
    final circles = <Circle>{};
    final allPoints = <LatLng>[];
    int segmentIndex = 0;
    String? previousTravelMode;

    for (final step in option.steps) {
      if (step.polyline.isEmpty) continue;

      final points = step.polyline.map((final c) => c.toLatLng()).toList();
      allPoints.addAll(points);
      Color color;
      int width;
      List<PatternItem> pattern;

      if (step.travelMode == "TRANSIT" && step.transitDetails != null) {
        // Color-code based on transit type (colorblind-friendly Concordia palette)
        switch (step.transitDetails!.mode) {
          case TransitMode.subway:
            color = AppTheme.concordiaDarkBlue;
            width = 6;
            pattern = []; // Solid line
            break;
          case TransitMode.bus:
            color = AppTheme.concordiaBusCyan;
            width = 6;
            pattern = []; // Solid line
            break;
          case TransitMode.train:
            color = AppTheme.concordiaTrainMauve;
            width = 6;
            pattern = []; // Solid line
            break;
          case TransitMode.tram:
            color = AppTheme.concordiaTurquoise;
            width = 6;
            pattern = []; // Solid line
            break;
          case TransitMode.rail:
            color = AppTheme.concordiaRailGold;
            width = 6;
            pattern = []; // Solid line
            break;
        }
      } else {
        // Walking segments in transit route
        color = AppTheme.concordiaTurquoise;
        width = 4;
        pattern = [
          PatternItem.dot,
          PatternItem.gap(10),
        ]; // Dotted line for walking
      }

      // Check if travel mode changed - add circle at transition point
      if (previousTravelMode != null && previousTravelMode != step.travelMode && points.isNotEmpty) {
        circles.add(
          Circle(
            circleId: CircleId("transit-change-$segmentIndex"),
            center: points.first,
            radius: 7,
            fillColor: const Color.fromARGB(255, 134, 134, 134).withValues(alpha: 1.0), // Opaque
            strokeWidth: 3,
            strokeColor: const Color.fromARGB(255, 207, 207, 207),
          ),
        );
      }

      polylines.add(
        Polyline(
          polylineId: PolylineId("transit-segment-$segmentIndex"),
          points: points,
          color: color,
          width: width,
          patterns: pattern,
        ),
      );
      segmentIndex++;
      previousTravelMode = step.travelMode;
    }

    routePolylines = polylines;
    transitChangeCircles = circles;
    routeBounds = _calculateBounds(allPoints);
  }

  LatLngBounds? _calculateBounds(final List<LatLng> points) {
    if (points.isEmpty) return null;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
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
