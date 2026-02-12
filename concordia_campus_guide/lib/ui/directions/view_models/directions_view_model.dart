
import "package:flutter/material.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/route.dart";  
import "package:concordia_campus_guide/domain/interactors/route_interactor.dart";
import "package:concordia_campus_guide/data/services/location_service.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";

class DirectionsViewModel extends ChangeNotifier {
  final RouteInteractor routeInteractor;

  DirectionsViewModel({required this.routeInteractor});

  Coordinate? currentLocationCoordinate;
  Building? startBuilding;
  Building? destinationBuilding;
  DirectionRoute? plannedRoute; 
  
  bool isLoadingLocation = false;
  String? errorMessage;

  void initializeFromBuildings(Building? start, Building? dest) {
    if (start != null) {
      startBuilding = start;
    }
    if (dest != null) {
      destinationBuilding = dest;
    }

    _updateRoute();
    notifyListeners();
  }

  void updateDestination(final Building building) {
    destinationBuilding = building;
    _updateRoute();
    notifyListeners();
  }

  Future<void> useCurrentLocation() async {
    isLoadingLocation = true;
    errorMessage = null;
    notifyListeners();

    try {
      final coordinate = await LocationService.instance.getCurrentPosition();
      startBuilding = null;
      currentLocationCoordinate = coordinate;
      _updateRoute();
    } catch (e) {
      errorMessage = "Unable to get current location: $e";
      logger.e("DirectionViewModel: Error fetching location", error: errorMessage);
    } finally {
      isLoadingLocation = false;
      notifyListeners();
    }
  }

  void _updateRoute() {
    final start = startBuilding?.location ?? currentLocationCoordinate;
    if (start != null && destinationBuilding != null) {
      plannedRoute = routeInteractor.createOutdoorRoute(
        start,
        destinationBuilding!,
      );
    } else {
      plannedRoute = null;
    }
  }

  void clearStartLocation() {
    currentLocationCoordinate = null;
    plannedRoute = null;
    notifyListeners();
  }

  bool get canGetDirections =>
      (currentLocationCoordinate != null || startBuilding != null) && destinationBuilding != null;

  void setStartBuilding(final Building building) {
    startBuilding = building;
    currentLocationCoordinate = null;
    _updateRoute();
    notifyListeners();
  }
}
