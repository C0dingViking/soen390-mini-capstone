import "package:concordia_campus_guide/controllers/coordinates_controller.dart";
import "package:concordia_campus_guide/domain/models/campus_details.dart";
import "package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/home/widgets/building_detail_screen.dart";
import "package:concordia_campus_guide/ui/home/widgets/map_wrapper.dart";
import "package:concordia_campus_guide/ui/home/widgets/building_search_bar.dart";
import "package:concordia_campus_guide/ui/home/widgets/route_details_panel.dart";
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

  CoordinatesController get coordsController => _coords;

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
    if (_viewModel.routeBounds != null) {
      _coords.fitBounds(_viewModel.routeBounds!);
      _viewModel.clearRouteBounds();
      if (_viewModel.cameraTarget != null) {
        _viewModel.clearCameraTarget();
      }
      return;
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
    final hasNavigation = context.select(
      (final HomeViewModel vm) =>
          vm.routeOptions.isNotEmpty || vm.isLoadingRoutes,
    );

    return PopScope(
      canPop: !hasNavigation,
      onPopInvokedWithResult: (final didPop, final result) {
        if (didPop || !hasNavigation) return;
        context.read<HomeViewModel>().exitNavigation();
      },
      child: Scaffold(
        appBar: const CampusAppBar(),
        body: Consumer<HomeViewModel>(
          builder: (final context, final hvm, final child) {
            final CampusDetails selected = _campuses[hvm.selectedCampusIndex];
            const double searchBarInset = 16;
            const double searchBarTop = 12;
            const double actionInset = 25;
            const double actionBottom = 25;
            const double actionBottomWithRoutes = 145;
            const double toggleRadius = 30;
            const double togglePaddingVertical = 8;
            const double togglePaddingHorizontal = 12;
            const double toggleIconSize = 20;
            const double toggleIconContainer = 40;
            const double labelFontSize = 16;
            const double shadowBlurRadius = 6;
            const double shadowOffsetY = 2;
            const double spacingSm = 8;
            final double actionBottomOffset =
                (hvm.routeOptions.isNotEmpty || hvm.isLoadingRoutes)
                ? actionBottomWithRoutes
                : actionBottom;
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
                  markers: hvm.mapMarkers,
                  polylines: hvm.routePolylines,
                  circles: hvm.transitChangeCircles,
                  onPolygonTap: _onBuildingTapped,
                ),
                const Positioned(
                  left: searchBarInset,
                  right: searchBarInset,
                  top: searchBarTop,
                  child: BuildingSearchBar(),
                ),
                Positioned(
                  left: actionInset,
                  bottom: actionBottomOffset,
                  child: hvm.currentBuilding != null
                      ? FloatingActionButton.extended(
                          heroTag: "my_location",
                          onPressed: () => context
                              .read<HomeViewModel>()
                              .goToCurrentLocation(),
                          backgroundColor: _buttonColor,
                          icon: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                          ),
                          label: Text(
                            hvm.currentBuilding!.id.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: labelFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : FloatingActionButton(
                          heroTag: "my_location",
                          onPressed: () => context
                              .read<HomeViewModel>()
                              .goToCurrentLocation(),
                          backgroundColor: _buttonColor,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                          ),
                        ),
                ),
                Positioned(
                  right: actionInset,
                  bottom: actionBottomOffset,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key("campus_toggle_button"),
                      borderRadius: BorderRadius.circular(toggleRadius),
                      onTap: () => context.read<HomeViewModel>().toggleCampus(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: togglePaddingVertical,
                          horizontal: togglePaddingHorizontal,
                        ),
                        decoration: BoxDecoration(
                          color: _buttonColor,
                          borderRadius: BorderRadius.circular(toggleRadius),
                          boxShadow: const [
                             BoxShadow(
                              color: Colors.black26,
                              blurRadius: shadowBlurRadius,
                              offset: Offset(0, shadowOffsetY),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: toggleIconContainer,
                              height: toggleIconContainer,
                              decoration: BoxDecoration(
                                color: _buttonColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  selected.icon,
                                  color: Colors.white,
                                  size: toggleIconSize,
                                ),
                              ),
                            ),
                            const SizedBox(width: spacingSm),
                            Text(
                              selected.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: labelFontSize,
                              ),
                            ),
                            const SizedBox(width: spacingSm),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const RouteDetailsPanel(),
              ],
            );
          },
        ),
      ),
    );
  }
}
