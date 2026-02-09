import "dart:math";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/route.dart";

class RouteInteractor {
  DirectionRoute createOutdoorRoute(  
    final Coordinate currentCoordinate,
    final Building destination,
  ) {
    final distance = _calculateDistance(currentCoordinate, destination.location);
    
    return DirectionRoute(  
      startCoordinate: currentCoordinate,
      destinationBuilding: destination,
      estimatedDistanceMeters: distance,
    );
  }

  /// Haversine Formula reference: https://en.wikipedia.org/wiki/Haversine_formula
  /// Additional explanation: https://www.movable-type.co.uk/scripts/latlong.html
  /// /// Use cases:
  /// - Calculating distances between geographic locations (cities, addresses, GPS coordinates)
  /// - Finding nearby points of interest within a certain radius
  /// - Navigation and mapping applications
  /// - Geofencing and location-based services
  double _calculateDistance(final Coordinate start, final Coordinate end) {
    const double earthRadiusInMeters = 6371000;
    /// Earth's mean radius in meters.
    /// Source: https://en.wikipedia.org/wiki/Earth_radius#Mean_radius
    /// 
    final startLatitudeRad = start.latitude * pi / 180;
    final endLatitudeRad  = end.latitude * pi / 180;
    final deltaLatitudeRad  = (end.latitude - start.latitude) * pi / 180;
    final deltaLongitudeRad  = (end.longitude - start.longitude) * pi / 180;

    final haversineValue  = sin(deltaLatitudeRad  / 2) * sin(deltaLatitudeRad  / 2) +
        cos(startLatitudeRad) * cos(endLatitudeRad ) * sin(deltaLongitudeRad  / 2) * sin(deltaLongitudeRad  / 2);
    final centralAngle  = 2 * atan2(sqrt(haversineValue ), sqrt(1 - haversineValue ));

    return earthRadiusInMeters * centralAngle ;
  }
}
