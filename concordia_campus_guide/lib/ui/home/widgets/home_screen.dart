import 'package:concordia_campus_guide/domain/models/coordinate.dart';
import 'package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:concordia_campus_guide/utils/coordinate_extensions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Coordinate sgw = Coordinate(latitude: 45.4972, longitude: -73.5786);
  static const Coordinate loyola = Coordinate(latitude: 45.45823348665408, longitude: -73.64067095332564);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CampusAppBar(),

      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: sgw.toLatLng(),
          zoom: 15,
        ),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }
}