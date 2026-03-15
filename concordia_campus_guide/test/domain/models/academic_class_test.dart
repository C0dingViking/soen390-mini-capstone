import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/domain/exceptions/invalid_event_format_exception.dart";
import "package:concordia_campus_guide/domain/models/academic_class.dart";
import "package:concordia_campus_guide/domain/models/room.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:googleapis/calendar/v3.dart";

void main() {
  group("AcademicClass.fromCalendar", () {
    test("creates class from valid event", () {
      final startTimeUtc = DateTime.parse("2025-01-01T10:00:00Z");
      final endTimeUtc = DateTime.parse("2025-01-01T11:00:00Z");
      final event = Event(
        summary: "SOEN 390 LEC",
        location: "Sir George Williams Campus - CL Building Rm 235",
        start: EventDateTime(dateTime: startTimeUtc),
        end: EventDateTime(dateTime: endTimeUtc),
      );
      final room = Room("235", "2", Campus.sgw, "cl");

      final academicClass = AcademicClass.fromCalendar(event, room);

      expect(academicClass.name, "SOEN 390 LEC");
      expect(academicClass.startTime, startTimeUtc.toLocal());
      expect(academicClass.endTime, endTimeUtc.toLocal());
      expect(academicClass.room.roomNumber, "235");
      expect(academicClass.room.floor, "2");
      expect(academicClass.room.campus, Campus.sgw);
      expect(academicClass.room.buildingId, "cl");
    });

    test("throws when event name is empty", () {
      final event = Event(
        summary: "",
        location: "Sir George Williams Campus - CL Building Rm 235",
        start: EventDateTime(dateTime: DateTime.parse("2025-01-01T10:00:00Z")),
        end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
      );
      final room = Room("235", "2", Campus.sgw, "cl");

      expect(
        () => AcademicClass.fromCalendar(event, room),
        throwsA(isA<InvalidEventFormatException>()),
      );
    });

    test("throws when start time is missing", () {
      final event = Event(
        summary: "SOEN 390 LEC A",
        location: "Sir George Williams Campus - CL Building Rm 235",
        end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
      );
      final room = Room("235", "2", Campus.sgw, "cl");

      expect(
        () => AcademicClass.fromCalendar(event, room),
        throwsA(isA<InvalidEventFormatException>()),
      );
    });

    test("throws when end time is missing", () {
      final event = Event(
        summary: "SOEN 390 LEC",
        location: "Sir George Williams Campus - CL Building Rm 235",
        start: EventDateTime(dateTime: DateTime.parse("2025-01-01T10:00:00Z")),
      );
      final room = Room("235", "2", Campus.sgw, "cl");

      expect(
        () => AcademicClass.fromCalendar(event, room),
        throwsA(isA<InvalidEventFormatException>()),
      );
    });

    test("throws when location is missing", () {
      final event = Event(
        summary: "SOEN 390 LEC",
        start: EventDateTime(dateTime: DateTime.parse("2025-01-01T10:00:00Z")),
        end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
      );
      final room = Room("235", "2", Campus.sgw, "cl");

      expect(
        () => AcademicClass.fromCalendar(event, room),
        throwsA(isA<InvalidEventFormatException>()),
      );
    });
  });

  group("AcademicClass.toString", () {
    test("includes class fields", () {
      final room = Room.fromLocation("Sir George Williams Campus - H Building Rm 101", "h");
      final academicClass = AcademicClass(
        "ENCS 282",
        DateTime.parse("2025-02-01T09:00:00Z"),
        DateTime.parse("2025-02-01T10:00:00Z"),
        room,
      );

      final result = academicClass.toString();

      expect(result, contains("name: ENCS 282"));
      expect(result, contains("startTime"));
      expect(result, contains("endTime"));
      expect(result, contains("Room"));
    });
  });

  group("AcademicClass.getCourseCode", () {
    test("extracts compact course code when class name has space", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "SOEN 390 LEC",
        DateTime.parse("2025-02-01T09:00:00Z"),
        DateTime.parse("2025-02-01T10:00:00Z"),
        room,
      );

      expect(academicClass.getCourseCode(), "SOEN390");
    });

    test("throws when no course code exists", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "Project Meeting",
        DateTime.parse("2025-02-01T09:00:00Z"),
        DateTime.parse("2025-02-01T10:00:00Z"),
        room,
      );

      expect(() => academicClass.getCourseCode(), throwsA(isA<InvalidEventFormatException>()));
    });
  });

  group("AcademicClass.classType", () {
    test("returns Lecture for LEC", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime.parse("2025-02-01T09:00:00Z"),
        DateTime.parse("2025-02-01T10:00:00Z"),
        room,
      );

      expect(academicClass.classType(), "Lecture");
    });

    test("returns Tutorial for lowercase tut", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "COMP 248 tut B",
        DateTime.parse("2025-02-01T09:00:00Z"),
        DateTime.parse("2025-02-01T10:00:00Z"),
        room,
      );

      expect(academicClass.classType(), "Tutorial");
    });

    test("returns Lab for LAB", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "COEN 243 LAB C",
        DateTime.parse("2025-02-01T09:00:00Z"),
        DateTime.parse("2025-02-01T10:00:00Z"),
        room,
      );

      expect(academicClass.classType(), "Lab");
    });

    test("returns Unknown when no abbreviation exists", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "General Session",
        DateTime.parse("2025-02-01T09:00:00Z"),
        DateTime.parse("2025-02-01T10:00:00Z"),
        room,
      );

      expect(academicClass.classType(), "Unknown");
    });
  });

  group("AcademicClass.getFormattedDateTime", () {
    test("formats date and time in expected weekday and AM/PM format", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime.parse("2026-01-05T13:05:00"),
        DateTime.parse("2026-01-05T14:15:00"),
        room,
      );

      expect(academicClass.getFormattedDayAndTime(), "Mondays, \nAt 1:05 PM - 2:15 PM");
    });

    test("formats midnight and noon correctly", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime.parse("2026-01-06T00:00:00"),
        DateTime.parse("2026-01-06T12:00:00"),
        room,
      );

      expect(academicClass.getFormattedDayAndTime(), "Tuesdays, \nAt 12:00 AM - 12:00 PM");
    });

    test("formats Wednesday correctly", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime.parse("2026-01-07T09:30:00"),
        DateTime.parse("2026-01-07T11:00:00"),
        room,
      );

      expect(academicClass.getFormattedDayAndTime(), "Wednesdays, \nAt 9:30 AM - 11:00 AM");
    });

    test("formats Thursday correctly", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime.parse("2026-01-08T14:00:00"),
        DateTime.parse("2026-01-08T15:30:00"),
        room,
      );

      expect(academicClass.getFormattedDayAndTime(), "Thursdays, \nAt 2:00 PM - 3:30 PM");
    });

    test("formats Friday correctly", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime.parse("2026-01-09T10:00:00"),
        DateTime.parse("2026-01-09T11:30:00"),
        room,
      );

      expect(academicClass.getFormattedDayAndTime(), "Fridays, \nAt 10:00 AM - 11:30 AM");
    });

    test("formats Saturday correctly", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime.parse("2026-01-10T08:00:00"),
        DateTime.parse("2026-01-10T09:30:00"),
        room,
      );

      expect(academicClass.getFormattedDayAndTime(), "Saturdays, \nAt 8:00 AM - 9:30 AM");
    });

    test("formats Sunday correctly", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime.parse("2026-01-11T16:00:00"),
        DateTime.parse("2026-01-11T17:30:00"),
        room,
      );

      expect(academicClass.getFormattedDayAndTime(), "Sundays, \nAt 4:00 PM - 5:30 PM");
    });
  });
}
