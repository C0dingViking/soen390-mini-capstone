import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:concordia_campus_guide/ui/directions/view_models/directions_view_model.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/interactors/route_interactor.dart";

class DirectionsScreen extends StatelessWidget {
  final Map<String, Building> buildings;

  const DirectionsScreen({super.key, required this.buildings});

  @override
  Widget build(final BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DirectionsViewModel(
        routeInteractor: RouteInteractor(),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Get Directions"),
          foregroundColor: Colors.white,
        ),
        body: Consumer<DirectionsViewModel>(
          builder: (context, viewModel, child) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Start Location Section
                  const Text(
                    "Start Location",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
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
                  const Text(
                    "Destination Building",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  //Wrapper
                  Container(
                    constraints: const BoxConstraints(maxHeight: 56), 
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Select a building",
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                      ),
                      isExpanded: true, 
                      value: viewModel.destinationBuilding?.id,
                      items: buildings.values.map((building) {
                        return DropdownMenuItem<String>(
                          value: building.id,
                          child: Text(
                            "${building.name} (${building.id.toUpperCase()})",
                            overflow: TextOverflow.ellipsis, //Long Building Names
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          context.read<DirectionsViewModel>().setDestination(buildings[value]!);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

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

  void _showRoute(BuildContext context, DirectionsViewModel viewModel) {
    final route = viewModel.plannedRoute!;
    final distanceKm = (route.estimatedDistance ?? 0) / 1000;
    
    showDialog(
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