import "package:concordia_campus_guide/domain/exceptions/invalid_event_format_exception.dart";
import "package:concordia_campus_guide/domain/models/room.dart";
import "package:concordia_campus_guide/utils/pattern_extensions.dart";
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
  /// Throw InvalidEventFormatException if the Event has unexpected format
  factory AcademicClass.fromCalendar(final Event calendarEvent, final Room room) {
    final name = calendarEvent.summary ?? "";
    final startTime = calendarEvent.start?.dateTime;
    final endTime = calendarEvent.end?.dateTime;

    if (!checkEventFormat(calendarEvent)) {
      throw InvalidEventFormatException("Calendar event does not match expected format");
    }

    // Convert start and end times to local timezone for easier display in the UI
    return AcademicClass(name, startTime!.toLocal(), endTime!.toLocal(), room);
  }

  static bool checkEventFormat(final Event event) {
    final Pattern courseCodePattern = RegExp(r"([A-Z]{2,4}\s?\d{3})");
    final Pattern classTypePattern = RegExp(r"\b(LEC|TUT|LAB)\b");
    if (event.summary == null ||
        event.summary!.isEmpty ||
        courseCodePattern.firstMatchOf(event.summary!) == null ||
        classTypePattern.firstMatchOf(event.summary!) == null) {
      return false;
    }
    if (event.start?.dateTime == null) {
      return false;
    }
    if (event.end?.dateTime == null) {
      return false;
    }
    if (event.location == null || event.location!.isEmpty) {
      return false;
    }
    return true;
  }

  String getCourseCode() {
    final Pattern regex = RegExp(r"([A-Z]{2,4}\s?\d{3})");
    final match = regex.firstMatchOf(name);
    if (match != null) {
      return match.group(0)!.replaceAll(" ", "");
    }
    throw InvalidEventFormatException("Class name does not contain a valid course code");
  }

  String classType() {
    final Pattern regex = RegExp(r"\b(LEC|TUT|LAB)\b", caseSensitive: false);
    final match = regex.firstMatchOf(name);

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

    return "Unknown";
  }

  String getFormattedDayAndTime() {
    final weekDay = _getWeekday(startTime.weekday);
    final startTimeFormatted =
        "${startTime.hourOfPeriod}:${startTime.minute.toString().padLeft(2, "0")} ${startTime.hour >= 12 ? "PM" : "AM"}";
    final endTimeFormatted =
        "${endTime.hourOfPeriod}:${endTime.minute.toString().padLeft(2, "0")} ${endTime.hour >= 12 ? "PM" : "AM"}";
    return "${weekDay}s, \nAt $startTimeFormatted - $endTimeFormatted";
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
