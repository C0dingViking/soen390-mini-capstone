import "package:concordia_campus_guide/ui/directions/widgets/searchable_building_field.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:concordia_campus_guide/ui/directions/view_models/directions_view_model.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/interactors/route_interactor.dart";

class DirectionsScreen extends StatelessWidget {
  final Map<String, Building> buildings;
  final DirectionsViewModel? viewModel; //For testing purposes
  final Building? startBuilding;
  final Building? destinationBuilding;


  const DirectionsScreen({super.key, required this.buildings, this.viewModel, this.startBuilding, this.destinationBuilding});

  @override
  Widget build(final BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final vm = DirectionsViewModel(routeInteractor: RouteInteractor());
        vm.initializeFromBuildings(startBuilding, destinationBuilding);
        return vm;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Get Directions"),
          foregroundColor: Colors.white,
        ),
        body: Consumer<DirectionsViewModel>(
          builder: (final context, final viewModel, final child) {
            final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Start Location Section
                  SearchableBuildingField(
                    buildings: buildings.values.toList(),
                    selected: viewModel.startBuilding,
                    label: "Start Location",
                    onSelected: (final b) => viewModel.setStartBuilding(b),
                  ),

                  SizedBox(height: keyboardOpen ? 12 : 32),
                  
                  ElevatedButton.icon(
                    onPressed: viewModel.isLoadingLocation 
                        ? null 
                        : () => context.read<DirectionsViewModel>().useCurrentLocation(),
                    icon: viewModel.isLoadingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      viewModel.currentLocationCoordinate != null
                          ? "Current Location (${viewModel.currentLocationCoordinate!.latitude.toStringAsFixed(4)}, ${viewModel.currentLocationCoordinate!.longitude.toStringAsFixed(4)})"
                          : "Use Current Location",
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: viewModel.currentLocationCoordinate != null
                          ? Colors.green.shade100
                          : null,
                    ),
                  ),

                  if (viewModel.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        viewModel.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Destination Section
                  SearchableBuildingField(
                    buildings: buildings.values.toList(),
                    selected: viewModel.destinationBuilding,
                    label: "Destination Building",
                    onSelected: (final b) => viewModel.updateDestination(b),
                  ),

                  SizedBox(height: keyboardOpen ? 12 : 32),

                  // Get Directions Button
                  ElevatedButton(
                    onPressed: viewModel.canGetDirections
                        ? () => _showRoute(context, viewModel)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF912338), 
                    ),
                    child: const Text(
                      "Get Directions",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showRoute(final BuildContext context, final DirectionsViewModel viewModel) {
    final route = viewModel.plannedRoute!;
    final distanceKm = (route.estimatedDistanceMeters ?? 0) / 1000;
    
    showDialog<void>(
      context: context,
      builder: (final context) => AlertDialog(
        title: const Text("Route Created"),
        content: Text(
          "From: Current Location\n"
          "To: ${route.destinationBuilding.name}\n"
          "Distance: ${distanceKm.toStringAsFixed(2)} km",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
