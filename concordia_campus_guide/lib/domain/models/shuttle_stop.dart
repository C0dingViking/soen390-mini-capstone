import "package:concordia_campus_guide/domain/models/coordinate.dart";

class ShuttleStop {
  final String id;
  final String name;
  final Coordinate location;
  final String campusId;

  const ShuttleStop({
    required this.id,
    required this.name,
    required this.location,
    required this.campusId,
  });
}

const sgwShuttleStop = ShuttleStop(
  id: "sgw-shuttle",
  name: "SGW Shuttle Stop",
  location: Coordinate(latitude: 45.497, longitude: -73.579),
  campusId: "sgw",
);

const loyolaShuttleStop = ShuttleStop(
  id: "loyola-shuttle",
  name: "Loyola Shuttle Stop",
  location: Coordinate(latitude: 45.458, longitude: -73.641),
  campusId: "loyola",
);
