import "package:concordia_campus_guide/domain/converters/campus_converter.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("CampusConverter", () {
    const converter = CampusConverter();

    group("fromJson", () {
      test("converts 'sgw' string to Campus.sgw", () {
        expect(converter.fromJson("sgw"), equals(Campus.sgw));
      });

      test("converts 'SGW' string to Campus.sgw (case insensitive)", () {
        expect(converter.fromJson("SGW"), equals(Campus.sgw));
      });

      test("converts 'Sir George Williams' to Campus.sgw", () {
        expect(converter.fromJson("Sir George Williams"), equals(Campus.sgw));
      });

      test("converts 'loyola' string to Campus.loyola", () {
        expect(converter.fromJson("loyola"), equals(Campus.loyola));
      });

      test("converts 'Loyola' string to Campus.loyola (case insensitive)", () {
        expect(converter.fromJson("Loyola"), equals(Campus.loyola));
      });

      test("converts 'loy' string to Campus.loyola", () {
        expect(converter.fromJson("loy"), equals(Campus.loyola));
      });
    });

    group("toJson", () {
      test("converts Campus.sgw to 'sgw'", () {
        expect(converter.toJson(Campus.sgw), equals("sgw"));
      });

      test("converts Campus.loyola to 'loyola'", () {
        expect(converter.toJson(Campus.loyola), equals("loyola"));
      });
    });
  });
}
