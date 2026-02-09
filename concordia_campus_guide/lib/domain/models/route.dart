import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/building.dart";

class DirectionRoute {  
  final Coordinate startCoordinate;
  final Building destinationBuilding;
  
  double get estimatedDistanceMeters =>
    _calculateDistance(startCoordinate, destinationBuilding.coordinate);

  // Since all the fields/attributes are final, DirectedRoute is immutable so we can use a const constructor. 
  // Provides benefits such as improved performance, reduced memory usage and enhanced safety 
  // (more information at https://medium.com/@maliaishu1794/const-constructors-in-dart-97d7b543beb3)
  const DirectionRoute({
    required this.startCoordinate,
    required this.destinationBuilding,
  });
}
