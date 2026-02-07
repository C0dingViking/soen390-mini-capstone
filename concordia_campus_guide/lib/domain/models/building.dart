import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/campus.dart";

class Building {
  final String id;
  final String name;
  final String street;
  final String postalCode;
  final Coordinate location;
  final Campus campus;
  List<Coordinate> outlinePoints;
  double? minLatitude;
  double? maxLatitude;
  double? minLongitude;
  double? maxLongitude;

  Building({
    required this.id,
    required this.name,
    required this.street,
    required this.postalCode,
    required this.location,
    required this.campus,
    required this.outlinePoints,
  });

  /// Precompute axis-aligned bounding box for outlinePoints. Call after
  /// constructing or when `outlinePoints` changes.
  void computeOutlineBBox() {
    if (outlinePoints.isEmpty) {
      minLatitude = maxLatitude = location.latitude;
      minLongitude = maxLongitude = location.longitude;
      return;
    }

    double minLat = outlinePoints[0].latitude;
    double maxLat = outlinePoints[0].latitude;
    double minLon = outlinePoints[0].longitude;
    double maxLon = outlinePoints[0].longitude;

    for (final p in outlinePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    minLatitude = minLat;
    maxLatitude = maxLat;
    minLongitude = minLon;
    maxLongitude = maxLon;
  }

  /// Fast axis-aligned bbox check; returns true if [c] is inside the bbox.
  bool isInsideBBox(final Coordinate c) {
    if (minLatitude == null || maxLatitude == null || minLongitude == null || maxLongitude == null) {
      computeOutlineBBox();
    }
    return c.latitude >= (minLatitude ?? double.negativeInfinity) &&
           c.latitude <= (maxLatitude ?? double.infinity) &&
           c.longitude >= (minLongitude ?? double.negativeInfinity) &&
           c.longitude <= (maxLongitude ?? double.infinity);
  }

  String get address => "$street, Montreal, QC $postalCode, Canada";

  @override
  String toString() => "$id: ($name - $address at ${location.toString()})";
}
