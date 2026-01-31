class Coordinate {
  final double latitude;
  final double longitude;

  const Coordinate({required this.latitude, required this.longitude});

  @override
  String toString() => 'Coordinate(latitude: $latitude, longitude: $longitude)';
}