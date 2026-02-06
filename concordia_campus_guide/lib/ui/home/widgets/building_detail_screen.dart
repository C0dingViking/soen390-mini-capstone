import 'package:concordia_campus_guide/domain/models/building.dart';
import 'package:concordia_campus_guide/ui/core/themes/app_theme.dart';
import 'package:concordia_campus_guide/utils/image_helper.dart';
import 'package:flutter/material.dart';

class BuildingDetailScreen extends StatelessWidget {
  final Building building;

  const BuildingDetailScreen({super.key, required this.building});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.concordiaMaroon,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          building.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/images/concordia_logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Building Image
            _buildImage(),

            const SizedBox(height: 16),

            // Address Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildAddressRow(),
            ),

            const SizedBox(height: 16),

            // Amenities/Features Icons
            if (building.buildingFeatures != null &&
                building.buildingFeatures!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildFeaturesRow(),
              ),

            const SizedBox(height: 20),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                building.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (building.images.isNotEmpty) {
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
        const Icon(Icons.location_on, color: Colors.black87, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            building.address,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
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
        Icon(icon, size: 32, color: Colors.black87),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ],
    );
  }
}
