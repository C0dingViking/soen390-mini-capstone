import "package:concordia_campus_guide/controllers/coordinates_controller.dart";
import "package:concordia_campus_guide/domain/models/campus_details.dart";
import "package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/home/widgets/map_wrapper.dart";
import "package:concordia_campus_guide/ui/home/widgets/building_detail_screen.dart";
import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:concordia_campus_guide/utils/coordinate_extensions.dart";
import "package:provider/provider.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CoordinatesController _coords = CoordinatesController();
  final Color _buttonColor = const Color(0xCC00ADEF);
  late HomeViewModel _viewModel;

  final List<CampusDetails> _campuses = [
    const CampusDetails(
      name: "SGW",
      coord: HomeViewModel.sgw,
      icon: Icons.location_city,
    ),
    const CampusDetails(
      name: "LOY",
      coord: HomeViewModel.loyola,
      icon: Icons.school,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeViewModel>().initializeBuildingsData(
        "assets/maps/building_data.json",
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel = Provider.of<HomeViewModel>(context, listen: false);
    _viewModel.addListener(_onViewModelChange);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    super.dispose();
  }

  void _onViewModelChange() {
    if (!mounted) return;
    if (_viewModel.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_viewModel.errorMessage!)));
    }
    if (_viewModel.cameraTarget != null) {
      _coords.goToCoordinate(_viewModel.cameraTarget!);
      _viewModel.clearCameraTarget();
    }
  }

  void _onBuildingTapped(final PolygonId polygonId) {
    // Extract building ID from polygon ID (format: "buildingId-poly")
    final buildingId = polygonId.value.replaceAll("-poly", "");
    final building = _viewModel.buildings[buildingId];

    if (building != null) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (final context) => BuildingDetailScreen(building: building),
        ),
      );
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: const CampusAppBar(),
      body: Consumer<HomeViewModel>(
        builder: (final context, final hvm, final child) {
          final CampusDetails selected = _campuses[hvm.selectedCampusIndex];
          return Stack(
            children: [
              MapWrapper(
                initialCameraPosition: CameraPosition(
                  target: HomeViewModel.sgw.toLatLng(),
                  zoom: 15,
                ),
                onMapCreated: _coords.onMapCreated,
                myLocationEnabled: hvm.myLocationEnabled,
                polygons: hvm.buildingOutlines,
                markers: hvm.buildingMarkers,
                onPolygonTap: _onBuildingTapped,
              ),
              Positioned(
                left: 25,
                bottom: 25,
                child: FloatingActionButton(
                  heroTag: "my_location",
                  onPressed: () =>
                      context.read<HomeViewModel>().goToCurrentLocation(),
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
                    key: const Key("campus_toggle_button"),
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => context.read<HomeViewModel>().toggleCampus(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _buttonColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
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
                              child: Icon(
                                selected.icon,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selected.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
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
