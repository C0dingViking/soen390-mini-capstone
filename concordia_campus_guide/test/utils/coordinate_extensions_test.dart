import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:concordia_campus_guide/domain/models/coordinate.dart';
import 'package:concordia_campus_guide/utils/coordinate_extensions.dart';

void main() {
  group('Coordinate and LatLng extensions', () {
    test('Coordinate.toLatLng converts correctly', () {
      const c = Coordinate(latitude: 45.5019, longitude: -73.5674);

      final latLng = c.toLatLng();

      expect(latLng.latitude, 45.5019);
      expect(latLng.longitude, -73.5674);
    });

    test('LatLng.toCoordinate converts correctly', () {
      const latLng = LatLng(45.5019, -73.5674);

      final c = latLng.toCoordinate();

      expect(c.latitude, 45.5019);
      expect(c.longitude, -73.5674);
    });

    test('coordinate to LatLng to coordinate conversion preserves values', () {
      const original = Coordinate(latitude: -12.345678, longitude: 98.765432);

      final roundTrip = original.toLatLng().toCoordinate();

      expect(roundTrip.latitude, original.latitude);
      expect(roundTrip.longitude, original.longitude);
    });
  });
}