import "package:concordia_campus_guide/domain/exceptions/invalid_location_format_exception.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import 'package:concordia_campus_guide/utils/pattern_extensions.dart';

class Room {
  String roomNumber;
  String floor;
  Campus campus;
  String buildingId;

  Room(this.roomNumber, this.floor, this.campus, this.buildingId);

  /// Constructor for Room. Takes a calendar event's location as
  /// input and attempts to parse the string for a valid Room
  ///
  /// Throw FormatException if the string has unexpected format
  factory Room.fromLocation(final String location, final String buildingId) {
    if (location.isEmpty) {
      throw InvalidLocationFormatException("Location string is empty");
    }

    final roomNumber = Room._determineRoomNumberFromBuildingId(buildingId, location);

    final String floor = Room._determineFloorFromRoomNumber(roomNumber);
    final Campus campus = Room._determineCampus(location);

    return Room(roomNumber, floor, campus, buildingId);
  }

  static Campus _determineCampus(final String location) {
    late Campus campus;
    if (location.toLowerCase().contains("loyola")) {
      campus = Campus.loyola;
    } else if (location.toLowerCase().contains("george williams")) {
      campus = Campus.sgw;
    } else {
      throw InvalidLocationFormatException("Campus not found in location: $location");
    }
    return campus;
  }

  static String _determineRoomNumberFromBuildingId(final String buildingId, final String location) {
    final String lowerBuildingId = buildingId.toLowerCase();
    final Pattern mbBuildingRoomPattern = RegExp(r"Rm\s(?:S[12]|\d)\.\d{3}");
    final Pattern ccHBuildingRoomPattern = RegExp(r"\bRm\.?\s*(\d{3,4})");
    final Pattern otherBuildingRoomPattern = RegExp(r"\bRm\.?\s*([A-Za-z0-9][A-Za-z0-9\.\-]*)");

    if (lowerBuildingId == "mb") {
      if (mbBuildingRoomPattern.firstMatchOf(location) != null) {
        final match = mbBuildingRoomPattern.firstMatchOf(location);
        return match!.group(0)!.split("Rm").last.trim();
      } else {
        throw InvalidLocationFormatException(
          "Room number format is invalid in location: $location",
        );
      }
    } else if (lowerBuildingId == "cc" || lowerBuildingId == "h") {
      if (ccHBuildingRoomPattern.firstMatchOf(location) != null) {
        final match = ccHBuildingRoomPattern.firstMatchOf(location);
        return match!.group(1)!.trim();
      } else {
        throw InvalidLocationFormatException(
          "Room number format is invalid in location: $location",
        );
      }
    } else {
      if (otherBuildingRoomPattern.firstMatchOf(location) != null) {
        final match = otherBuildingRoomPattern.firstMatchOf(location);
        return match!.group(1)!.trim();
      } else {
        throw InvalidLocationFormatException(
          "Room number format is invalid in location: $location",
        );
      }
    }
  }

  static String _determineFloorFromRoomNumber(final String roomNumber) {
    late String floor;

    if (roomNumber.contains(".")) {
      // For formats like "S2.330"
      floor = roomNumber.split(".").first;
    } else if (RegExp(r"^\d{3,}$").hasMatch(roomNumber)) {
      // For formats like "235"
      floor = (int.parse(roomNumber) ~/ 100).toString();
    } else if (RegExp(r"^\d{2}$").hasMatch(roomNumber)) {
      // For formats like "05"
      floor = (int.parse(roomNumber) ~/ 10).toString();
    } else {
      floor = roomNumber.replaceAll(RegExp(r"\d.*"), "");
      if (floor.isEmpty) {
        floor = roomNumber;
      }
    }
    return floor;
  }

  @override
  String toString() {
    return "Room{roomNumber: $roomNumber, floor: $floor, campus: ${campus.name}, buildingId: $buildingId}";
  }
}
