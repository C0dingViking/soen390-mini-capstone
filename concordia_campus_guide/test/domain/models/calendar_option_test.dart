import "package:concordia_campus_guide/domain/models/calendar_option.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("CalendarOption", () {
    test("stores provided title and id", () {
      final option = CalendarOption(title: "My Calendar", id: "calendar-123");

      expect(option.title, equals("My Calendar"));
      expect(option.id, equals("calendar-123"));
    });

    test("supports duplicate titles with different ids", () {
      final options = [
        CalendarOption(title: "Work", id: "work-primary"),
        CalendarOption(title: "Work", id: "work-shared"),
      ];

      expect(options.map((final o) => o.title), everyElement(equals("Work")));
      expect(options.map((final o) => o.id).toSet().length, equals(2));
      expect(options[0].id, isNot(equals(options[1].id)));
    });
  });
}
