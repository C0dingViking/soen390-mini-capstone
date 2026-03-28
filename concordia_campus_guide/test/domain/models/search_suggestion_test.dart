import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/search_suggestion.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:flutter_google_maps_webservices/places.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("SearchSuggestion room", () {
    test("factory creates room suggestion with expected fields", () {
      final building = Building(
        id: "H",
        googlePlacesId: null,
        name: "Hall Building",
        description: "desc",
        street: "1455 De Maisonneuve Blvd W",
        postalCode: "H3G 1M8",
        location: const Coordinate(latitude: 45.4973, longitude: -73.5788),
        hours: OpeningHoursDetail(),
        campus: Campus.sgw,
        outlinePoints: const [],
        images: const [],
        supportedIndoorFloors: const [1, 2],
      );

      final suggestion = SearchSuggestion.room(
        building: building,
        roomLabel: "H 110",
        subtitle: "SGW - Hall Building",
      );

      expect(suggestion.type, SearchSuggestionType.room);
      expect(suggestion.title, "H 110");
      expect(suggestion.subtitle, "SGW - Hall Building");
      expect(suggestion.building, same(building));
      expect(suggestion.roomLabel, "H 110");
      expect(suggestion.place, isNull);
    });
  });
}
