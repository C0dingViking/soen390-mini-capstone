import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/search_suggestion.dart";
import "package:concordia_campus_guide/utils/campus.dart";

typedef ParsedRoomLabel = ({String buildingId, String roomNumber});

class QueryHelper {
  static const int _defaultBuildingOnlyLimit = 8;
  static const int _defaultBuildingWhenRoomLimit = 4;
  static const int _defaultRoomLimit = 8;
  static const int _defaultTotalLimit = 10;

  static List<SearchSuggestion> buildSearchSuggestions({
    required final String query,
    required final Map<String, Building> buildings,
    required final List<String> campusRoomLabels,
    final bool includeRooms = false,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return [];

    final buildingSuggestions = _buildBuildingSuggestionsFromQuery(normalizedQuery, buildings);

    if (!includeRooms || campusRoomLabels.isEmpty) {
      return buildingSuggestions.take(_defaultBuildingOnlyLimit).toList();
    }

    final roomSuggestions = _buildRoomSuggestionsFromQuery(
      query: normalizedQuery,
      buildings: buildings,
      campusRoomLabels: campusRoomLabels,
      roomLimit: _defaultRoomLimit,
    );

    return [
      ...buildingSuggestions.take(_defaultBuildingWhenRoomLimit),
      ...roomSuggestions,
    ].take(_defaultTotalLimit).toList();
  }

  static Building? findBuildingById(
    final String buildingId,
    final Map<String, Building> buildings,
  ) {
    final normalized = buildingId.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final directMatch =
        buildings[buildingId] ?? buildings[normalized] ?? buildings[normalized.toUpperCase()];
    if (directMatch != null) return directMatch;

    for (final building in buildings.values) {
      if (building.id.toLowerCase() == normalized) {
        return building;
      }
    }

    return null;
  }

  static ParsedRoomLabel? parseRoomLabel(final String rawLabel) {
    final trimmed = rawLabel.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split(RegExp(r"\s+"));
    if (parts.length < 2) return null;

    final buildingId = parts.first.trim();
    final roomNumber = trimmed.substring(parts.first.length).trim();
    if (buildingId.isEmpty || roomNumber.isEmpty) return null;

    return (buildingId: buildingId, roomNumber: roomNumber);
  }

  static bool isCampusRoomLabel(final String roomLabel, final Map<String, Building> buildings) {
    final parsed = parseRoomLabel(roomLabel);
    if (parsed == null) return false;

    final building = findBuildingById(parsed.buildingId, buildings);
    if (building == null || building.supportedIndoorFloors.isEmpty) {
      return false;
    }

    return building.campus == Campus.sgw || building.campus == Campus.loyola;
  }

  static List<SearchSuggestion> _buildBuildingSuggestionsFromQuery(
    final String query,
    final Map<String, Building> buildings,
  ) {
    final matches = _matchAndSortBuildings(query, buildings.values);
    return matches.map((final building) {
      final campusLabel = building.campus == Campus.sgw ? "SGW" : "LOY";
      return SearchSuggestion.building(
        building,
        subtitle: "$campusLabel - ${building.id.toUpperCase()}",
      );
    }).toList();
  }

  static List<Building> _matchAndSortBuildings(
    final String query,
    final Iterable<Building> buildings,
  ) {
    final matches = buildings.where((final building) {
      final name = building.name.toLowerCase();
      final id = building.id.toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();

    matches.sort((final a, final b) {
      final rankA = _matchRank(a, query);
      final rankB = _matchRank(b, query);
      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.name.compareTo(b.name);
    });

    return matches;
  }

  static List<SearchSuggestion> _buildRoomSuggestionsFromQuery({
    required final String query,
    required final Map<String, Building> buildings,
    required final List<String> campusRoomLabels,
    required final int roomLimit,
  }) {
    final roomMatches = _matchAndSortRooms(query, campusRoomLabels);
    final roomSuggestions = <SearchSuggestion>[];

    for (final roomLabel in roomMatches) {
      final parsed = parseRoomLabel(roomLabel);
      if (parsed == null) continue;

      final building = findBuildingById(parsed.buildingId, buildings);
      if (building == null) continue;

      final campusLabel = building.campus == Campus.sgw ? "SGW" : "LOY";
      roomSuggestions.add(
        SearchSuggestion.room(
          building: building,
          roomLabel: "${building.id.toUpperCase()} ${parsed.roomNumber}",
          subtitle: "$campusLabel - ${building.name}",
        ),
      );

      if (roomSuggestions.length >= roomLimit) break;
    }

    return roomSuggestions;
  }

  static List<String> _matchAndSortRooms(final String query, final List<String> campusRoomLabels) {
    final roomMatches = campusRoomLabels
        .where((final roomLabel) => _roomMatchesQuery(roomLabel, query))
        .toList();

    roomMatches.sort((final a, final b) {
      final rankA = _roomMatchRank(a, query);
      final rankB = _roomMatchRank(b, query);
      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.compareTo(b);
    });

    return roomMatches;
  }

  static bool _roomMatchesQuery(final String roomLabel, final String query) {
    final normalizedQuery = _normalizeSearchToken(query);
    final normalizedLabel = _normalizeSearchToken(roomLabel);
    return roomLabel.toLowerCase().contains(query) ||
        (normalizedQuery.isNotEmpty && normalizedLabel.contains(normalizedQuery));
  }

  static int _roomMatchRank(final String roomLabel, final String query) {
    final normalizedQuery = _normalizeSearchToken(query);
    final normalizedLabel = _normalizeSearchToken(roomLabel);
    final roomLower = roomLabel.toLowerCase();

    if (roomLower.startsWith(query)) return 0;
    if (roomLower.contains(query)) return 1;
    if (normalizedQuery.isNotEmpty && normalizedLabel.startsWith(normalizedQuery)) return 2;
    if (normalizedQuery.isNotEmpty && normalizedLabel.contains(normalizedQuery)) return 3;
    return 4;
  }

  static int _matchRank(final Building building, final String query) {
    final name = building.name.toLowerCase();
    final id = building.id.toLowerCase();
    if (name.startsWith(query)) return 0;
    if (name.contains(query)) return 1;
    if (id.startsWith(query)) return 2;
    if (id.contains(query)) return 3;
    return 4;
  }

  static String _normalizeSearchToken(final String value) {
    return value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), "");
  }
}
