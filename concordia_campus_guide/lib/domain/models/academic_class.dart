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

    // Convert start and end times to local timezone for easier display in the UI
    return AcademicClass(name, startTime.toLocal(), endTime.toLocal(), room);
  }

  /// Returns the course code for this class (e.g. "SOEN390")
  String getCourseCode() {
    final regex = RegExp(r"([A-Z]{2,4}\s?\d{3})");
    final match = regex.firstMatch(name);
    if (match != null) {
      return match.group(1)?.replaceAll(" ", "") ?? "Unknown Course";
    }
    return "Unknown Course";
  }

  /// Returns the type of class (e.g. "Lecture", "Tutorial", "Lab") based on the abbreviation in the class name (e.g. "LEC", "TUT", "LAB").
  /// If no abbreviation is found, returns "Unknown Type".
  String classType() {
    final regex = RegExp(r"\b(LEC|TUT|LAB)\b", caseSensitive: false);
    final match = regex.firstMatch(name);

    if (match != null) {
      final type = match.group(1)?.toUpperCase();

      switch (type) {
        case "LEC":
          return "Lecture";
        case "TUT":
          return "Tutorial";
        case "LAB":
          return "Lab";
      }
    }

    return "Unknown Type";
  }

  /// Returns a well formatted string representation of the day and time of this class (e.g. "Monday, 1/1/2026 at 10:00 AM - 11:00 AM")
  String getFormattedDateTime() {
    final weekDay = _getWeekday(startTime.weekday);
    final date = "${startTime.month}/${startTime.day}/${startTime.year}";
    final startTimeFormatted =
        "${startTime.hourOfPeriod}:${startTime.minute.toString().padLeft(2, "0")} ${startTime.hour >= 12 ? "PM" : "AM"}";
    final endTimeFormatted =
        "${endTime.hourOfPeriod}:${endTime.minute.toString().padLeft(2, "0")} ${endTime.hour >= 12 ? "PM" : "AM"}";
    return "$weekDay, $date at $startTimeFormatted - $endTimeFormatted";
  }

  @override
  String toString() {
    return "AcademicClass{name: $name, startTime: $startTime, endTime: $endTime, room: $room}";
  }

  String _getWeekday(final int weekDay) {
    switch (weekDay) {
      case DateTime.monday:
        return "Monday";
      case DateTime.tuesday:
        return "Tuesday";
      case DateTime.wednesday:
        return "Wednesday";
      case DateTime.thursday:
        return "Thursday";
      case DateTime.friday:
        return "Friday";
      case DateTime.saturday:
        return "Saturday";
      case DateTime.sunday:
        return "Sunday";
      default:
        return "Unknown Day";
    }
  }
}

extension on DateTime {
  int get hourOfPeriod => hour % 12 == 0 ? 12 : hour % 12;
}
