import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart";
import "package:concordia_campus_guide/ui/home/widgets/opening_hours_widget.dart";
import "package:concordia_campus_guide/utils/image_helper.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../directions/directions_screen.dart";
import "../view_models/home_view_model.dart";

class BuildingDetailScreen extends StatelessWidget {
  final Building building;

  const BuildingDetailScreen({super.key, required this.building});

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: const CampusAppBar(),
      body: Container(
        color: AppTheme.concordiaGold,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        building.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      _buildImage(),

                      const SizedBox(height: 16),

                      _buildAddressRow(context),

                      const SizedBox(height: 16),

                      if (building.buildingFeatures != null &&
                          building.buildingFeatures!.isNotEmpty)
                        Builder(
                          builder: (final context) =>
                              _buildFeaturesRow(context),
                        ),

                      const SizedBox(height: 16),

                      _buildOpeningHours(),

                      const SizedBox(height: 20),

                      Text(
                        building.description,
                        textAlign: TextAlign.left,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Accessibility Info
          FloatingActionButton(
            heroTag: "accessibility_info",
            onPressed: () => _showAccessibilityDialog(context),
            tooltip: "Accessibility Information",
            backgroundColor: AppTheme.concordiaMaroon,
            child: const Icon(Icons.info, color: Colors.white),
          ),

          const SizedBox(height: 12),

          // Start From Here
          FloatingActionButton.extended(
            heroTag: "start_from_here",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (final context) => DirectionsScreen(
                    buildings: context.read<HomeViewModel>().buildings,
                    startBuilding: building,
                  ),
                ),
              );
            },
            backgroundColor: Colors.green.shade700,
            icon: const Icon(Icons.flag, color: Colors.white),
            label: const Text("Start from here", style: TextStyle(color: Colors.white)),
          ),

          const SizedBox(height: 12),

          // Go To This Building
          FloatingActionButton.extended(
            heroTag: "go_to_here",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (final context) => DirectionsScreen(
                    buildings: context.read<HomeViewModel>().buildings,
                    destinationBuilding: building,
                  ),
                ),
              );
            },
            backgroundColor: Colors.blue.shade700,
            icon: const Icon(Icons.place, color: Colors.white),
            label: const Text("Go to this building", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (building.images.isNotEmpty) {
      // TODO: convert to an carousel if we decide to scrape images from google places API
      return building.images.first.toImage(
        width: double.infinity,
        height: 250,
        fit: BoxFit.cover,
        errorBuilder: (final context, final error, final stackTrace) =>
            _buildPlaceholderImage(),
      );
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 250,
      color: Colors.grey[300],
      child: const Icon(Icons.apartment, size: 80, color: Colors.grey),
    );
  }

  Widget _buildAddressRow(final BuildContext context) {
    return Column(
      children: [
        Text(
          building.address,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  void _showAccessibilityDialog(final BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (final BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.concordiaGold,
          title: Text(
            "Accessibility Features",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppTheme.concordiaMaroon),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: building.buildingFeatures!.map((final feature) {
                return _buildAccessibilityFeature(feature, context);
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Close",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.concordiaMaroon,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccessibilityFeature(
    final BuildingFeature feature,
    final BuildContext context,
  ) {
    IconData icon;
    String description;

    switch (feature) {
      case BuildingFeature.wheelChairAccess:
        icon = Icons.accessible;
        description = "Wheelchair Accessible";
        break;
      case BuildingFeature.elevator:
        icon = Icons.elevator;
        description = "Elevator Available";
        break;
      case BuildingFeature.escalator:
        icon = Icons.stairs;
        description = "Escalator Available";
        break;
      case BuildingFeature.bathroom:
        icon = Icons.wc;
        description = "Restrooms Available";
        break;
      case BuildingFeature.metroAccess:
        icon = Icons.train;
        description = "Metro Access";
        break;
      case BuildingFeature.food:
        icon = Icons.restaurant;
        description = "Food Services";
        break;
      case BuildingFeature.shuttleBus:
        icon = Icons.directions_bus;
        description = "Shuttle Bus Stop";
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 32, color: AppTheme.concordiaMaroon),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesRow(final BuildContext context) {
    return Wrap(
      spacing: 20.0,
      runSpacing: 16.0,
      children: building.buildingFeatures!.take(8).map((final feature) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 32 - 60) / 6,
          child: _buildFeatureIcon(feature),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureIcon(final BuildingFeature feature) {
    IconData icon;

    switch (feature) {
      case BuildingFeature.wheelChairAccess:
        icon = Icons.accessible;
        break;
      case BuildingFeature.elevator:
        icon = Icons.elevator;
        break;
      case BuildingFeature.escalator:
        icon = Icons.stairs;
        break;
      case BuildingFeature.bathroom:
        icon = Icons.wc;
        break;
      case BuildingFeature.metroAccess:
        icon = Icons.train;
        break;
      case BuildingFeature.food:
        icon = Icons.restaurant;
        break;
      case BuildingFeature.shuttleBus:
        icon = Icons.directions_bus;
        break;
    }

    return Column(
      children: [
        Icon(icon, size: 48, color: AppTheme.concordiaForeground),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildOpeningHours() {
    return OpeningHoursWidget(building: building);
  }
}
