import "package:concordia_campus_guide/domain/models/room.dart";
import "package:googleapis/calendar/v3.dart";

class AcademicClass {
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final Room room;

  AcademicClass(this.name, this.startTime, this.endTime, this.room);

  /// Constructor for Academic Class. Takes a calendar event as
  /// input and attempts to create a class from it.
  ///
  /// Throw FormatException if the Event has unexpected format
  factory AcademicClass.fromEvent(final Event calendarEvent) {
    final name = calendarEvent.summary ?? '';
    final startTime = calendarEvent.start?.dateTime;
    final endTime = calendarEvent.end?.dateTime;
    final location = calendarEvent.location;

    if (name.isEmpty) {
      throw FormatException('Event name is empty');
    }
    if (startTime == null) {
      throw FormatException('Event start time is missing');
    }
    if (endTime == null) {
      throw FormatException('Event end time is missing');
    }
    if (location == null || location.isEmpty) {
      throw FormatException('Event location is missing');
    }

    final room = Room.fromLocation(location);

    return AcademicClass(name, startTime, endTime, room);
  }
}
