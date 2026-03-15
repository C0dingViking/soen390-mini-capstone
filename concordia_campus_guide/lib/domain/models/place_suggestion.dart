import "package:concordia_campus_guide/domain/models/coordinate.dart";

enum PlaceSuggestionSource { autocomplete, nearby }

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final Coordinate? coordinate;
  final double? distanceMeters;
  final PlaceSuggestionSource source;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.coordinate,
    this.distanceMeters,
    this.source = PlaceSuggestionSource.autocomplete,
  });
}
