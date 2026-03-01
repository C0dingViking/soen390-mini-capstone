import "package:concordia_campus_guide/domain/exceptions/invalid_location_format_exception.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("InvalidLocationFormatException", () {
    test("stores message passed to constructor", () {
      const message = "Location string is empty";

      final exception = InvalidLocationFormatException(message);

      expect(exception.message, message);
    });

    test("toString returns raw message", () {
      const message = "Room number format is invalid";

      final exception = InvalidLocationFormatException(message);

      expect(exception.toString(), message);
    });
  });
}
