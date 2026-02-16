import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";

enum SearchSuggestionType { building, place }

class SearchSuggestion {
  final SearchSuggestionType type;
  final String title;
  final String? subtitle;
  final Building? building;
  final PlaceSuggestion? place;

  const SearchSuggestion._({
    required this.type,
    required this.title,
    this.subtitle,
    this.building,
    this.place,
  });

  factory SearchSuggestion.building(
    final Building building, {
    final String? subtitle,
  }) {
    return SearchSuggestion._(
      type: SearchSuggestionType.building,
      title: building.name,
      subtitle: subtitle,
      building: building,
    );
  }

  factory SearchSuggestion.place(final PlaceSuggestion place) {
    final subtitle = place.secondaryText.isNotEmpty ? place.secondaryText : null;
    return SearchSuggestion._(
      type: SearchSuggestionType.place,
      title: place.mainText.isNotEmpty ? place.mainText : place.description,
      subtitle: subtitle,
      place: place,
    );
  }
}
