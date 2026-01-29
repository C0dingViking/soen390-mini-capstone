import 'package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CampusAppBar(),

      body: const GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(45.4972, -73.5786),
          zoom: 15,
        ),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }
}
