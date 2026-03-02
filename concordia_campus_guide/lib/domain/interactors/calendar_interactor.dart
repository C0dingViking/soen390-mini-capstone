import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:concordia_campus_guide/domain/exceptions/invalid_event_format_exception.dart";
import "package:concordia_campus_guide/domain/exceptions/invalid_location_format_exception.dart";
import "package:concordia_campus_guide/domain/models/academic_class.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/room.dart";
import "package:concordia_campus_guide/utils/pattern_extensions.dart";

class CalendarInteractor {
  final GoogleCalendarRepository _calendarRepo;
  final BuildingRepository _buildingRepo = BuildingRepository();

  CalendarInteractor({final GoogleCalendarRepository? calendarRepo})
    : _calendarRepo = calendarRepo ?? GoogleCalendarRepository();

  Future<List<AcademicClass>> getUpcomingClasses({
    final int maxResults = 10,
    final DateTime? timeMin,
    final DateTime? timeMax,
    final String buildingDataPath = "assets/maps/building_data.json",
  }) async {
    final events = await _calendarRepo.getUpcomingEvents(
      maxResults: maxResults,
      timeMin: timeMin,
      timeMax: timeMax,
    );

    final academicClasses = <AcademicClass>[];
    for (final event in events) {
      try {
        // This is to skip events that dont match the format to be considered a class
        if (!AcademicClass.checkEventFormat(event)) {
          continue;
        }
        final String? buildingId = await _buildingNameFormatCheck(
          event.location ?? "",
          buildingDataPath: buildingDataPath,
        );
        if (buildingId == null) {
          // We dont throw here because building name can be a building that is not fully supported
          throw InvalidLocationFormatException(
            "Class location does not match any known building: ${event.location}",
          );
        }

        final Room room = Room.fromLocation(event.location ?? "", buildingId);
        final academicClass = AcademicClass.fromCalendar(event, room);
        academicClasses.add(academicClass);
      } on InvalidEventFormatException {
        continue;
      }
    }

    return academicClasses;
  }

  Future<String?> _buildingNameFormatCheck(
    final String location, {
    final String buildingDataPath = "assets/maps/building_data.json",
  }) async {
    final allBuildings = await _buildingRepo.loadBuildings(buildingDataPath);
    final List<Building> buildings = allBuildings.values.toList();

    final Pattern buildingNamePattern = RegExp(r"-\s*(.*?)\s*Rm");
    final match = buildingNamePattern.firstMatchOf(location.trim());

    final eventLocationBuildingName = match?.group(1);

    if (eventLocationBuildingName == null || eventLocationBuildingName.isEmpty) {
      throw InvalidLocationFormatException(
        "Building name could not be extracted from location: $location",
      );
    }

    for (final building in buildings) {
      if (building.name.contains(eventLocationBuildingName!) ||
          eventLocationBuildingName.contains(building.name)) {
        return building.id;
      }
    }
    if (eventLocationBuildingName.contains("Faubourg Building (FG)")) {
      return "fg";
    } else if (eventLocationBuildingName.contains("Faubourg Tower (FB)")) {
      return "fb";
    } else if (eventLocationBuildingName.contains("CL Building")) {
      return "cl";
    } else {
      // Since we don't officially support every building, we handle unsupported buildings by treating their name as ID
      return eventLocationBuildingName;
    }
  }
}
