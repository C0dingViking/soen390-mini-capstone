import "package:concordia_campus_guide/domain/converters/building_feature_converter.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("BuildingFeatureListConverter", () {
    const converter = BuildingFeatureListConverter();

    group("fromJson", () {
      test("converts list of feature strings to BuildingFeature list", () {
        final result = converter.fromJson([
          "escalator",
          "elevator",
          "wheelChairAccess",
        ]);

        expect(result, hasLength(3));
        expect(result![0], equals(BuildingFeature.escalator));
        expect(result[1], equals(BuildingFeature.elevator));
        expect(result[2], equals(BuildingFeature.wheelChairAccess));
      });

      test("converts all BuildingFeature types", () {
        final result = converter.fromJson([
          "escalator",
          "elevator",
          "wheelChairAccess",
          "bathroom",
          "shuttleBus",
          "metroAccess",
          "food",
        ]);

        expect(result, hasLength(7));
        expect(result![0], equals(BuildingFeature.escalator));
        expect(result[1], equals(BuildingFeature.elevator));
        expect(result[2], equals(BuildingFeature.wheelChairAccess));
        expect(result[3], equals(BuildingFeature.bathroom));
        expect(result[4], equals(BuildingFeature.shuttleBus));
        expect(result[5], equals(BuildingFeature.metroAccess));
        expect(result[6], equals(BuildingFeature.food));
      });

      test("returns null for null input", () {
        final result = converter.fromJson(null);
        expect(result, isNull);
      });

      test("returns empty list for empty input", () {
        final result = converter.fromJson([]);
        expect(result, isEmpty);
      });

      test("filters out invalid feature names", () {
        final result = converter.fromJson([
          "elevator",
          "invalidFeature",
          "wheelChairAccess",
          "anotherInvalid",
        ]);

        expect(result, hasLength(2));
        expect(result![0], equals(BuildingFeature.elevator));
        expect(result[1], equals(BuildingFeature.wheelChairAccess));
      });

      test("handles all invalid features gracefully", () {
        final result = converter.fromJson([
          "invalidFeature1",
          "invalidFeature2",
        ]);

        expect(result, isEmpty);
      });

      test("handles mixed valid and null-like values", () {
        final result = converter.fromJson(["elevator", "", "bathroom"]);

        expect(result, hasLength(2));
        expect(result![0], equals(BuildingFeature.elevator));
        expect(result[1], equals(BuildingFeature.bathroom));
      });
    });

    group("toJson", () {
      test("converts BuildingFeature list to list of strings", () {
        const features = [
          BuildingFeature.escalator,
          BuildingFeature.elevator,
          BuildingFeature.wheelChairAccess,
        ];

        final result = converter.toJson(features);

        expect(result, hasLength(3));
        expect(result![0], equals("escalator"));
        expect(result[1], equals("elevator"));
        expect(result[2], equals("wheelChairAccess"));
      });

      test("converts all BuildingFeature types to strings", () {
        const features = [
          BuildingFeature.escalator,
          BuildingFeature.elevator,
          BuildingFeature.wheelChairAccess,
          BuildingFeature.bathroom,
          BuildingFeature.shuttleBus,
          BuildingFeature.metroAccess,
          BuildingFeature.food,
        ];

        final result = converter.toJson(features);

        expect(result, hasLength(7));
        expect(result![0], equals("escalator"));
        expect(result[1], equals("elevator"));
        expect(result[2], equals("wheelChairAccess"));
        expect(result[3], equals("bathroom"));
        expect(result[4], equals("shuttleBus"));
        expect(result[5], equals("metroAccess"));
        expect(result[6], equals("food"));
      });

      test("returns null for null input", () {
        final result = converter.toJson(null);
        expect(result, isNull);
      });

      test("returns empty list for empty input", () {
        const features = <BuildingFeature>[];
        final result = converter.toJson(features);
        expect(result, isEmpty);
      });

      test("handles single feature", () {
        const features = [BuildingFeature.elevator];
        final result = converter.toJson(features);

        expect(result, hasLength(1));
        expect(result![0], equals("elevator"));
      });
    });

    group("round-trip conversion", () {
      test("fromJson and toJson are inverse operations", () {
        const originalFeatures = [
          BuildingFeature.escalator,
          BuildingFeature.elevator,
          BuildingFeature.wheelChairAccess,
          BuildingFeature.bathroom,
        ];

        final json = converter.toJson(originalFeatures);
        final restored = converter.fromJson(json);

        expect(restored, equals(originalFeatures));
      });

      test("null round-trip", () {
        final json = converter.toJson(null);
        final restored = converter.fromJson(json);

        expect(restored, isNull);
      });

      test("empty list round-trip", () {
        const originalFeatures = <BuildingFeature>[];
        final json = converter.toJson(originalFeatures);
        final restored = converter.fromJson(json);

        expect(restored, isEmpty);
      });
    });
  });
}
