import 'package:flutter_test/flutter_test.dart';
import 'package:concordia_campus_guide/domain/models/building.dart';
import 'package:concordia_campus_guide/domain/models/coordinate.dart';
import 'package:concordia_campus_guide/utils/campus.dart';

void main() {
  group('Building bbox', () {
    test('computeOutlineBBox uses location for empty outline', () {
      final b = Building(
        id: 'b1',
        name: 'Test',
        street: '1 Test St',
        postalCode: 'H0H0H0',
        location: const Coordinate(latitude: 10.0, longitude: 20.0),
        campus: Campus.sgw,
        outlinePoints: const [],
      );

      b.computeOutlineBBox();

      expect(b.minLatitude, equals(10.0));
      expect(b.maxLatitude, equals(10.0));
      expect(b.minLongitude, equals(20.0));
      expect(b.maxLongitude, equals(20.0));
    });

    test('computeOutlineBBox computes correct min/max for multiple points', () {
      final b = Building(
        id: 'b2',
        name: 'Poly',
        street: '2 Poly Ln',
        postalCode: 'H0H0H0',
        location: const Coordinate(latitude: 0.0, longitude: 0.0),
        campus: Campus.sgw,
        outlinePoints: [
          const Coordinate(latitude: 1.0, longitude: 2.0),
          const Coordinate(latitude: -1.5, longitude: 3.0),
          const Coordinate(latitude: 0.5, longitude: -2.0),
        ],
      );

      b.computeOutlineBBox();

      expect(b.minLatitude, equals(-1.5));
      expect(b.maxLatitude, equals(1.0));
      expect(b.minLongitude, equals(-2.0));
      expect(b.maxLongitude, equals(3.0));
    });

    test('isInsideBBox returns true for inside point and false for outside', () {
      final b = Building(
        id: 'b3',
        name: 'Box',
        street: '3 Box Rd',
        postalCode: 'H0H0H0',
        location: const Coordinate(latitude: 0.0, longitude: 0.0),
        campus: Campus.sgw,
        outlinePoints: [
          const Coordinate(latitude: 1.0, longitude: 1.0),
          const Coordinate(latitude: 1.0, longitude: -1.0),
          const Coordinate(latitude: -1.0, longitude: -1.0),
          const Coordinate(latitude: -1.0, longitude: 1.0),
        ],
      );

      b.computeOutlineBBox();

      expect(b.isInsideBBox(const Coordinate(latitude: 0.0, longitude: 0.0)), isTrue);
      expect(b.isInsideBBox(const Coordinate(latitude: 2.0, longitude: 0.0)), isFalse);
      // point on edge: considered inside by bbox
      expect(b.isInsideBBox(const Coordinate(latitude: 1.0, longitude: 0.0)), isTrue);
    });
  });
}
