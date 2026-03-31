import "dart:async";
import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:concordia_campus_guide/data/services/location_service.dart";
import "../domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/coordinate_extensions.dart";
import "package:concordia_campus_guide/utils/dialog_helper.dart";

class CoordinatesController {
  final Completer<GoogleMapController> _controller = Completer();
  static const String _locationErrorTitle = "Location Error";

  Future<GoogleMapController> get mapController => _controller.future;

  static const Coordinate sgw = Coordinate(latitude: 45.4972, longitude: -73.5786);
  static const Coordinate loyola = Coordinate(
    latitude: 45.45823348665408,
    longitude: -73.64067095332564,
  );

  void onMapCreated(final GoogleMapController controller) {
    if (!_controller.isCompleted) _controller.complete(controller);
  }

  Future<void> goToCoordinate(final Coordinate coord, {final double zoom = 17}) async {
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: coord.toLatLng(), zoom: zoom)),
    );
  }

  Future<void> fitBounds(final LatLngBounds bounds, {final double padding = 80}) async {
    final controller = await _controller.future;
    final adjustedBounds = _expandBoundsIfNeeded(bounds);
    await controller.animateCamera(CameraUpdate.newLatLngBounds(adjustedBounds, padding));
  }

  LatLngBounds _expandBoundsIfNeeded(final LatLngBounds bounds) {
    const minSpan = 0.002; // ~200m to prevent over-zooming on tiny routes
    final latSpan = (bounds.northeast.latitude - bounds.southwest.latitude).abs();
    final lngSpan = (bounds.northeast.longitude - bounds.southwest.longitude).abs();

    if (latSpan >= minSpan && lngSpan >= minSpan) {
      return bounds;
    }

    final centerLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    final latDeltaFromCenter = (latSpan < minSpan ? minSpan : latSpan) / 2;
    final lngDeltaFromCenter = (lngSpan < minSpan ? minSpan : lngSpan) / 2;

    return LatLngBounds(
      southwest: LatLng(centerLat - latDeltaFromCenter, centerLng - lngDeltaFromCenter),
      northeast: LatLng(centerLat + latDeltaFromCenter, centerLng + lngDeltaFromCenter),
    );
  }

  Future<void> goToCurrentLocation(final BuildContext context) async {
    try {
      final coord = await LocationService.instance.getCurrentPosition();
      await goToCoordinate(coord);
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString();
      if (msg.contains("disabled")) {
        await showErrorPopup(context, "Enable location services", title: _locationErrorTitle);
      } else if (msg.contains("deniedForever")) {
        await showErrorPopup(
          context,
          "Enable location permissions in settings",
          title: _locationErrorTitle,
        );
      } else if (msg.contains("denied")) {
        // user denied once; silently return
      } else {
        await showErrorPopup(context, "$e", title: _locationErrorTitle);
      }
    }
  }
}
