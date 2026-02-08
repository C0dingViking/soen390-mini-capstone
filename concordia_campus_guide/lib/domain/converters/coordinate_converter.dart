import "package:json_annotation/json_annotation.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";

class CoordinateConverter implements JsonConverter<Coordinate, List<dynamic>> {
  const CoordinateConverter();

  @override
  Coordinate fromJson(final List<dynamic> json) {
    return Coordinate(
      latitude: (json[0] as num).toDouble(),
      longitude: (json[1] as num).toDouble(),
    );
  }

  @override
  List<dynamic> toJson(final Coordinate coordinate) {
    return [coordinate.latitude, coordinate.longitude];
  }
}

class CoordinateListConverter
    implements JsonConverter<List<Coordinate>, List<dynamic>> {
  const CoordinateListConverter();

  @override
  List<Coordinate> fromJson(final List<dynamic> json) {
    const converter = CoordinateConverter();
    return json
        .map((final p) => converter.fromJson(p as List<dynamic>))
        .toList();
  }

  @override
  List<dynamic> toJson(final List<Coordinate> coordinates) {
    const converter = CoordinateConverter();
    return coordinates.map(converter.toJson).toList();
  }
}
