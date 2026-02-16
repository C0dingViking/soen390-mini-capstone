import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/utils/polyline_decoder.dart";

void main() {
  group("decodePolyline", () {
    test("returns empty list for empty string", () {
      final result = decodePolyline("");

      expect(result, isEmpty);
    });

    test("decodes single point correctly", () {
      // Encoded polyline for a single point at approximately (38.5, -120.2)
      const encoded = "_p~iF~ps|U";
      final result = decodePolyline(encoded);

      expect(result.length, 1);
      expect(result[0].latitude, closeTo(38.5, 0.1));
      expect(result[0].longitude, closeTo(-120.2, 0.1));
    });

    test("decodes multiple points correctly", () {
      // Well-known encoded polyline with 3 points
      const encoded = "_p~iF~ps|U_ulLnnqC_mqNvxq`@";
      final result = decodePolyline(encoded);

      expect(result.length, 3);

      // First point approximately (38.5, -120.2)
      expect(result[0].latitude, closeTo(38.5, 0.1));
      expect(result[0].longitude, closeTo(-120.2, 0.1));

      // Second point approximately (40.7, -120.95)
      expect(result[1].latitude, closeTo(40.7, 0.1));
      expect(result[1].longitude, closeTo(-120.95, 0.1));

      // Third point approximately (43.252, -126.453)
      expect(result[2].latitude, closeTo(43.25, 0.1));
      expect(result[2].longitude, closeTo(-126.45, 0.1));
    });

    test("decodes straight line between two points", () {
      // Encoded polyline for two points forming a straight line
      const encoded = "gfo}EtbdwGq@mA";
      final result = decodePolyline(encoded);

      expect(result.length, 2);
      expect(result[0].latitude, isPositive);
      expect(result[0].longitude, isNegative);
      expect(result[1].latitude, greaterThan(result[0].latitude));
    });

    test("decodes polyline with precise coordinates", () {
      // Polyline representing Montreal area coordinates
      // Point 1: approximately (44.5, -73.6), Point 2: offset by small delta
      const encoded = "kcxnGriqbMmBwC";
      final result = decodePolyline(encoded);

      expect(result.length, 2);
      // Verify both points are in reasonable coordinate range
      expect(result[0].latitude, closeTo(44.5, 1.0));
      expect(result[0].longitude, closeTo(-73.6, 1.0));
      expect(result[1].latitude, closeTo(44.5, 1.0));
      expect(result[1].longitude, closeTo(-73.6, 1.0));
    });

    test("handles negative latitude and longitude deltas", () {
      // Encoded polyline where subsequent points move south and west
      const encoded = "gfo}EtbdwG~@~A";
      final result = decodePolyline(encoded);

      expect(result.length, 2);
      // Second point should be south and west of first
      expect(result[1].latitude, lessThan(result[0].latitude));
      expect(result[1].longitude, lessThan(result[0].longitude));
    });

    test("handles positive latitude and longitude deltas", () {
      // Encoded polyline where subsequent points move north and east
      const encoded = "gfo}EtbdwGq@mA";
      final result = decodePolyline(encoded);

      expect(result.length, 2);
      // Second point should be north and east of first
      expect(result[1].latitude, greaterThan(result[0].latitude));
      expect(result[1].longitude, greaterThan(result[0].longitude));
    });

    test("decodes complex polyline with many points", () {
      // Polyline with 5+ points representing a route
      const encoded = "gfo}EtbdwGq@mA}@aBo@gAc@w@_@s@";
      final result = decodePolyline(encoded);

      expect(result.length, greaterThan(4));
      // All points should be valid coordinates
      for (final coord in result) {
        expect(coord.latitude, inInclusiveRange(-90, 90));
        expect(coord.longitude, inInclusiveRange(-180, 180));
      }
    });

    test("maintains coordinate precision to 5 decimal places", () {
      // Test that decoding maintains the precision of encoded coordinates
      const encoded = "_p~iF~ps|U";
      final result = decodePolyline(encoded);

      expect(result.length, 1);
      // Verify precision is maintained (Google polylines encode to 1e-5 precision)
      final lat = result[0].latitude;
      final lng = result[0].longitude;

      // Coordinates should have meaningful decimal places
      expect((lat * 100000).round() / 100000, equals(lat));
      expect((lng * 100000).round() / 100000, equals(lng));
    });

    test("decodes polyline with zero deltas (repeated points)", () {
      // When delta is zero, the point repeats
      // This tests the bitwise operations with zero values
      const encoded = "gfo}EtbdwG??";
      final result = decodePolyline(encoded);

      expect(result.length, 2);
      // Both points should be equal when delta is zero
      expect(result[0].latitude, equals(result[1].latitude));
      expect(result[0].longitude, equals(result[1].longitude));
    });

    test("handles characters at boundary values correctly", () {
      // Test with encoded string using characters near boundary (63 offset)
      const encoded = "?_p~iF?~ps|U";
      final result = decodePolyline(encoded);

      // Should decode without errors
      expect(result, isNotEmpty);
      for (final coord in result) {
        expect(coord.latitude, inInclusiveRange(-90, 90));
        expect(coord.longitude, inInclusiveRange(-180, 180));
      }
    });

    test("decodes route with sharp turns", () {
      // Polyline representing a route with direction changes
      const encoded = "gfo}EtbdwGq@mA~@~A_@s@~@~A";
      final result = decodePolyline(encoded);

      expect(result.length, greaterThan(2));
      // Verify coordinates are valid
      for (final coord in result) {
        expect(coord.latitude, inInclusiveRange(-90, 90));
        expect(coord.longitude, inInclusiveRange(-180, 180));
      }
    });

    test("decodes very long polyline efficiently", () {
      // Create a longer encoded polyline
      const encoded = "gfo}EtbdwGq@mA}@aBo@gAc@w@_@s@YkA]o@We@Uc@Sa@Qa@O_@M]K]";
      final result = decodePolyline(encoded);

      expect(result.length, greaterThan(10));
      // All coordinates should be valid
      for (final coord in result) {
        expect(coord.latitude, inInclusiveRange(-90, 90));
        expect(coord.longitude, inInclusiveRange(-180, 180));
      }
    });

    test("accumulates latitude and longitude correctly across points", () {
      // Test that cumulative additions work correctly
      const encoded = "gfo}EtbdwGq@mA}@aB";
      final result = decodePolyline(encoded);

      expect(result.length, 3);
      // Each subsequent point should be derived from accumulated deltas
      expect(result[0].latitude, isPositive);
      expect(result[1].latitude, greaterThanOrEqualTo(result[0].latitude));
      expect(result[2].latitude, greaterThanOrEqualTo(result[1].latitude));
    });

    test("handles encoded string with all positive deltas", () {
      const encoded = "gfo}EtbdwGqGmKoFiJ";
      final result = decodePolyline(encoded);

      expect(result.length, 3);
      // With all positive deltas, coordinates should increase
      expect(result[1].latitude, greaterThan(result[0].latitude));
      expect(result[1].longitude, greaterThan(result[0].longitude));
      expect(result[2].latitude, greaterThan(result[1].latitude));
      expect(result[2].longitude, greaterThan(result[1].longitude));
    });

    test("handles encoded string with all negative deltas", () {
      const encoded = "gfo}EtbdwG~F~J~E~I";
      final result = decodePolyline(encoded);

      expect(result.length, 3);
      // With all negative deltas, coordinates should decrease
      expect(result[1].latitude, lessThan(result[0].latitude));
      expect(result[1].longitude, lessThan(result[0].longitude));
      expect(result[2].latitude, lessThan(result[1].latitude));
      expect(result[2].longitude, lessThan(result[1].longitude));
    });

    test("correctly applies bitwise operations for encoding chunks", () {
      // Test a known encoded value to verify bit manipulation
      const encoded = "_p~iF~ps|U";
      final result = decodePolyline(encoded);

      expect(result.length, 1);
      // Verify the decoded value matches expected coordinates
      // '_p~iF' encodes to latitude around 38.5
      // '~ps|U' encodes to longitude around -120.2
      expect(result[0].latitude, closeTo(38.5, 0.01));
      expect(result[0].longitude, closeTo(-120.2, 0.01));
    });

    test("correctly handles coordinate scale conversion from 1e5", () {
      // The algorithm divides by 1e5, so test that scaling is correct
      const encoded = "_p~iF~ps|U";
      final result = decodePolyline(encoded);

      expect(result.length, 1);
      // Latitude should be properly scaled (original value was multiplied by 1e5)
      final scaledLat = (result[0].latitude * 1e5).round();
      expect(scaledLat, isNonZero);
      expect(result[0].latitude, inInclusiveRange(-90, 90));
    });
  });
}
