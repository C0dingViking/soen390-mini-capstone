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
