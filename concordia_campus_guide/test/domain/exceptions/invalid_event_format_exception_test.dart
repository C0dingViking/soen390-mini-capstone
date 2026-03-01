import "package:concordia_campus_guide/domain/exceptions/invalid_event_format_exception.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("InvalidEventFormatException", () {
    test("stores message passed to constructor", () {
      const message = "Event summary is invalid";

      final exception = InvalidEventFormatException(message);

      expect(exception.message, message);
    });

    test("toString includes exception type and message", () {
      const message = "Class name does not contain a valid course code";

      final exception = InvalidEventFormatException(message);

      expect(exception.toString(), "InvalidEventFormatException: $message");
    });
  });
}
