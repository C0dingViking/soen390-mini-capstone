import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/domain/models/academic_class.dart";
import "package:concordia_campus_guide/domain/models/room.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:googleapis/calendar/v3.dart";

void main() {
  group("AcademicClass.fromCalendar", () {
    test("creates class from valid event", () {
      final event = Event(
        summary: "SOEN 390",
        location: "Sir George Williams Campus - CL Building Rm 235",
        start: EventDateTime(dateTime: DateTime.parse("2025-01-01T10:00:00Z")),
        end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
      );

      final academicClass = AcademicClass.fromCalendar(event);

      expect(academicClass.name, "SOEN 390");
      expect(academicClass.startTime, DateTime.parse("2025-01-01T10:00:00Z"));
      expect(academicClass.endTime, DateTime.parse("2025-01-01T11:00:00Z"));
      expect(academicClass.room.roomNumber, "235");
      expect(academicClass.room.floor, 2);
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
}
