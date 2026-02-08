import "dart:math";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/route.dart";

class RouteInteractor {
  DirectionRoute createOutdoorRoute(  
    Coordinate currentCoordinate,
    Building destination,
  ) {
    final distance = _calculateDistance(currentCoordinate, destination.location);
    
    return DirectionRoute(  
      startCoordinate: currentCoordinate,
      destinationBuilding: destination,
      estimatedDistance: distance,
    );
  }

  double _calculateDistance(Coordinate start, Coordinate end) {
    const double earthRadius = 6371000;
    
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLat = (end.latitude - start.latitude) * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}