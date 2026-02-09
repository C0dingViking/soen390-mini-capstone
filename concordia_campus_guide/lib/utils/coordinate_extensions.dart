import "package:google_maps_flutter/google_maps_flutter.dart";
import "../domain/models/coordinate.dart";

// Extensions to convert between LatLng and Coordinate

extension LatLngToCoordinate on LatLng {
  Coordinate toCoordinate() {
    return Coordinate(
      latitude: latitude,
      longitude: longitude,
    );
  }
}

extension CoordinateToLatLng on Coordinate {
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}

// Ray-casting algorithm to determine if a point is inside a polygon.)
extension PointInPolygon on Coordinate {
  bool isInPolygon(final List<Coordinate> polygon) {
    if (polygon.isEmpty) return false;

    final double x = longitude; // treat longitude as x
    final double y = latitude; // treat latitude as y

    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;

      final bool intersect = ((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }

    return inside;
  }
}

// Provides approximate-equality comparison for coordinates.
extension CoordinateApproxEqual on Coordinate {
  bool isApproximatelyEqual(final Coordinate other, {final double eps = 1e-6}) {
    return (latitude - other.latitude).abs() < eps && (longitude - other.longitude).abs() < eps;
  }
}
