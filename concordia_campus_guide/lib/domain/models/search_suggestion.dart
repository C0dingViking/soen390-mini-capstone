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

  factory SearchSuggestion.building(final Building building, {final String? subtitle}) {
    return SearchSuggestion._(
      type: SearchSuggestionType.building,
      title: building.name,
      subtitle: subtitle,
      building: building,
    );
  }

  factory SearchSuggestion.place(final PlaceSuggestion place) {
    return SearchSuggestion._(
      type: SearchSuggestionType.place,
      title: place.mainText.isNotEmpty ? place.mainText : place.description,
      subtitle: _buildPlaceSubtitle(place),
      place: place,
    );
  }

  static String? _buildPlaceSubtitle(final PlaceSuggestion place) {
    final parts = <String>[];

    if (place.distanceMeters != null) {
      parts.add(_formatDistance(place.distanceMeters!));
    }

    if (place.secondaryText.isNotEmpty) {
      parts.add(place.secondaryText);
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(" • ");
  }

  static String _formatDistance(final double distanceMeters) {
    if (distanceMeters >= 1000) {
      return "${(distanceMeters / 1000).toStringAsFixed(1)} km";
    }

    return "${distanceMeters.round()} m";
  }
}
