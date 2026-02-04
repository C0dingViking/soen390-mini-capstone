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
