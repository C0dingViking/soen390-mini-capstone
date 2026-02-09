import "package:flutter/material.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/route.dart";  
import "package:concordia_campus_guide/domain/interactors/route_interactor.dart";
import "package:concordia_campus_guide/data/services/location_service.dart";

class DirectionsViewModel extends ChangeNotifier {
  final RouteInteractor routeInteractor;

  DirectionsViewModel({required this.routeInteractor});

  Coordinate? currentLocationCoordinate;
  Building? destinationBuilding;
  DirectionRoute? plannedRoute; 
  
  bool isLoadingLocation = false;
  String? errorMessage;

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
      currentLocationCoordinate = coordinate;
      _updateRoute();
    } catch (e) {
      errorMessage = "Unable to get current location: $e";
    } finally {
      isLoadingLocation = false;
      notifyListeners();
    }
  }

  void _updateRoute() {
    if (currentLocationCoordinate != null && destinationBuilding != null) {
      plannedRoute = routeInteractor.createOutdoorRoute(
        currentLocationCoordinate!,
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
      currentLocationCoordinate != null && destinationBuilding != null;
}