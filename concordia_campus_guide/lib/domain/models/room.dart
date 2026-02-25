import "package:concordia_campus_guide/utils/campus.dart";

class Room {
  String roomNumber;
  String floor;
  Campus campus;
  String buildingId;

  Room(this.roomNumber, this.floor, this.campus, this.buildingId);

  /// Constructor for Room. Takes a calendar event's location as
  /// input and attempts to parse the string for a valid Room
  /// Throw FormatException if the string has unexpected format
  factory Room.fromLocation(final String location) {
    final loc = location.trim();

    // Extract room number: accepts digits/letters + optional dots/dashes
    // Matches: "235", "S2.330", "MB-1.210", "101"
    final roomMatch = RegExp(
      r'\bRm\.?\s*([A-Za-z0-9][A-Za-z0-9\.\-]*)',
      caseSensitive: false,
    ).firstMatch(loc);

    if (roomMatch == null) {
      throw FormatException("Room number not found in location: $location");
    }
    final roomNumber = roomMatch.group(1)!.trim();

    // Determine floor from room number
    late String floor;

    if (roomNumber.contains('.')) {
      // Format like "S2.330" -> floor is "S2"
      floor = roomNumber.split('.').first;
    } else if (roomNumber.contains('-')) {
      // Format like "MB-1.210" -> floor is part before first dot or before dash
      final parts = roomNumber.split('-');
      if (parts.first.contains('.')) {
        floor = parts.first.split('.').first;
      } else {
        floor = parts.first;
      }
    } else if (RegExp(r'^\d{3,}$').hasMatch(roomNumber)) {
      // Pure numeric like "235" -> floor is "2" (hundreds digit)
      floor = (int.parse(roomNumber) ~/ 100).toString();
    } else if (RegExp(r'^\d{2}$').hasMatch(roomNumber)) {
      // Two digit like "05" -> floor is "0"
      floor = (int.parse(roomNumber) ~/ 10).toString();
    } else {
      // Non-numeric format with letters, use as-is or extract prefix
      floor = roomNumber.replaceAll(RegExp(r'\d.*'), ''); // Extract letter prefix
      if (floor.isEmpty) {
        floor = roomNumber; // Fallback to whole room number
      }
    }

    // Determine campus
    late Campus campus;
    if (location.toLowerCase().contains("loyola")) {
      campus = Campus.loyola;
    } else if (location.toLowerCase().contains("george williams")) {
      campus = Campus.sgw;
    } else {
      throw FormatException("Campus not found in location: $location");
    }

    // Extract building name: everything between '-' and 'Rm'
    // This handles both "CL Building" and "John Molson School of Business"
    final buildingMatch = RegExp(r'-\s*(.+?)\s*Rm\b', caseSensitive: false).firstMatch(loc);

    if (buildingMatch == null) {
      throw FormatException("Building not found in location: $location");
    }

    final buildingName = buildingMatch.group(1)!.trim();
    // Remove trailing "Building" keyword if present for cleaner building ID
    final cleanBuildingName = buildingName
        .replaceAll(RegExp(r'\s+Building\s*$', caseSensitive: false), '')
        .trim();
    String buildingId = cleanBuildingName.toLowerCase();
    if (buildingName == "John Molson School of Business") {
      // Special case for John Molson School of Business to avoid overly long building ID
      buildingId = "mb";
    }

    if (buildingId.isEmpty) {
      throw FormatException("Building not found in location: $location");
    }

    return Room(roomNumber, floor, campus, buildingId);
  }

  @override
  String toString() {
    return "Room{roomNumber: $roomNumber, floor: $floor, campus: ${campus.name}, buildingId: $buildingId}";
  }
}
