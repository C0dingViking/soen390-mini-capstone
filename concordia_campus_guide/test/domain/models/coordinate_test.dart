import 'package:flutter_test/flutter_test.dart';
import 'package:concordia_campus_guide/domain/models/coordinate.dart';

void main() {
  group('Coordinate', () {
    test('stores latitude and longitude', () {
      const c = Coordinate(latitude: 45.5, longitude: -73.6);

      expect(c.latitude, 45.5);
      expect(c.longitude, -73.6);
    });

    test('rejects invalid ranges (if you used asserts)', () {
      expect(
        () => Coordinate(latitude: 100, longitude: 0),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => Coordinate(latitude: 0, longitude: 200),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}