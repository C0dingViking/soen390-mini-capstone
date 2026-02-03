import 'package:concordia_campus_guide/controllers/coordinates_controller.dart';
import 'package:concordia_campus_guide/domain/models/coordinate.dart';
import 'package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart';
import 'package:concordia_campus_guide/utils/coordinate_extensions.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CoordinatesController _coords = CoordinatesController();
  bool _myLocationEnabled = false;

  Future<void> _goToCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable location services')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable location permission in settings')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      await _coords.goToCoordinate(Coordinate(latitude: pos.latitude, longitude: pos.longitude));
      setState(() => _myLocationEnabled = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  final Color _buttonColor = const Color(0xFF00ADEF).withOpacity(0.8);

  final List<_Campus> _campuses = [
    const _Campus(name: 'SGW', coord: CoordinatesController.sgw, icon: Icons.location_city),
    const _Campus(name: 'LOY', coord: CoordinatesController.loyola, icon: Icons.school),
  ];

  int _selectedCampusIndex = 0;

  Future<void> _toggleCampus() async {
    setState(() {
      _selectedCampusIndex = (_selectedCampusIndex + 1) % _campuses.length;
    });
    await _coords.goToCoordinate(_campuses[_selectedCampusIndex].coord);
  }

  @override
  Widget build(BuildContext context) {
    final _Campus selected = _campuses[_selectedCampusIndex];

    return Scaffold(
      appBar: const CampusAppBar(),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: CoordinatesController.sgw.toLatLng(),
              zoom: 15,
            ),
            onMapCreated: _coords.onMapCreated,
            myLocationEnabled: _myLocationEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          Positioned(
            left: 25,
            bottom: 25,
            child: FloatingActionButton(
              heroTag: 'my_location',
              onPressed: _goToCurrentLocation,
              backgroundColor: _buttonColor,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),

          Positioned(
            right: 25,
            bottom: 25,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: _toggleCampus,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _buttonColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _buttonColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(selected.icon, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selected.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Campus {
  final String name;
  final Coordinate coord;
  final IconData icon;

  const _Campus({required this.name, required this.coord, required this.icon});
}