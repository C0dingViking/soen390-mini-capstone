import "package:flutter_test/flutter_test.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";

import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/coordinate_extensions.dart";

void main() {
  group("Coordinate and LatLng extensions", () {
    test("Coordinate.toLatLng converts correctly", () {
      const c = Coordinate(latitude: 45.5019, longitude: -73.5674);

      final latLng = c.toLatLng();

      expect(latLng.latitude, 45.5019);
      expect(latLng.longitude, -73.5674);
    });

    test("LatLng.toCoordinate converts correctly", () {
      const latLng = LatLng(45.5019, -73.5674);

      final c = latLng.toCoordinate();

      expect(c.latitude, 45.5019);
      expect(c.longitude, -73.5674);
    });

    test("coordinate to LatLng to coordinate conversion preserves values", () {
      const original = Coordinate(latitude: -12.345678, longitude: 98.765432);

      final roundTrip = original.toLatLng().toCoordinate();

      expect(roundTrip.latitude, original.latitude);
      expect(roundTrip.longitude, original.longitude);
    });

    group("PointInPolygon.isInPolygon ray-casting algorithm", () {
      test("returns false for empty polygon", () {
        const point = Coordinate(latitude: 45.0, longitude: -73.0);
        const emptyPolygon = <Coordinate>[];

        expect(point.isInPolygon(emptyPolygon), isFalse);
      });

      test("returns true for point inside square polygon", () {
        const point = Coordinate(latitude: 45.5, longitude: -73.5);
        const polygon = [
          Coordinate(latitude: 45.0, longitude: -74.0),
          Coordinate(latitude: 46.0, longitude: -74.0),
          Coordinate(latitude: 46.0, longitude: -73.0),
          Coordinate(latitude: 45.0, longitude: -73.0),
        ];

        expect(point.isInPolygon(polygon), isTrue);
      });

      test("returns false for point outside square polygon", () {
        const point = Coordinate(latitude: 44.5, longitude: -73.5);
        const polygon = [
          Coordinate(latitude: 45.0, longitude: -74.0),
          Coordinate(latitude: 46.0, longitude: -74.0),
          Coordinate(latitude: 46.0, longitude: -73.0),
          Coordinate(latitude: 45.0, longitude: -73.0),
        ];

        expect(point.isInPolygon(polygon), isFalse);
      });

      test("returns true for point on polygon boundary (edge)", () {
        const point = Coordinate(latitude: 45.0, longitude: -73.5);
        const polygon = [
          Coordinate(latitude: 45.0, longitude: -74.0),
          Coordinate(latitude: 46.0, longitude: -74.0),
          Coordinate(latitude: 46.0, longitude: -73.0),
          Coordinate(latitude: 45.0, longitude: -73.0),
        ];

        expect(point.isInPolygon(polygon), isTrue);
      });

      test("returns true for point inside triangle polygon", () {
        const point = Coordinate(latitude: 45.5, longitude: -73.5);
        const polygon = [
          Coordinate(latitude: 45.0, longitude: -74.0),
          Coordinate(latitude: 46.0, longitude: -74.0),
          Coordinate(latitude: 45.5, longitude: -73.0),
        ];

        expect(point.isInPolygon(polygon), isTrue);
      });

      test("returns false for point outside triangle polygon", () {
        const point = Coordinate(latitude: 44.5, longitude: -73.0);
        const polygon = [
          Coordinate(latitude: 45.0, longitude: -74.0),
          Coordinate(latitude: 46.0, longitude: -74.0),
          Coordinate(latitude: 45.5, longitude: -73.0),
        ];

        expect(point.isInPolygon(polygon), isFalse);
      });

      test("handles polygon with many vertices correctly", () {
        const point = Coordinate(latitude: 45.5, longitude: -73.5);
        const polygon = [
          Coordinate(latitude: 45.0, longitude: -74.0),
          Coordinate(latitude: 45.5, longitude: -74.5),
          Coordinate(latitude: 46.0, longitude: -74.0),
          Coordinate(latitude: 46.0, longitude: -73.0),
          Coordinate(latitude: 45.5, longitude: -72.5),
          Coordinate(latitude: 45.0, longitude: -73.0),
        ];

        expect(point.isInPolygon(polygon), isTrue);
      });
    });
  });
}
