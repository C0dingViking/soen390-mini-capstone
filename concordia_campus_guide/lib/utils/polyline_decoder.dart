import "package:concordia_campus_guide/domain/models/coordinate.dart";

List<Coordinate> decodePolyline(final String encoded) {
  final List<Coordinate> points = [];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int result = 0;
    int shift = 0;
    int encodedByte;
    do {
      encodedByte = encoded.codeUnitAt(index++) - 63;
      result |= (encodedByte & 0x1f) << shift;
      shift += 5;
    } while (encodedByte>= 0x20);
    final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += deltaLat;

    result = 0;
    shift = 0;
    do {
      encodedByte = encoded.codeUnitAt(index++) - 63;
      result |= (encodedByte & 0x1f) << shift;
      shift += 5;
    } while (encodedByte >= 0x20);
    final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += deltaLng;

    points.add(
      Coordinate(
        latitude: lat / 1e5,
        longitude: lng / 1e5,
      ),
    );
  }

  return points;
}
