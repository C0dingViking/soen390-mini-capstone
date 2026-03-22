import "dart:async";

import "package:flutter/foundation.dart";
import "package:geolocator/geolocator.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";

/// Encapsulates Geolocator usage and exposes a broadcast stream of `Coordinate`.
class LocationService {
  LocationService._privateConstructor();
  static final LocationService instance = LocationService._privateConstructor();

  late StreamController<Coordinate> _controller = StreamController<Coordinate>.broadcast();
  StreamSubscription<Position>? _posSub;

  Stream<Coordinate> get positionStream => _controller.stream;

  Future<Coordinate> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PermissionDeniedException(
        "Location services disabled. Enter locations manually or enable location services.",
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException(
          "Location permission denied. Enter locations manually or enable location permissions.",
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException(
        "Location permission deniedForever. Please enable it in settings.",
      );
    }
    final accuracy = await Geolocator.getLocationAccuracy();
    if (accuracy == LocationAccuracyStatus.reduced) {
      throw const PermissionDeniedException(
        "Location accuracy is reduced. Turn on Location Accuracy the Concordia Campus Guide app for full location functionality.",
      );
    }

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw const PermissionDeniedException(
        "Location request timed out. Location service may be disabled.",
      );
    } on Exception catch (e) {
      // throw a more user friendly message if location accuracy is off
      if (e.toString().contains("The location service on the device is disabled.")) {
        throw const PermissionDeniedException(
          "Location services are unavailable. Turn on Location and Location Accuracy.",
        );
      }
      rethrow;
    }

    return Coordinate(latitude: pos.latitude, longitude: pos.longitude);
  }

  Future<void> start({
    final LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    final int distanceFilter = 5,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      ))
        return;

      LocationPermission permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 2),
        onTimeout: () => LocationPermission.denied,
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 5),
          onTimeout: () => LocationPermission.denied,
        );
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _posSub?.cancel();
      _posSub =
          Geolocator.getPositionStream(
            locationSettings: LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter),
          ).listen(
            (final pos) {
              _controller.add(Coordinate(latitude: pos.latitude, longitude: pos.longitude));
            },
            onError: (final error) {
              // swallow stream errors silently
            },
          );
    } catch (_) {
      // swallow errors here; callers may subscribe to stream and handle absence
    }
  }

  void stop() {
    _posSub?.cancel();
    _posSub = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  @visibleForTesting
  static void resetForTesting() {
    instance.dispose();
    instance._posSub = null;
    if (instance._controller.isClosed) {
      instance._controller = StreamController<Coordinate>.broadcast();
    }
  }
}
