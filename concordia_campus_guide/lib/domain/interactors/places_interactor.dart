import "package:concordia_campus_guide/data/services/places_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";

class PlacesInteractor {
  final PlacesService _service;

  PlacesInteractor({final PlacesService? service})
      : _service = service ?? PlacesService();

  Future<List<PlaceSuggestion>> searchPlaces(final String query) {
    return _service.fetchAutocomplete(query);
  }

  Future<Coordinate?> resolvePlace(final String placeId) {
    return _service.fetchPlaceCoordinate(placeId);
  }

  Future<Coordinate?> resolvePlaceSuggestion(final PlaceSuggestion suggestion) {
    return _service.fetchPlaceCoordinate(
      suggestion.placeId,
      fallbackQuery: suggestion.description,
    );
  }
}
