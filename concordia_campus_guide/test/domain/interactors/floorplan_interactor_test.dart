import "package:concordia_campus_guide/data/repositories/floorplan_repository.dart";
import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/domain/models/floorplan.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "floorplan_interactor_test.mocks.dart";

@GenerateMocks([FloorplanRepository])
void main() {
  group("Floorplan Interactor", () {
    test("loadFloorplans returns an empty list when no floorplans are found", () async {
      final mockRepo = MockFloorplanRepository();

      when(mockRepo.loadBuildingFloorplans(any)).thenAnswer((_) async => {});

      final interactor = FloorplanInteractor(floorplanRepo: mockRepo);
      final response = await interactor.loadFloorplans("nonexistent/id");

      expect(response, isEmpty);
    });

    test("loadFloorplans forwards the floorplans when they are found", () async {
      final mockRepo = MockFloorplanRepository();
      final mockFloorplans = {
        1: Floorplan(buildingId: "cl", floorNumber: 1, svgPath: "cl-1.svg", rooms: []),
      };

      when(mockRepo.loadBuildingFloorplans(any)).thenAnswer((_) async => mockFloorplans);

      final interactor = FloorplanInteractor(floorplanRepo: mockRepo);
      final response = await interactor.loadFloorplans("valid/id");

      expect(response, equals(mockFloorplans));
    });

    test("loadRoomNames returns an empty list when no floorplans are found", () async {
      final mockRepo = MockFloorplanRepository();

      when(mockRepo.loadRoomNames()).thenAnswer((_) async => []);

      final interactor = FloorplanInteractor(floorplanRepo: mockRepo);
      final response = await interactor.loadRoomNames();

      expect(response, isEmpty);
    });

    test("loadRoomNames forwards the room names when they are found", () async {
      final mockRepo = MockFloorplanRepository();
      final mockRoomNames = ["T 1", "T 2", "T 3"];

      when(mockRepo.loadRoomNames()).thenAnswer((_) async => mockRoomNames);

      final interactor = FloorplanInteractor(floorplanRepo: mockRepo);
      final response = await interactor.loadRoomNames();

      expect(response, equals(mockRoomNames));
    });
  });
}
