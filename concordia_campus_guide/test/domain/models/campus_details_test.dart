import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:concordia_campus_guide/domain/models/campus_details.dart';
import 'package:concordia_campus_guide/domain/models/coordinate.dart';

void main() {
  group('CampusDetails', () {
    test('stores name, coordinate and icon correctly', () {
      const cd = CampusDetails(
        name: 'SGW',
        coord: Coordinate(latitude: 45.4972, longitude: -73.5786),
        icon: Icons.location_city,
      );

      expect(cd.name, 'SGW');
      expect(cd.coord.latitude, 45.4972);
      expect(cd.coord.longitude, -73.5786);
      expect(cd.icon, Icons.location_city);
    });

    test('const instances with identical values are identical', () {
      const a = CampusDetails(
        name: 'SGW',
        coord: Coordinate(latitude: 45.4972, longitude: -73.5786),
        icon: Icons.location_city,
      );
      const b = CampusDetails(
        name: 'SGW',
        coord: Coordinate(latitude: 45.4972, longitude: -73.5786),
        icon: Icons.location_city,
      );

      expect(identical(a, b), isTrue);
    });
  });
}