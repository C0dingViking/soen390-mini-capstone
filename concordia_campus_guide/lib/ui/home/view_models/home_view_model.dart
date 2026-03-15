import "dart:async";

import "package:concordia_campus_guide/domain/interactors/calendar_interactor.dart";
import "package:concordia_campus_guide/domain/models/academic_class.dart";
import "dart:math" as math;
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
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:concordia_campus_guide/data/services/location_service.dart";
import "package:concordia_campus_guide/utils/campus.dart";

enum SearchField { start, destination }

enum DepartureMode { now, departAt, arriveBy }

class HomeViewModel extends ChangeNotifier {
  static const String buildingDataAssetPath = "assets/maps/building_data.json";

  final MapDataInteractor mapInteractor;
  final PlacesInteractor placesInteractor;
  final DirectionsInteractor directionsInteractor;
  final CalendarInteractor calendarInteractor;
  Color _buildingOutlineColor = AppTheme.concordiaMaroon;
  bool _showLoginSuccessMessage = false;

  bool get showLoginSuccessMessage => _showLoginSuccessMessage;

  HomeViewModel({
    required this.mapInteractor,
    required this.placesInteractor,
    required this.directionsInteractor,
    required this.calendarInteractor,
  });

  Map<String, Building> buildings = {};
  Set<Polygon> buildingOutlines = {};
  Set<Marker> buildingMarkers = {};
  Building? currentBuilding;
  StreamSubscription<Coordinate>? _locationSubscription;
  bool isLoading = false;
  String? errorMessage;
  String? generateInfoMessage;
  bool isSearchingPlaces = false;
  bool isSearchingNearbyPlaces = false;
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
  double _currentMapZoom = 15;

  bool showNextClassFab = false;
  AcademicClass? upcomingClass;
  bool _showNextClassDialog = false;

  bool get showNextClassDialog => _showNextClassDialog;

  DepartureMode departureMode = DepartureMode.now;
  DateTime? selectedDepartureTime;
  DateTime? selectedArrivalTime;
  DateTime? suggestedDepartureTime;

  List<SearchSuggestion> searchResults = [];
  List<PlaceSuggestion> nearbySearchResults = [];
  String _searchQuery = "";
  Timer? _searchDebounce;
  SearchField _activeSearchField = SearchField.destination;
  int nearbySearchResultLimit = 5;

  bool myLocationEnabled = false;
  bool isSearchBarExpanded = false;
  int _unfocusSearchBarSignal = 0;

  int get unfocusSearchBarSignal => _unfocusSearchBarSignal;

  static const Coordinate sgw = Coordinate(latitude: 45.4972, longitude: -73.5786);
  static const Coordinate loyola = Coordinate(
    latitude: 45.45823348665408,
    longitude: -73.64067095332564,
  );
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

