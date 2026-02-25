import "package:flutter_test/flutter_test.dart";
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
        summary: "SOEN 390",
        location: "Sir George Williams Campus - CL Building Rm 235",
        start: EventDateTime(dateTime: startTimeUtc),
        end: EventDateTime(dateTime: endTimeUtc),
      );

      final academicClass = AcademicClass.fromCalendar(event);

      expect(academicClass.name, "SOEN 390");
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

      expect(() => AcademicClass.fromCalendar(event), throwsA(isA<FormatException>()));
    });

    test("throws when start time is missing", () {
      final event = Event(
        summary: "SOEN 390",
        location: "Sir George Williams Campus - CL Building Rm 235",
        end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
      );

      expect(() => AcademicClass.fromCalendar(event), throwsA(isA<FormatException>()));
    });

    test("throws when end time is missing", () {
      final event = Event(
        summary: "SOEN 390",
        location: "Sir George Williams Campus - CL Building Rm 235",
        start: EventDateTime(dateTime: DateTime.parse("2025-01-01T10:00:00Z")),
      );

      expect(() => AcademicClass.fromCalendar(event), throwsA(isA<FormatException>()));
    });

    test("throws when location is missing", () {
      final event = Event(
        summary: "SOEN 390",
        start: EventDateTime(dateTime: DateTime.parse("2025-01-01T10:00:00Z")),
        end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
      );

      expect(() => AcademicClass.fromCalendar(event), throwsA(isA<FormatException>()));
    });
  });

  group("AcademicClass.toString", () {
    test("includes class fields", () {
      final room = Room.fromLocation("Sir George Williams Campus - H Building Rm 101");
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
        "SOEN 390 LEC A",
        DateTime.parse("2025-02-01T09:00:00Z"),
        DateTime.parse("2025-02-01T10:00:00Z"),
        room,
      );

      expect(academicClass.getCourseCode(), "SOEN390");
    });

    test("returns Unknown Course when no course code exists", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "Project Meeting",
        DateTime.parse("2025-02-01T09:00:00Z"),
        DateTime.parse("2025-02-01T10:00:00Z"),
        room,
      );

      expect(academicClass.getCourseCode(), "Unknown Course");
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

    test("returns Unknown Type when no abbreviation exists", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "General Session",
        DateTime.parse("2025-02-01T09:00:00Z"),
        DateTime.parse("2025-02-01T10:00:00Z"),
        room,
      );

      expect(academicClass.classType(), "Unknown Type");
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

      expect(academicClass.getFormattedDateTime(), "Monday, 1/5/2026 at 1:05 PM - 2:15 PM");
    });

    test("formats midnight and noon correctly", () {
      final room = Room("101", "1", Campus.sgw, "h");
      final academicClass = AcademicClass(
        "SOEN 390 LEC A",
        DateTime.parse("2026-01-06T00:00:00"),
        DateTime.parse("2026-01-06T12:00:00"),
        room,
      );

      expect(academicClass.getFormattedDateTime(), "Tuesday, 1/6/2026 at 12:00 AM - 12:00 PM");
    });
  });
}
