import "package:concordia_campus_guide/utils/campus.dart";

class Room {
  String roomNumber;
  int floor;
  Campus campus;
  String buildingId;

  Room(this.roomNumber, this.floor, this.campus, this.buildingId);

  /// Constructor for Room. Takes a calendar event's location as
  /// input and attempts to parse the string for a valid Room
  ///
  /// Throw FormatException if the string has unexpected format
  factory Room.fromLocation(final String location) {
    // string like "Sir George Williams Campus - CL Building Rm 235"
    final roomPattern = RegExp(r"(?:Rm)\s*(\d+)", caseSensitive: false);
    final roomMatch = roomPattern.firstMatch(location);
    if (roomMatch == null) {
      throw FormatException("Room number not found in location: $location");
    }
    final roomNumber = roomMatch.group(1)!;

    final floor = int.parse(roomNumber) ~/ 100;

    late Campus campus;
    if (location.toLowerCase().contains("loyola")) {
      campus = Campus.loyola;
    } else if (location.toLowerCase().contains("george williams")) {
      campus = Campus.sgw;
    } else {
      throw FormatException("Campus not found in location: $location");
    }

    final buildingPattern = RegExp(r"(\w+)\s+Building", caseSensitive: false);
    final buildingMatch = buildingPattern.firstMatch(location);
    if (buildingMatch == null) {
      throw FormatException("Building not found in location: $location");
    }
    final buildingId = buildingMatch.group(1)!.toLowerCase();

    return Room(roomNumber, floor, campus, buildingId);
  }

  @override
  String toString() {
    return "Room{roomNumber: $roomNumber, floor: $floor, campus: ${campus.name}, buildingId: $buildingId}";
  }
}
