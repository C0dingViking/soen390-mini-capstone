import "package:concordia_campus_guide/domain/converters/coordinate_converter.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("CoordinateConverter", () {
    const converter = CoordinateConverter();

    group("fromJson", () {
      test("converts list of two numbers to Coordinate", () {
        final result = converter.fromJson([45.5, -73.6]);
        expect(result.latitude, equals(45.5));
        expect(result.longitude, equals(-73.6));
      });

      test("converts list with integers to Coordinate with doubles", () {
        final result = converter.fromJson([45, -73]);
        expect(result.latitude, equals(45.0));
        expect(result.longitude, equals(-73.0));
      });

      test("handles negative coordinates", () {
        final result = converter.fromJson([-45.5, -73.6]);
        expect(result.latitude, equals(-45.5));
        expect(result.longitude, equals(-73.6));
      });

      test("handles zero coordinates", () {
        final result = converter.fromJson([0, 0]);
        expect(result.latitude, equals(0.0));
        expect(result.longitude, equals(0.0));
      });
    });

    group("toJson", () {
      test("converts Coordinate to list of two numbers", () {
        const coordinate = Coordinate(latitude: 45.5, longitude: -73.6);
        final result = converter.toJson(coordinate);
        expect(result, equals([45.5, -73.6]));
      });

      test("converts Coordinate with negative values to list", () {
        const coordinate = Coordinate(latitude: -45.5, longitude: -73.6);
        final result = converter.toJson(coordinate);
        expect(result, equals([-45.5, -73.6]));
      });

      test("converts Coordinate with zero values to list", () {
        const coordinate = Coordinate(latitude: 0.0, longitude: 0.0);
        final result = converter.toJson(coordinate);
        expect(result, equals([0.0, 0.0]));
      });
    });
  });

  group("CoordinateListConverter", () {
    const converter = CoordinateListConverter();

    group("fromJson", () {
      test("converts list of coordinate arrays to list of Coordinates", () {
        final result = converter.fromJson([
          [45.5, -73.6],
          [45.6, -73.7],
          [45.7, -73.8],
        ]);

        expect(result, hasLength(3));
        expect(result[0].latitude, equals(45.5));
        expect(result[0].longitude, equals(-73.6));
        expect(result[1].latitude, equals(45.6));
        expect(result[1].longitude, equals(-73.7));
        expect(result[2].latitude, equals(45.7));
        expect(result[2].longitude, equals(-73.8));
      });

      test("converts empty list to empty coordinate list", () {
        final result = converter.fromJson([]);
        expect(result, isEmpty);
      });

      test("handles single coordinate in list", () {
        final result = converter.fromJson([
          [45.5, -73.6],
        ]);

        expect(result, hasLength(1));
        expect(result[0].latitude, equals(45.5));
        expect(result[0].longitude, equals(-73.6));
      });
    });

    group("toJson", () {
      test("converts list of Coordinates to list of coordinate arrays", () {
        const coordinates = [
          Coordinate(latitude: 45.5, longitude: -73.6),
          Coordinate(latitude: 45.6, longitude: -73.7),
          Coordinate(latitude: 45.7, longitude: -73.8),
        ];

        final result = converter.toJson(coordinates);

        expect(result, hasLength(3));
        expect(result[0], equals([45.5, -73.6]));
        expect(result[1], equals([45.6, -73.7]));
        expect(result[2], equals([45.7, -73.8]));
      });

      test("converts empty list to empty array", () {
        const coordinates = <Coordinate>[];
        final result = converter.toJson(coordinates);
        expect(result, isEmpty);
      });

      test("handles single coordinate in list", () {
        const coordinates = [Coordinate(latitude: 45.5, longitude: -73.6)];

        final result = converter.toJson(coordinates);

        expect(result, hasLength(1));
        expect(result[0], equals([45.5, -73.6]));
      });
    });
  });
}
