import "package:json_annotation/json_annotation.dart";
import "package:concordia_campus_guide/utils/campus.dart";

class CampusConverter implements JsonConverter<Campus, String> {
  const CampusConverter();

  @override
  Campus fromJson(final String json) {
    return parseCampus(json)!;
  }

  @override
  String toJson(final Campus campus) {
    return campus.name;
  }
}
