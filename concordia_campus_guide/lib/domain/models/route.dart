import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/building.dart";

class DirectionRoute {  
  final Coordinate startCoordinate;
  final Building destinationBuilding;
  final double? estimatedDistance;

  DirectionRoute({
    required this.startCoordinate,
    required this.destinationBuilding,
    this.estimatedDistance,
  });
}