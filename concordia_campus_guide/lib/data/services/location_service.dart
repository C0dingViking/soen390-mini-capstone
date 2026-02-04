import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:concordia_campus_guide/domain/models/coordinate.dart';

/// Encapsulates Geolocator usage and exposes a broadcast stream of `Coordinate`.
class LocationService {
  LocationService._privateConstructor();
  static final LocationService instance = LocationService._privateConstructor();

  final StreamController<Coordinate> _controller = StreamController<Coordinate>.broadcast();
  StreamSubscription<Position>? _posSub;

  Stream<Coordinate> get positionStream => _controller.stream;

  Future<Coordinate> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception("Location services disabled");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception("Location permission denied");
    }
    if (permission == LocationPermission.deniedForever) throw Exception("Location permission deniedForever. Please enable it in settings.");

    final pos = await Geolocator.getCurrentPosition();
    return Coordinate(latitude: pos.latitude, longitude: pos.longitude);
  }

  Future<void> start({LocationAccuracy accuracy = LocationAccuracy.best, int distanceFilter = 5}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter),
      ).listen((final pos) {
        _controller.add(Coordinate(latitude: pos.latitude, longitude: pos.longitude));
      });
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
}
