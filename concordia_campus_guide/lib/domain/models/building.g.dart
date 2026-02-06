// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'building.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Building _$BuildingFromJson(Map<String, dynamic> json) => Building(
  id: json['id'] as String,
  googlePlacesId: json['googlePlacesId'] as String?,
  name: json['name'] as String,
  description: json['description'] as String,
  street: json['street'] as String,
  postalCode: json['postalCode'] as String,
  location: const CoordinateConverter().fromJson(json['location'] as List),
  hours: OpeningHoursDetail.fromJson(json['hours'] as Map<String, dynamic>),
  campus: const CampusConverter().fromJson(json['campus'] as String),
  outlinePoints: const CoordinateListConverter().fromJson(
    json['points'] as List,
  ),
  images: (json['images'] as List<dynamic>).map((e) => e as String).toList(),
  buildingFeatures: const BuildingFeatureListConverter().fromJson(
    json['buildingFeatures'] as List?,
  ),
);

Map<String, dynamic> _$BuildingToJson(Building instance) => <String, dynamic>{
  'id': instance.id,
  'googlePlacesId': instance.googlePlacesId,
  'name': instance.name,
  'description': instance.description,
  'street': instance.street,
  'postalCode': instance.postalCode,
  'location': const CoordinateConverter().toJson(instance.location),
  'hours': instance.hours,
  'campus': const CampusConverter().toJson(instance.campus),
  'points': const CoordinateListConverter().toJson(instance.outlinePoints),
  'buildingFeatures': const BuildingFeatureListConverter().toJson(
    instance.buildingFeatures,
  ),
  'images': instance.images,
};
