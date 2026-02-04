import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";

class MapWrapper extends StatelessWidget {
  final CameraPosition initialCameraPosition;
  final void Function(GoogleMapController) onMapCreated;
  final bool myLocationEnabled;
  final Set<Polygon> polygons;
  final Set<Marker> markers;
  
  // These are the missing definitions
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool fortyFiveDegreeImageryEnabled;

  const MapWrapper({
    super.key,
    required this.initialCameraPosition,
    required this.onMapCreated,
    required this.myLocationEnabled,
    required this.polygons,
    required this.markers,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = false,
    this.fortyFiveDegreeImageryEnabled = false,
  });

  @override
  Widget build(final BuildContext context) {
    return GoogleMap(
      initialCameraPosition: initialCameraPosition,
      onMapCreated: onMapCreated,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      zoomControlsEnabled: zoomControlsEnabled,
      polygons: polygons,
      markers: markers,
      fortyFiveDegreeImageryEnabled: fortyFiveDegreeImageryEnabled,
    );
  }
}
