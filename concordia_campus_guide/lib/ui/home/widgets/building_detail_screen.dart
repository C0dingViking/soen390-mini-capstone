import 'package:concordia_campus_guide/domain/models/building.dart';
import 'package:concordia_campus_guide/ui/core/themes/app_theme.dart';
import 'package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart';
import 'package:concordia_campus_guide/ui/home/widgets/opening_hours_widget.dart';
import "package:concordia_campus_guide/utils/app_logger.dart";
import 'package:concordia_campus_guide/utils/image_helper.dart';
import 'package:flutter/material.dart';
import "package:flutter/widget_previews.dart";

class BuildingDetailScreen extends StatelessWidget {
  final Building building;

  const BuildingDetailScreen({super.key, required this.building});

  @override
  Widget build(BuildContext context) {
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
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppTheme.concordiaForeground,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        building.name,
                        style: const TextStyle(
                          color: AppTheme.concordiaForeground,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
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

                      _buildAddressRow(),

                      const SizedBox(height: 16),

                      if (building.buildingFeatures != null &&
                          building.buildingFeatures!.isNotEmpty)
                        Builder(
                          builder: (context) => _buildFeaturesRow(context),
                        ),

                      const SizedBox(height: 16),

                      _buildOpeningHours(),

                      const SizedBox(height: 20),

                      Text(
                        building.description,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: AppTheme.concordiaForeground,
                        ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => logger.d("meh"),
        tooltip: "Assesibility Information",
        child: const Icon(Icons.info),
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
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
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

  Widget _buildAddressRow() {
    return Column(
      children: [
        Text(
          building.address,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.concordiaForeground,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesRow(BuildContext context) {
    return Wrap(
      spacing: 20.0,
      runSpacing: 16.0,
      children: building.buildingFeatures!.take(8).map((feature) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 32 - 60) / 6,
          child: _buildFeatureIcon(feature),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureIcon(BuildingFeature feature) {
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
