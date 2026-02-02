import 'package:concordia_campus_guide/domain/models/coordinate.dart';
import 'package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart';
import 'package:concordia_campus_guide/ui/home/view_models/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:concordia_campus_guide/utils/coordinate_extensions.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Coordinate sgw = Coordinate(
    latitude: 45.4972,
    longitude: -73.5786,
  );

  @override
  void initState() {
    super.initState();

    // initializes the building data once the Provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>()
          .initializeBuildingsData("assets/maps/building_data.json");
    });
  }

  // Coordinates for loyola, uncomment if needed
  // static const Coordinate loyola = Coordinate(latitude: 45.45823348665408, longitude: -73.64067095332564);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CampusAppBar(),

      // subscribes to the HomeViewModel, rebuilds on change
      body: Consumer<HomeViewModel>(
        builder: (_, hvm, _) => GoogleMap(
            initialCameraPosition: CameraPosition(target: sgw.toLatLng(), zoom: 15),
            polygons: hvm.buildingPolygons,
            markers: hvm.buildingMarkers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            fortyFiveDegreeImageryEnabled: false,
          )
      )
    );
  }
}
