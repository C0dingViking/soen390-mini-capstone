import 'package:flutter_test/flutter_test.dart';
import 'package:concordia_campus_guide/controllers/coordinates_controller.dart';
import 'package:concordia_campus_guide/utils/coordinate_extensions.dart';

void main() {
  group('CoordinatesController', () {
    test('SGW constant stores expected values', () {
      final c = CoordinatesController.sgw;
      expect(c.latitude, 45.4972);
      expect(c.longitude, -73.5786);
    });

    test('Loyola constant stores expected values', () {
      final c = CoordinatesController.loyola;
      expect(c.latitude, 45.45823348665408);
      expect(c.longitude, -73.64067095332564);
    });

    test('SGW toLatLng conversion', () {
      final latLng = CoordinatesController.sgw.toLatLng();
      expect(latLng.latitude, 45.4972);
      expect(latLng.longitude, -73.5786);
    });

    test('Loyola toLatLng conversion', () {
      final latLng = CoordinatesController.loyola.toLatLng();
      expect(latLng.latitude, 45.45823348665408);
      expect(latLng.longitude, -73.64067095332564);
    });
  });
}