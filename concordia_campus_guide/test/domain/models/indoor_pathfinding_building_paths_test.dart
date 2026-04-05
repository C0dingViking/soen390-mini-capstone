import "dart:io";

import "package:concordia_campus_guide/data/repositories/floorplan_repository.dart";
import "package:concordia_campus_guide/domain/models/indoor_pathfinding.dart";
import "package:flutter_test/flutter_test.dart";
import "package:logger/logger.dart";

int _floorSortKey(final String floorNumber) {
  final digits = floorNumber.replaceAll(RegExp(r"[^0-9]"), "");
  return digits.isNotEmpty ? int.parse(digits) : 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FloorplanRepository repository;

  setUpAll(() {
    Logger.level = Level.off;
    repository = FloorplanRepository(
      floorplanLoader: (final path) async => File(path).readAsString(),
    );
  });

  Future<void> expectEveryRoomPairConnected(final String buildingId) async {
    final floorplans = await repository.loadBuildingFloorplans(buildingId);

    expect(floorplans, isNotEmpty, reason: "No floorplans were loaded for building $buildingId.");

    final floorNumbers = floorplans.keys.toList()
      ..sort((final a, final b) => _floorSortKey(a).compareTo(_floorSortKey(b)));

    for (final floorNumber in floorNumbers) {
      final floorplan = floorplans[floorNumber]!;
      final rooms = floorplan.rooms;

      expect(
        rooms,
        isNotEmpty,
        reason: "No rooms were found for building $buildingId floor $floorNumber.",
      );

      for (var i = 0; i < rooms.length; i++) {
        for (var j = i + 1; j < rooms.length; j++) {
          final startRoom = rooms[i];
          final destinationRoom = rooms[j];

          final path = floorplan.shortestPathBetweenRooms(startRoom, destinationRoom);

          expect(
            path,
            isNotEmpty,
            reason:
                "No path found in building $buildingId floor $floorNumber between rooms ${startRoom.name} and ${destinationRoom.name}.",
          );
          expect(
            path.first,
            startRoom.doorLocation,
            reason:
                "Path in building $buildingId floor $floorNumber does not start at room ${startRoom.name}.",
          );
          expect(
            path.last,
            destinationRoom.doorLocation,
            reason:
                "Path in building $buildingId floor $floorNumber does not end at room ${destinationRoom.name}.",
          );
        }
      }
    }
  }

  group("Indoor navigation building coverage", () {
    test("MB has a path between every room pair on every floor", () async {
      await expectEveryRoomPairConnected("mb");
    });

    test("H has a path between every room pair on every floor", () async {
      await expectEveryRoomPairConnected("h");
    });

    test("VL has a path between every room pair on every floor", () async {
      await expectEveryRoomPairConnected("vl");
    });

    test("CC has a path between every room pair on every floor", () async {
      await expectEveryRoomPairConnected("cc");
    });

    test("LB has a path between every room pair on every floor", () async {
      await expectEveryRoomPairConnected("lb");
    });

    test("VE has a path between every room pair on every floor", () async {
      await expectEveryRoomPairConnected("ve");
    });
  });
}