    final BuildingMapDataDTO payload = await mapInteractor.loadBuildingsWithMapElements(
      path,
      _buildingOutlineColor,
    );

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
        error: payload.errorMessage,
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
    final markers = <Marker>{...buildingMarkers, ..._nearbyResultMarkers()};
    if (searchStartMarker != null) markers.add(searchStartMarker!);
    if (searchDestinationMarker != null) markers.add(searchDestinationMarker!);
    return markers;
  }

  void setActiveSearchField(final SearchField field) {
    _activeSearchField = field;
  }

  void setNearbySearchResultLimit(final int value) {
    if (nearbySearchResultLimit == value) return;
    nearbySearchResultLimit = value;

    final trimmed = _searchQuery.trim();
    if (_activeSearchField == SearchField.destination && trimmed.length >= 3) {
      updateSearchQuery(_searchQuery);
      return;
    }

    notifyListeners();
  }

  void updateSearchQuery(final String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();

    final buildingSuggestions = _buildingSuggestions(query);
    searchResults = buildingSuggestions;
    nearbySearchResults = [];
    isSearchingPlaces = false;
    isSearchingNearbyPlaces = false;
    notifyListeners();

    final trimmed = query.trim();
    if (trimmed.length < 3) return;

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (trimmed != _searchQuery.trim()) return;

      isSearchingPlaces = true;
      final searchNearby = _activeSearchField == SearchField.destination;
      isSearchingNearbyPlaces = searchNearby;
      notifyListeners();

      final autocompleteFuture = placesInteractor.searchPlaces(trimmed);
      final nearbyFuture = searchNearby
          ? _searchNearbyPlaces(trimmed)
          : Future.value(<PlaceSuggestion>[]);

      final autocompleteResults = await autocompleteFuture;
      final nearbyResults = await nearbyFuture;

      if (trimmed != _searchQuery.trim()) {
        isSearchingPlaces = false;
        isSearchingNearbyPlaces = false;
        notifyListeners();
        return;
      }

      nearbySearchResults = nearbyResults;
      final nearbyPlaceIds = nearbyResults.map((final place) => place.placeId).toSet();
      final autocompleteSuggestions = autocompleteResults
          .where((final place) => !nearbyPlaceIds.contains(place.placeId))
          .map(SearchSuggestion.place);

      searchResults = <SearchSuggestion>[
        ...buildingSuggestions,
        ...nearbyResults.map(SearchSuggestion.place),
        ...autocompleteSuggestions,
      ];
      isSearchingPlaces = false;
      isSearchingNearbyPlaces = false;
      notifyListeners();
    });
  }

  void clearSearchResults() {
    _searchDebounce?.cancel();
    _searchQuery = "";
    if (searchResults.isNotEmpty ||
        nearbySearchResults.isNotEmpty ||
        isSearchingPlaces ||
        isSearchingNearbyPlaces) {
      searchResults = [];
      nearbySearchResults = [];
      isSearchingPlaces = false;
      isSearchingNearbyPlaces = false;
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
    nearbySearchResults = [];
    notifyListeners();
  }

  void exitNavigation() {
    clearRouteSelection();
    setSearchBarExpanded(false);
    requestUnfocusSearchBar();
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

    if (field == SearchField.destination && startCoordinate == null && place.coordinate != null) {
      await _applyCurrentLocationAsStart();
    }

    _applySelection(field: field, coordinate: coordinate, label: suggestion.title, campus: null);
    cameraTarget = coordinate;
    isSearchBarExpanded = true;
    clearSearchResults();
    requestUnfocusSearchBar();
    await _loadRoutesIfReady();
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
    if (selectedOption == null || selectedOption.durationSeconds == null) {
      return;
    }

    final durationSeconds = selectedOption.durationSeconds!;
    suggestedDepartureTime = selectedArrivalTime!.subtract(Duration(seconds: durationSeconds));
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

  /// Refreshes the currently displayed routes without changing origin/destination.
  Future<void> refreshRoutes() async {
    await _loadRoutesIfReady();
  }

  void onMapCameraMove(final CameraPosition position) {
    final zoom = position.zoom;
    if ((_currentMapZoom - zoom).abs() < 0.25) return;

    _currentMapZoom = zoom;

    final option = routeOptions[selectedRouteMode];
    if (selectedRouteMode != RouteMode.transit || option == null || option.steps.isEmpty) {
      return;
    }

    _updateRoutePolylines();
    routeBounds = null;
    notifyListeners();
  }

  double _transitChangeCircleRadiusMeters() {
    const minRadiusMeters = 5.0;
    const maxRadiusMeters = 600.0;
    const baseZoom = 16.5;
    const growthPerZoomOut = 2;

    final zoomDelta = (baseZoom - _currentMapZoom).clamp(0.0, 8.0);
    final scaled = minRadiusMeters * math.pow(growthPerZoomOut, zoomDelta).toDouble();

    return scaled.clamp(minRadiusMeters, maxRadiusMeters).toDouble();
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

    // Special handling for shuttle routes - show dashed walking and solid shuttle segments
    if (selectedRouteMode == RouteMode.shuttle && option.steps.isNotEmpty) {
      _updateShuttlePolylines(option);
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
      case RouteMode.transit:
        polylineColor = AppTheme.concordiaDarkBlue;
        polylineWidth = 5;
        polylinePattern = [PatternItem.dash(20), PatternItem.gap(10)]; // Dashed line for transit
        break;
      case RouteMode.shuttle:
        polylineColor = AppTheme.concordiaMaroon;
        polylineWidth = 5;
        polylinePattern = []; // Solid line
        break;
      default:
        throw StateError("Unsupported route mode: $selectedRouteMode");
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
    final transitionCircleRadius = _transitChangeCircleRadiusMeters();
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
        pattern = [PatternItem.dot, PatternItem.gap(10)]; // Dotted line for walking
      }

      // Check if travel mode changed - add circle at transition point
      if (previousTravelMode != null &&
          previousTravelMode != step.travelMode &&
          points.isNotEmpty) {
        circles.add(
          Circle(
            circleId: CircleId("transit-change-$segmentIndex"),
            center: points.first,
            radius: transitionCircleRadius,
            fillColor: const Color.fromARGB(223, 98, 106, 114).withValues(alpha: 0.8),
            strokeWidth: 3,
            strokeColor: const Color.fromARGB(223, 98, 106, 114),
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

  void _updateShuttlePolylines(final RouteOption option) {
    final polylines = <Polyline>{};
    final allPoints = <LatLng>[];
    int segmentIndex = 0;

    for (final step in option.steps) {
      if (step.polyline.isEmpty) continue;

      final points = step.polyline.map((final c) => c.toLatLng()).toList();
      allPoints.addAll(points);

      Color color;
      int width;
      List<PatternItem> pattern;

      // SHUTTLE segment
      if (step.travelMode == "SHUTTLE") {
        color = AppTheme.concordiaMaroon;
        width = 6;
        pattern = [];
      }
      // WALKING segment
      else {
        color = AppTheme.concordiaTurquoise;
        width = 4;
        pattern = [PatternItem.dot, PatternItem.gap(10)];
      }

      polylines.add(
        Polyline(
          polylineId: PolylineId("shuttle-segment-$segmentIndex"),
          points: points,
          color: color,
          width: width,
          patterns: pattern,
        ),
      );
      segmentIndex++;
    }

    routePolylines = polylines;
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

    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
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

  Future<List<PlaceSuggestion>> _searchNearbyPlaces(final String query) async {
    try {
      final origin = await LocationService.instance.getCurrentPosition();
      myLocationEnabled = true;
      return await placesInteractor.searchNearbyPlaces(
        query,
        origin,
        maxResults: nearbySearchResultLimit,
      );
    } catch (e) {
      logger.w("HomeViewModel: nearby place search failed", error: e);
      return [];
    }
  }

  Future<void> _applyCurrentLocationAsStart() async {
    final posCoord = await LocationService.instance.getCurrentPosition();
    _applySelection(
      field: SearchField.start,
      coordinate: posCoord,
      label: "Current location",
      campus: null,
    );
    myLocationEnabled = true;
  }

  Set<Marker> _nearbyResultMarkers() {
    return nearbySearchResults.where((final place) => place.coordinate != null).map((final place) {
      final coordinate = place.coordinate!;
      return Marker(
        markerId: MarkerId("nearby-${place.placeId}"),
        position: coordinate.toLatLng(),
        onTap: () async {
          await selectSearchSuggestion(SearchSuggestion.place(place), SearchField.destination);
        },
        infoWindow: InfoWindow(
          title: place.mainText,
          snippet: place.secondaryText.isNotEmpty ? place.secondaryText : null,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      );
    }).toSet();
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

  void notifyLoginSuccess() {
    _showLoginSuccessMessage = true;
    notifyListeners();
  }

  void clearLoginSuccessMessage() {
    _showLoginSuccessMessage = false;
    notifyListeners();
  }

  void toggleNextClassFabVisibility(final bool isVisible) {
    if (showNextClassFab != isVisible) {
      showNextClassFab = isVisible;
      notifyListeners();
    }
  }

  void clearNextClassDialog() {
    _showNextClassDialog = false;
    notifyListeners();
  }

  Building? _findBuildingById(final String buildingId) {
    final normalized = buildingId.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final directMatch =
        buildings[buildingId] ?? buildings[normalized] ?? buildings[normalized.toUpperCase()];
    if (directMatch != null) return directMatch;

    for (final building in buildings.values) {
      if (building.id.toLowerCase() == normalized) {
        return building;
      }
    }

    return null;
  }

  Future<void> setDestinationToUpcomingClassBuilding() async {
    setSearchBarExpanded(true);
    await setStartToCurrentLocation();
    if (startCoordinate == null) {
      generateInfoMessage = "Unable to determine current location for navigation start.";
      notifyListeners();
      return;
    }

    final upcoming = upcomingClass;
    if (upcoming == null) {
      generateInfoMessage = "No upcoming class selected.";
      notifyListeners();
      return;
    }

    final buildingId = upcoming.room.buildingId;
    final building = _findBuildingById(buildingId);
    if (building != null) {
      _applySelection(
        field: SearchField.destination,
        coordinate: building.location,
        label: building.name,
        campus: building.campus,
      );
      cameraTarget = building.location;
      await _loadRoutesIfReady();
      notifyListeners();
      return;
    }

    final query = buildingId.trim();
    final suggestions = await placesInteractor.searchPlaces(query);

    if (suggestions.isNotEmpty) {
      final firstSuggestion = suggestions.first;
      final coordinate = await placesInteractor.resolvePlaceSuggestion(firstSuggestion);
      if (coordinate != null) {
        final label = SearchSuggestion.place(firstSuggestion).title;
        _applySelection(
          field: SearchField.destination,
          coordinate: coordinate,
          label: label,
          campus: null,
        );
        cameraTarget = coordinate;
        await _loadRoutesIfReady();
        notifyListeners();
        return;
      }
    }

    generateInfoMessage = "Unable to find ${buildingId.toUpperCase()} on the map.";
    notifyListeners();
  }

  Future<void> showNextClass() async {
    // To prevent unnecessary API calls and improve prefomance
    if (upcomingClass != null && upcomingClass!.startTime.isAfter(DateTime.now())) {
      _showNextClassDialog = true;
      notifyListeners();
      return;
    }

    try {
      // Acceptance Criteria: Only show classes that are upcoming today
      final now = DateTime.now();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final classes = await calendarInteractor.getUpcomingClasses(
        timeMin: now,
        timeMax: endOfDay,
        maxResults: 100,
      );

      if (classes.isEmpty) {
        generateInfoMessage = "No more classes today.";
        notifyListeners();
        return;
      }

      upcomingClass = classes.first;
      _showNextClassDialog = true;
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e("Failed to fetch calendar events", error: e, stackTrace: stackTrace);
      final errorMessageText = e.toString();
      generateInfoMessage = "$errorMessageText. Please use search to find your destination.";
      notifyListeners();
    }
  }

  void clearUpcomingClass() {
    upcomingClass = null;
    _showNextClassDialog = false;
    notifyListeners();
  }
}
