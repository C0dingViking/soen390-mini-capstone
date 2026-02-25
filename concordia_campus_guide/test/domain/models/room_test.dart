import "package:flutter_test/flutter_test.dart";
import "package:concordia_campus_guide/domain/models/room.dart";
import "package:concordia_campus_guide/utils/campus.dart";

void main() {
  group("Room.fromLocation", () {
    test("parses SGW room location", () {
      const location = "Sir George Williams Campus - CL Building Rm 235";

      final room = Room.fromLocation(location);

      expect(room.roomNumber, "235");
      expect(room.floor, "2");
      expect(room.campus, Campus.sgw);
      expect(room.buildingId, "cl");
    });

    test("parses Loyola room location", () {
      const location = "Loyola Campus - SP Building Rm 101";

      final room = Room.fromLocation(location);

      expect(room.roomNumber, "101");
      expect(room.floor, "1");
      expect(room.campus, Campus.loyola);
      expect(room.buildingId, "sp");
    });

    test("parses dot room format and special MB building id", () {
      const location = "Sir George Williams Campus - John Molson School of Business Rm S2.330";

      final room = Room.fromLocation(location);

      expect(room.roomNumber, "S2.330");
      expect(room.floor, "S2");
      expect(room.campus, Campus.sgw);
      expect(room.buildingId, "mb");
    });

    test("parses two-digit room format", () {
      const location = "Loyola Campus - SP Building Rm 05";

      final room = Room.fromLocation(location);

      expect(room.roomNumber, "05");
      expect(room.floor, "0");
      expect(room.campus, Campus.loyola);
      expect(room.buildingId, "sp");
    });

    test("throws when room number is missing", () {
      const location = "Sir George Williams Campus - CL Building";

      expect(() => Room.fromLocation(location), throwsA(isA<FormatException>()));
    });

    test("throws when campus is missing", () {
      const location = "Downtown Campus - CL Building Rm 235";

      expect(() => Room.fromLocation(location), throwsA(isA<FormatException>()));
    });

    test("throws when building is missing", () {
      const location = "Sir George Williams Campus - Rm 235";

      expect(() => Room.fromLocation(location), throwsA(isA<FormatException>()));
    });

    test("parses lowercase rm token", () {
      const location = "Sir George Williams Campus - CL Building rm 235";

      final room = Room.fromLocation(location);

      expect(room.roomNumber, "235");
      expect(room.floor, "2");
      expect(room.campus, Campus.sgw);
      expect(room.buildingId, "cl");
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
