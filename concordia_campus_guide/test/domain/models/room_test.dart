import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/domain/exceptions/invalid_location_format_exception.dart";
import "package:concordia_campus_guide/domain/models/room.dart";
import "package:concordia_campus_guide/utils/campus.dart";

void main() {
  group("Room.fromLocation", () {
    test("parses SGW room location", () {
      const location = "Sir George Williams Campus - CL Building Rm 235";

      final room = Room.fromLocation(location, "cl");

      expect(room.roomNumber, "235");
      expect(room.floor, "2");
      expect(room.campus, Campus.sgw);
      expect(room.buildingId, "cl");
    });

    test("parses Loyola room location", () {
      const location = "Loyola Campus - SP Building Rm 101";

      final room = Room.fromLocation(location, "sp");

      expect(room.roomNumber, "101");
      expect(room.floor, "1");
      expect(room.campus, Campus.loyola);
      expect(room.buildingId, "sp");
    });

    test("parses dot room format and special MB building id", () {
      const location = "Sir George Williams Campus - John Molson School of Business Rm S2.330";

      final room = Room.fromLocation(location, "mb");

      expect(room.roomNumber, "S2.330");
      expect(room.floor, "S2");
      expect(room.campus, Campus.sgw);
      expect(room.buildingId, "mb");
    });

    test("parses two-digit room format", () {
      const location = "Loyola Campus - SP Building Rm 05";

      final room = Room.fromLocation(location, "sp");

      expect(room.roomNumber, "05");
      expect(room.floor, "0");
      expect(room.campus, Campus.loyola);
      expect(room.buildingId, "sp");
    });

    test("throws when room number is missing", () {
      const location = "Sir George Williams Campus - CL Building";

      expect(
        () => Room.fromLocation(location, "cl"),
        throwsA(isA<InvalidLocationFormatException>()),
      );
    });

    test("throws when campus is missing", () {
      const location = "Downtown Campus - CL Building Rm 235";

      expect(
        () => Room.fromLocation(location, "cl"),
        throwsA(isA<InvalidLocationFormatException>()),
      );
    });

    test("throws when location is empty", () {
      const location = "";

      expect(
        () => Room.fromLocation(location, "cl"),
        throwsA(isA<InvalidLocationFormatException>()),
      );
    });

    test("throws for lowercase rm token", () {
      const location = "Sir George Williams Campus - CL Building rm 235";

      expect(
        () => Room.fromLocation(location, "cl"),
        throwsA(isA<InvalidLocationFormatException>()),
      );
    });

    test("throws for H building when room is not 3-4 digits", () {
      const location = "Sir George Williams Campus - H Building Rm A101";

      expect(
        () => Room.fromLocation(location, "h"),
        throwsA(isA<InvalidLocationFormatException>()),
      );
    });

    test("parses H building when room is 3-4 digits", () {
      const location = "Sir George Williams Campus - H Building Rm 101";

      final room = Room.fromLocation(location, "h");

      expect(room.roomNumber, "101");
      expect(room.floor, "1");
      expect(room.campus, Campus.sgw);
      expect(room.buildingId, "h");
    });

    test("parses CL building with 4-digit room", () {
      const location = "Sir George Williams Campus - CL Building Rm 1234";

      final room = Room.fromLocation(location, "cl");

      expect(room.roomNumber, "1234");
      expect(room.floor, "12");
      expect(room.campus, Campus.sgw);
      expect(room.buildingId, "cl");
    });

    test("parses FG building room with B prefix", () {
      const location = "Sir George Williams Campus - Faubourg Building (FG) Rm B123";

      final room = Room.fromLocation(location, "fg");

      expect(room.roomNumber, "B123");
      expect(room.floor, "B1");
      expect(room.campus, Campus.sgw);
      expect(room.buildingId, "fg");
    });

    test("parses FB building room with S prefix", () {
      const location = "Sir George Williams Campus - Faubourg Tower (FB) Rm S123";

      final room = Room.fromLocation(location, "fb");

      expect(room.roomNumber, "S123");
      expect(room.floor, "S1");
      expect(room.campus, Campus.sgw);
      expect(room.buildingId, "fb");
    });

    test("throws for FG when room prefix is invalid", () {
      const location = "Sir George Williams Campus - Faubourg Building (FG) Rm A123";

      expect(
        () => Room.fromLocation(location, "fg"),
        throwsA(isA<InvalidLocationFormatException>()),
      );
    });

    test("throws for FB when room is not 3 digits with optional S", () {
      const location = "Sir George Williams Campus - Faubourg Tower (FB) Rm 12";

      expect(
        () => Room.fromLocation(location, "fb"),
        throwsA(isA<InvalidLocationFormatException>()),
      );
    });

    test("throws for MB when room format is invalid", () {
      const location = "Sir George Williams Campus - John Molson School of Business Rm 820";

      expect(
        () => Room.fromLocation(location, "mb"),
        throwsA(isA<InvalidLocationFormatException>()),
      );
    });

    test("throws for other buildings when room token is invalid", () {
      const location = "Loyola Campus - SP Building Rm #12";

      expect(
        () => Room.fromLocation(location, "sp"),
        throwsA(isA<InvalidLocationFormatException>()),
      );
    });

    test("uses final floor fallback branch for non-numeric room token", () {
      const location = "Loyola Campus - SP Building Rm ABC";

      final room = Room.fromLocation(location, "sp");

      expect(room.roomNumber, "ABC");
      expect(room.floor, "ABC");
      expect(room.campus, Campus.loyola);
      expect(room.buildingId, "sp");
    });
  });

  group("Room.toString", () {
    test("includes room fields", () {
      final room = Room("321", "3", Campus.sgw, "h");

      final result = room.toString();

      expect(result, contains("roomNumber: 321"));
      expect(result, contains("floor: 3"));
      expect(result, contains("campus: sgw"));
      expect(result, contains("buildingId: h"));
    });
  });
}
