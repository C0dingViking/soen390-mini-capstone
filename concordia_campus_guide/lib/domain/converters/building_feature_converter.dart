import "package:json_annotation/json_annotation.dart";
import "package:concordia_campus_guide/domain/models/building.dart";

class BuildingFeatureListConverter
    implements JsonConverter<List<BuildingFeature>?, List<dynamic>?> {
  const BuildingFeatureListConverter();

  @override
  List<BuildingFeature>? fromJson(final List<dynamic>? json) {
    if (json == null) return null;
    return json
        .map((final f) {
          try {
            return BuildingFeature.values.firstWhere(
              (final e) => e.name == f.toString(),
            );
          } catch (e) {
            return null;
          }
        })
        .whereType<BuildingFeature>()
        .toList();
  }

  @override
  List<dynamic>? toJson(final List<BuildingFeature>? features) {
    return features?.map((final f) => f.name).toList();
  }
}
