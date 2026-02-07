import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:concordia_campus_guide/domain/converters/campus_converter.dart";
import "package:concordia_campus_guide/domain/converters/coordinate_converter.dart";
import "package:concordia_campus_guide/domain/converters/building_feature_converter.dart";
import "package:flutter_google_maps_webservices/places.dart";
import "package:json_annotation/json_annotation.dart";

part "building.g.dart";

enum BuildingFeature {
  escalator,
  elevator,
  wheelChairAccess,
  bathroom,
  shuttleBus,
  metroAccess,
  food,
}

@JsonSerializable()
class Building {
  final String id;
  final String? googlePlacesId;
  final String name;
  final String description;
  final String street;
  final String postalCode;
  final List<String> images;

  @CoordinateConverter()
  final Coordinate location;

  @JsonKey(name: "hours", defaultValue: null)
  final OpeningHoursDetail hours;

  @CampusConverter()
  final Campus campus;

  @JsonKey(name: "points")
  @CoordinateListConverter()
  List<Coordinate> outlinePoints;
  double? minLatitude;
  double? maxLatitude;
  double? minLongitude;
  double? maxLongitude;

  @BuildingFeatureListConverter()
  final List<BuildingFeature>? buildingFeatures;

  Building({
    required this.id,
    this.googlePlacesId,
    required this.name,
    required this.description,
    required this.street,
    required this.postalCode,
    required this.location,
    required this.hours,
    required this.campus,
    required this.outlinePoints,
    required this.images,
    this.buildingFeatures,
  });

  factory Building.fromJson(final Map<String, dynamic> json) =>
      _$BuildingFromJson(json);
  Map<String, dynamic> toJson() => _$BuildingToJson(this);

  /// Precompute axis-aligned bounding box for outlinePoints. Call after
  /// constructing or when `outlinePoints` changes.
  void computeOutlineBBox() {
    if (outlinePoints.isEmpty) {
      minLatitude = maxLatitude = location.latitude;
      minLongitude = maxLongitude = location.longitude;
      return;
    }

    double minLat = outlinePoints[0].latitude;
    double maxLat = outlinePoints[0].latitude;
    double minLon = outlinePoints[0].longitude;
    double maxLon = outlinePoints[0].longitude;

    for (final p in outlinePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    minLatitude = minLat;
    maxLatitude = maxLat;
    minLongitude = minLon;
    maxLongitude = maxLon;
  }

  /// Fast axis-aligned bbox check; returns true if [c] is inside the bbox.
  bool isInsideBBox(final Coordinate c) {
    if (minLatitude == null ||
        maxLatitude == null ||
        minLongitude == null ||
        maxLongitude == null) {
      computeOutlineBBox();
    }
    return c.latitude >= (minLatitude ?? double.negativeInfinity) &&
        c.latitude <= (maxLatitude ?? double.infinity) &&
        c.longitude >= (minLongitude ?? double.negativeInfinity) &&
        c.longitude <= (maxLongitude ?? double.infinity);
  }

  String get address => "$street, Montreal, QC $postalCode, Canada";

  bool isOpen() {
    if (googlePlacesId != null) {
      return hours.openNow;
    }

    final now = DateTime.now();
    final currentDay = now.weekday % 7;
    final currentTime = now.hour * 100 + now.minute;

    for (final period in hours.periods) {
      if (period.open?.day == currentDay) {
        final openTime = int.tryParse(period.open?.time ?? "") ?? 0;
        final closeTime = period.close != null
            ? int.tryParse(period.close?.time ?? "") ?? 2400
            : 2400;

        if (period.close == null) {
          return true;
        }

        if (currentTime >= openTime && currentTime < closeTime) {
          return true;
        }
      }
    }
    return false;
  }

  List<OpeningHoursPeriod> getSchedule() {
    return hours.periods;
  }

  @override
  String toString() => "$id: ($name - $address at ${location.toString()})";
}
