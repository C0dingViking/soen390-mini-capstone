import "package:concordia_campus_guide/controllers/coordinates_controller.dart";
import "package:concordia_campus_guide/domain/models/campus_details.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart";
import "package:concordia_campus_guide/ui/hamburger_menu/widgets/hamburger_menu.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/home/widgets/building_detail_screen.dart";
import "package:concordia_campus_guide/ui/home/widgets/map_wrapper.dart";
import "package:concordia_campus_guide/ui/home/widgets/building_search_bar.dart";
import "package:concordia_campus_guide/ui/home/widgets/route_details_panel.dart";
import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_map.dart";
import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:concordia_campus_guide/utils/coordinate_extensions.dart";
import "package:provider/provider.dart";
import "package:google_fonts/google_fonts.dart";

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
    const CampusDetails(name: "SGW", coord: HomeViewModel.sgw, icon: Icons.location_city),
    const CampusDetails(name: "LOY", coord: HomeViewModel.loyola, icon: Icons.school),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeViewModel>().initializeBuildingsData(HomeViewModel.buildingDataAssetPath);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_viewModel.errorMessage!)));
      _viewModel.consumeErrorMessage();
    }
    if (_viewModel.generateInfoMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_viewModel.generateInfoMessage!)));
      _viewModel.generateInfoMessage = null; // Auto clear
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
    if (_viewModel.showLoginSuccessMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLoginSuccessMessage(context);
      });
      _viewModel.clearLoginSuccessMessage();
    }
    if (_viewModel.showNextClassDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showNextClassDialog(context);
      });
      _viewModel.clearNextClassDialog();
    }
  }

  void _onBuildingTapped(final PolygonId polygonId) {
    // Extract building ID from polygon ID (format: "buildingId-poly")
    final buildingId = polygonId.value.replaceAll("-poly", "");
    _navigateToBuilding(buildingId);
  }

  void _onBuildingMarkerTapped(final MarkerId markerId) {
    final buildingId = markerId.value.replaceAll("-marker", "");
    _navigateToBuilding(buildingId);
  }

  void _navigateToBuilding(final String buildingId) {
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

  void _showLoginSuccessMessage(final BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (final context) => AlertDialog(
        backgroundColor: AppTheme.concordiaButtonCyan,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Your Gmail Account is Connected!",
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.0),
            Text(
              "You can now import your Google Calendar events into the app.",
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 16.0),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.8,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<HomeViewModel>().clearLoginSuccessMessage();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_circle_left_outlined, color: Colors.white),
                label: Text("Return to Map", style: GoogleFonts.roboto(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNextClassDialog(final BuildContext context) {
    final upcomingClass = _viewModel.upcomingClass;
    if (upcomingClass == null) return;

    final courseCode = upcomingClass.getCourseCode();
    final classType = upcomingClass.classType();
    final dateTime = upcomingClass.getFormattedDayAndTime();
    final location =
        "${upcomingClass.room.buildingId.toUpperCase()} ${upcomingClass.room.roomNumber}";

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (final context) => AlertDialog(
        backgroundColor: AppTheme.concordiaButtonCyan,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseCode,
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(classType, style: GoogleFonts.roboto(color: Colors.white, fontSize: 16.0)),
                const SizedBox(height: 12.0),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateTime,
                        style: GoogleFonts.roboto(color: Colors.white, fontSize: 16.0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.roboto(color: Colors.white, fontSize: 16.0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: -12,
              right: -12,
              child: IconButton(
                key: const Key("next_class_dialog_close_button"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: "Close",
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await _viewModel.setDestinationToUpcomingClassBuilding();
                      if (!mounted) return;
                      navigator.pop();
                    },
                    icon: const Icon(Icons.directions, color: Colors.white),
                    label: Text("Go to Next Class", style: GoogleFonts.roboto(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final hasNavigation = context.select(
      (final HomeViewModel vm) => vm.routeOptions.isNotEmpty || vm.isLoadingRoutes,
    );
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return PopScope(
      canPop: !hasNavigation,
      onPopInvokedWithResult: (final didPop, final result) {
        if (didPop || !hasNavigation) return;
        context.read<HomeViewModel>().exitNavigation();
      },
      child: Scaffold(
        appBar: const CampusAppBar(),
        drawer: const HamburgerMenu(),
        body: Consumer<HomeViewModel>(
          builder: (final context, final hvm, final child) {
            final CampusDetails selected = _campuses[hvm.selectedCampusIndex];
            const double searchBarInset = 16;
            const double searchBarTop = 12;
            const double actionInset = 25;
            const double actionBottom = 25;
            const double secondActionBottom = 85;
            const double actionBottomWithRoutes = 145;
            const double indoorSwitchBottomOffset = 205;
            const double toggleRadius = 30;
            const double toggleVertical = 40;
            const double toggleHorizontal = 160;
            const double labelFontSize = 16;
            const double shadowBlurRadius = 6;
            const double shadowOffsetY = 2;
            final double actionBottomOffset =
              ((hvm.routeOptions.isNotEmpty || hvm.isLoadingRoutes)
                  ? actionBottomWithRoutes
                  : actionBottom) +
              bottomInset;
            final locationFabIcon = hvm.isLocationActionAvailable
                ? Icons.my_location
                : Icons.location_disabled;
            final indoorDestination = hvm.indoorNavigationDestination;
            final isInsideDestinationBuilding =
                indoorDestination != null &&
                hvm.currentBuilding != null &&
                hvm.currentBuilding!.id.toLowerCase() ==
                    indoorDestination.building.id.toLowerCase();
            final canSwitchToIndoorNavigation =
                indoorDestination != null &&
                isInsideDestinationBuilding &&
                hvm.routeOptions.isNotEmpty &&
                !hvm.isLoadingRoutes;

            return Stack(
              children: [
                MapWrapper(
                  initialCameraPosition: CameraPosition(
                    target: HomeViewModel.sgw.toLatLng(),
                    zoom: 15,
                  ),
                  onMapCreated: _coords.onMapCreated,
                  onCameraMove: hvm.onMapCameraMove,
                  myLocationEnabled: hvm.myLocationEnabled && hvm.isLocationActionAvailable,
                  polygons: hvm.buildingOutlines,
                  markers: hvm.mapMarkers,
                  polylines: hvm.routePolylines,
                  circles: hvm.transitChangeCircles,
                  onPolygonTap: _onBuildingTapped,
                  onMarkerTap: _onBuildingMarkerTapped,
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
                          key: const Key("my_location_key"),
                          heroTag: "my_location",
                          onPressed: () => context.read<HomeViewModel>().goToCurrentLocation(),
                          backgroundColor: _buttonColor,
                          icon: Icon(locationFabIcon, color: Colors.white),
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
                          key: const Key("my_location_key"),
                          heroTag: "my_location",
                          onPressed: () => context.read<HomeViewModel>().goToCurrentLocation(),
                          backgroundColor: _buttonColor,
                          child: Icon(locationFabIcon, color: Colors.white),
                        ),
                ),
                Positioned(
                  right: actionInset,
                  bottom: actionBottomOffset,
                  child: Material(
                    color: Colors.transparent,
                    child: GestureDetector(
                      key: const Key("campus_toggle_button"),
                      onTap: () => context.read<HomeViewModel>().toggleCampus(),
                      child: Container(
                        width: toggleHorizontal,
                        height: toggleVertical,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(toggleRadius),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: shadowBlurRadius,
                              offset: Offset(0, shadowOffsetY),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 250),
                              alignment: selected.name == "SGW"
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _buttonColor,
                                  borderRadius: BorderRadius.circular(toggleRadius),
                                ),
                              ),
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      "SGW",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: selected.name == "SGW" ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      "LOY",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: selected.name == "LOY" ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (hvm.showNextClassFab)
                  Positioned(
                    left: actionInset,
                    bottom: secondActionBottom + bottomInset,
                    child: FloatingActionButton.extended(
                      key: const Key("next_class"),
                      heroTag: "next_class",
                      onPressed: () => context.read<HomeViewModel>().showNextClass(),
                      backgroundColor: _buttonColor,
                      icon: const Icon(Icons.school, color: Colors.white),
                      label: const Text(
                        "Next Class",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (canSwitchToIndoorNavigation)
                  Positioned(
                    left: actionInset,
                    bottom: indoorSwitchBottomOffset + bottomInset,
                    child: FloatingActionButton.extended(
                      key: const Key("main_screen_switch_to_indoor_navigation_button"),
                      heroTag: "main_screen_switch_to_indoor_navigation",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (final context) => IndoorMapView(
                              building: indoorDestination.building,
                              initialStartRoomLabel: indoorDestination.startRoomLabel,
                              initialDestinationRoomLabel: indoorDestination.destinationRoomLabel,
                            ),
                          ),
                        );
                      },
                      backgroundColor: _buttonColor,
                      icon: const Icon(Icons.schema, color: Colors.white),
                      label: const Text(
                        "Switch Indoor",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w600,
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
