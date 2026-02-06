import "dart:async";
import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:geolocator/geolocator.dart";
import "../domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/coordinate_extensions.dart";

class CoordinatesController {
  final Completer<GoogleMapController> _controller = Completer();

  Future<GoogleMapController> get mapController => _controller.future;

  static const Coordinate sgw = Coordinate(latitude: 45.4972, longitude: -73.5786);
  static const Coordinate loyola = Coordinate(latitude: 45.45823348665408, longitude: -73.64067095332564);

  void onMapCreated(final GoogleMapController controller) {
    if (!_controller.isCompleted) _controller.complete(controller);
  }

  Future<void> goToCoordinate(final Coordinate coord, {final double zoom = 17}) async {
    final controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: coord.toLatLng(), zoom: zoom),
    ));
  }

  Future<void> goToCurrentLocation(final BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await Geolocator.isLocationServiceEnabled()) {
      messenger.showSnackBar(const SnackBar(content: Text("Enable location services")));
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) {
      messenger.showSnackBar(const SnackBar(content: Text("Enable location permissions in settings")));
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    await goToCoordinate(Coordinate(latitude: pos.latitude, longitude: pos.longitude));
  }
}
