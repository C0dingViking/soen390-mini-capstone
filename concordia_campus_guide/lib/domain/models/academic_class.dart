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
  factory AcademicClass.fromCalendar(final Event calendarEvent) {
    final name = calendarEvent.summary ?? "";
    final startTime = calendarEvent.start?.dateTime;
    final endTime = calendarEvent.end?.dateTime;
    final location = calendarEvent.location;

    if (name.isEmpty) {
      throw const FormatException("Event name is empty");
    }
    if (startTime == null) {
      throw const FormatException("Event start time is missing");
    }
    if (endTime == null) {
      throw const FormatException("Event end time is missing");
    }
    if (location == null) {
      throw const FormatException("Event location is missing");
    }

    final room = Room.fromLocation(location);

    return AcademicClass(name, startTime, endTime, room);
  }

  @override
  String toString() {
    return "AcademicClass{name: $name, startTime: $startTime, endTime: $endTime, room: $room}";
  }
}
