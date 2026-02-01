class Coordinate {
  final double latitude;
  final double longitude;

  const Coordinate({required this.latitude, required this.longitude}): 
  assert(latitude >= -90 && latitude <= 90,
            'Latitude must be between -90 and 90'),
        assert(longitude >= -180 && longitude <= 180,
            'Longitude must be between -180 and 180');

  @override
  String toString() => 'Coordinate(latitude: $latitude, longitude: $longitude)';
}