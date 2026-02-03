import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:concordia_campus_guide/controllers/coordinates_controller.dart';
import 'package:concordia_campus_guide/domain/models/campus_details.dart';
import 'package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart';
import 'package:concordia_campus_guide/ui/home/view_models/home_view_model.dart';
import 'package:concordia_campus_guide/utils/coordinate_extensions.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CoordinatesController _coords = CoordinatesController();

  final Color _buttonColor = const Color(0xCC00ADEF);

  final List<CampusDetails> _campuses = [
    const CampusDetails(name: 'SGW', coord: HomeViewModel.sgw, icon: Icons.location_city),
    const CampusDetails(name: 'LOY', coord: HomeViewModel.loyola, icon: Icons.school),
  ];

  @override
  void initState() {
    super.initState();

    // initializes the building data once the Provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeViewModel>().initializeBuildingsData("assets/maps/building_data.json");
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = Provider.of<HomeViewModel>(context, listen: false);
    vm.addListener(_onViewModelChange);
  }

  @override
  void dispose() {
    final vm = Provider.of<HomeViewModel>(context, listen: false);
    vm.removeListener(_onViewModelChange);
    super.dispose();
  }

  void _onViewModelChange() {
    if (!mounted) return;
    final vm = context.read<HomeViewModel>();
    if (vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
    }
    if (vm.cameraTarget != null) {
      _coords.goToCoordinate(vm.cameraTarget!);
      vm.clearCameraTarget();
    }
  }

  // Coordinates for loyola, uncomment if needed
  // static const Coordinate loyola = Coordinate(latitude: 45.45823348665408, longitude: -73.64067095332564);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CampusAppBar(),
      
      // subscribes to the HomeViewModel, rebuilds on change
      body: Consumer<HomeViewModel>(
        builder: (context, hvm, child) {
          final CampusDetails selected = _campuses[hvm.selectedCampusIndex];
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: HomeViewModel.sgw.toLatLng(),
                  zoom: 15,
                ),
                onMapCreated: _coords.onMapCreated,
                myLocationEnabled: hvm.myLocationEnabled,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                polygons: hvm.buildingOutlines,
                markers: hvm.buildingMarkers,
                fortyFiveDegreeImageryEnabled: false,
              ),
              Positioned(
                left: 25,
                bottom: 25,
                child: FloatingActionButton(
                  heroTag: 'my_location',
                  onPressed: () => context.read<HomeViewModel>().goToCurrentLocation(),
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
                    onTap: () => context.read<HomeViewModel>().toggleCampus(),
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
          );
        },
      ),
    );
  }
}
