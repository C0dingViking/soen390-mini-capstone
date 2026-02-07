import 'package:concordia_campus_guide/domain/models/building.dart';
import 'package:concordia_campus_guide/ui/core/themes/app_theme.dart';
import 'package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart';
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
                        _buildFeaturesRow(),

                      const SizedBox(height: 20),

                      Text(
                        building.description,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on,
          color: AppTheme.concordiaForeground,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            building.address,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.concordiaForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: building.buildingFeatures!.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(right: 20.0),
          child: _buildFeatureIcon(feature),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureIcon(BuildingFeature feature) {
    IconData icon;
    String label;

    switch (feature) {
      case BuildingFeature.wheelChairAccess:
        icon = Icons.accessible;
        label = 'Wheelchair Access';
        break;
      case BuildingFeature.elevator:
        icon = Icons.elevator;
        label = 'Elevator';
        break;
      case BuildingFeature.escalator:
        icon = Icons.stairs;
        label = 'Escalator';
        break;
      case BuildingFeature.bathroom:
        icon = Icons.wc;
        label = 'Restroom';
        break;
      case BuildingFeature.metroAccess:
        icon = Icons.train;
        label = 'Metro Access';
        break;
    }

    return Column(
      children: [
        Icon(icon, size: 32, color: AppTheme.concordiaForeground),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.concordiaForeground,
          ),
        ),
      ],
    );
  }
}
