import "dart:developer" as developer;
import "dart:math";

import "package:concordia_campus_guide/domain/models/floorplan.dart";

const double _centerBiasStrength = 8.0;
const double _minClearanceForCenterBias = 1.0;

// Single-floor path segment used in multi-floor routes

class IndoorFloorPathSegment {
  final String floorNumber;

  final List<Point<double>> path;

  final FloorTransition? exitTransition;

  final FloorTransition? entryTransition;

  const IndoorFloorPathSegment({
    required this.floorNumber,
    required this.path,
    this.exitTransition,
    this.entryTransition,
  });
}

class IndoorShortestPathDebugResult {
  final List<Point<double>> path;
  final List<Point<double>> traversedNodes;

  const IndoorShortestPathDebugResult({required this.path, required this.traversedNodes});
}

class _GridPathResult {
  final List<Point<double>> path;
  final List<Point<double>> traversed;

  const _GridPathResult({required this.path, required this.traversed});
}

extension FloorplanPathfinding on Floorplan {
  _GridPathResult _computeIndoorGridPathOrThrow({
    required final Point<double> startPoint,
    required final Point<double> endPoint,
    required final String emptyCorridorsErrorDetails,
    required final String noPathDescription,
    required final String noPathErrorDetails,
  }) {
    if (corridors.isEmpty) {
      const description = "No indoor corridors available for pathfinding.";
      developer.log(description, name: "IndoorPathfinding", error: emptyCorridorsErrorDetails);
      throw StateError(description);
    }

    final gridResult = _computeIndoorShortestPathOnWalkableGrid(
      corridors: corridors,
      startPoint: startPoint,
      endPoint: endPoint,
    );

    if (gridResult.path.isEmpty) {
      developer.log(noPathDescription, name: "IndoorPathfinding", error: noPathErrorDetails);
      throw StateError(noPathDescription);
    }

    return gridResult;
  }

  _GridPathResult _shortestPathBetweenRoomsGridResult(
    final IndoorMapRoom startRoom,
    final IndoorMapRoom endRoom,
  ) {
    return _computeIndoorGridPathOrThrow(
      startPoint: startRoom.doorLocation,
      endPoint: endRoom.doorLocation,
      emptyCorridorsErrorDetails:
          "building=$buildingId floor=$floorNumber start=${startRoom.name} end=${endRoom.name}",
      noPathDescription:
          "No indoor path found between rooms ${startRoom.name} and ${endRoom.name}.",
      noPathErrorDetails:
          "building=$buildingId floor=$floorNumber start=${startRoom.name} end=${endRoom.name} startDoor=${startRoom.doorLocation} endDoor=${endRoom.doorLocation} corridors=${corridors.length}",
    );
  }

  List<Point<double>> shortestPathBetweenRooms(
    final IndoorMapRoom startRoom,
    final IndoorMapRoom endRoom,
  ) {
    return _shortestPathBetweenRoomsGridResult(startRoom, endRoom).path;
  }

  IndoorShortestPathDebugResult shortestPathBetweenRoomsWithDebug(
    final IndoorMapRoom startRoom,
    final IndoorMapRoom endRoom,
  ) {
    final gridResult = _shortestPathBetweenRoomsGridResult(startRoom, endRoom);

    return IndoorShortestPathDebugResult(
      path: gridResult.path,
      traversedNodes: gridResult.traversed,
    );
  }

  /// Computes the path from a room's door to a specific transition point on this floor.
  List<Point<double>> shortestPathToTransition(
    final Point<double> startPoint,
    final FloorTransition transition,
  ) {
    final gridResult = _computeIndoorGridPathOrThrow(
      startPoint: startPoint,
      endPoint: transition.location,
      emptyCorridorsErrorDetails:
          "building=$buildingId floor=$floorNumber transition=${transition.id} startPoint=$startPoint",
      noPathDescription:
          "No indoor path found to transition ${transition.id} on floor $floorNumber.",
      noPathErrorDetails:
          "building=$buildingId floor=$floorNumber transition=${transition.id} startPoint=$startPoint",
    );

    return gridResult.path;
  }
}

List<IndoorFloorPathSegment> computeInterFloorPath({
  required final Map<String, Floorplan> floorplans,
  required final String startFloor,
  required final String destinationFloor,
  required final IndoorMapRoom startRoom,
  required final IndoorMapRoom destinationRoom,
  final TransitionType? preferredTransitionType,
  final bool accessibleMode = false,
}) {
  if (startFloor == destinationFloor) {
    final floorplan = floorplans[startFloor]!;
    final path = floorplan.shortestPathBetweenRooms(startRoom, destinationRoom);
    return [IndoorFloorPathSegment(floorNumber: startFloor, path: path)];
  }

  final floorsToTraverse = _computeFloorsToTraverse(floorplans, startFloor, destinationFloor);

  // Build segments floor by floor.
  final List<IndoorFloorPathSegment> segments = [];
  Point<double> currentStartPoint = startRoom.doorLocation;

  for (int i = 0; i < floorsToTraverse.length - 1; i++) {
    currentStartPoint = _appendSegmentForFloorPair(
      floorplans: floorplans,
      preferredTransitionType: preferredTransitionType,
      accessibleMode: accessibleMode,
      floorsToTraverse: floorsToTraverse,
      segments: segments,
      index: i,
      currentStartPoint: currentStartPoint,
    );
  }

  _appendFinalDestinationSegment(
    floorplans: floorplans,
    destinationFloor: destinationFloor,
    destinationRoom: destinationRoom,
    segments: segments,
  );

  return segments;
}

void _appendFinalDestinationSegment({
  required final Map<String, Floorplan> floorplans,
  required final String destinationFloor,
  required final IndoorMapRoom destinationRoom,
  required final List<IndoorFloorPathSegment> segments,
}) {
  final destFloorplan = floorplans[destinationFloor]!;
  final lastExitTransition = segments.last.exitTransition!;

  final entryTransition = destFloorplan.transitions.firstWhere(
    (final t) => t.groupTag == lastExitTransition.groupTag,
    orElse: () {
      final description = "No matching entry transition on floor $destinationFloor.";
      developer.log(
        description,
        name: "IndoorPathfinding",
        error: "destinationFloor=$destinationFloor lastExitGroupTag=${lastExitTransition.groupTag}",
      );
      throw StateError(description);
    },
  );

  try {
    final destPath = destFloorplan.shortestPathToTransition(
      entryTransition.location,
      FloorTransition(
        id: "dest-room",
        location: destinationRoom.doorLocation,
        type: TransitionType.stairs,
        groupTag: "",
      ),
    );
    segments.add(
      IndoorFloorPathSegment(
        floorNumber: destinationFloor,
        path: destPath,
        entryTransition: entryTransition,
      ),
    );
  } on StateError {
    final description =
        "No path found from transition to room ${destinationRoom.name} "
        "on floor $destinationFloor.";
    developer.log(
      description,
      name: "IndoorPathfinding",
      error: "destinationFloor=$destinationFloor room=${destinationRoom.name}",
    );
    throw StateError(description);
  }
}

Point<double> _appendSegmentForFloorPair({
  required final Map<String, Floorplan> floorplans,
  required final TransitionType? preferredTransitionType,
  required final bool accessibleMode,
  required final List<String> floorsToTraverse,
  required final List<IndoorFloorPathSegment> segments,
  required final int index,
  required final Point<double> currentStartPoint,
}) {
  final currentFloorNum = floorsToTraverse[index];
  final nextFloorNum = floorsToTraverse[index + 1];
  final currentFloorplan = floorplans[currentFloorNum]!;
  final nextFloorplan = floorplans[nextFloorNum]!;

  final allCandidates = _findMatchingTransitions(
    currentFloorplan.transitions,
    nextFloorplan.transitions,
    preferredTransitionType,
  );

  if (allCandidates.isEmpty) {
    final description =
        "No connecting transition found between floor $currentFloorNum "
        "and floor $nextFloorNum.";
    developer.log(
      description,
      name: "IndoorPathfinding",
      error:
          "currentFloor=$currentFloorNum nextFloor=$nextFloorNum "
          "currentTransitions=${currentFloorplan.transitions.length} "
          "nextTransitions=${nextFloorplan.transitions.length} "
          "preferredType=$preferredTransitionType",
    );
    throw StateError(description);
  }

  List<_TransitionCandidate> candidates = allCandidates;

  if (accessibleMode) {
    final nonStairs = allCandidates
        .where(
          (final c) =>
              c.fromTransition.type != TransitionType.stairs &&
              c.toTransition.type != TransitionType.stairs &&
              c.fromTransition.type != TransitionType.escalator &&
              c.toTransition.type != TransitionType.escalator,
        )
        .toList();

    if (nonStairs.isNotEmpty) {
      candidates = nonStairs;
    }
  }

  _TransitionCandidate? bestCandidate;
  List<Point<double>>? bestPath;
  double bestCost = double.infinity;

  for (final candidate in candidates) {
    try {
      final path = currentFloorplan.shortestPathToTransition(
        currentStartPoint,
        candidate.fromTransition,
      );
      final cost = _pathLength(path);
      if (cost < bestCost) {
        bestCost = cost;
        bestPath = path;
        bestCandidate = candidate;
      }
    } on StateError {
      continue;
    }
  }

  if (bestCandidate == null || bestPath == null) {
    final description =
        "No reachable transition found on floor $currentFloorNum "
        "to reach floor $nextFloorNum.";
    developer.log(
      description,
      name: "IndoorPathfinding",
      error:
          "currentFloor=$currentFloorNum nextFloor=$nextFloorNum preferredType=$preferredTransitionType",
    );
    throw StateError(description);
  }

  segments.add(
    IndoorFloorPathSegment(
      floorNumber: currentFloorNum,
      path: bestPath,
      exitTransition: bestCandidate.fromTransition,
      entryTransition: index > 0 ? segments.last.exitTransition : null,
    ),
  );

  return bestCandidate.toTransition.location;
}

List<String> _computeFloorsToTraverse(
  final Map<String, Floorplan> floorplans,
  final String startFloor,
  final String destinationFloor,
) {
  int floorSortKey(final String key) {
    final digits = key.replaceAll(RegExp(r"[^0-9]"), "");
    return digits.isNotEmpty ? int.parse(digits) : 0;
  }

  final allKeys = floorplans.keys.toList()
    ..sort((final a, final b) => floorSortKey(a).compareTo(floorSortKey(b)));

  final startIdx = allKeys.indexOf(startFloor);
  final destIdx = allKeys.indexOf(destinationFloor);

  final List<String> floorsToTraverse;
  if (startIdx <= destIdx) {
    floorsToTraverse = allKeys.sublist(startIdx, destIdx + 1);
  } else {
    floorsToTraverse = allKeys.sublist(destIdx, startIdx + 1).reversed.toList();
  }

  if (floorsToTraverse.length < 2) {
    final description =
        "Cannot navigate between floor $startFloor and floor $destinationFloor: "
        "insufficient floorplan data.";
    developer.log(
      description,
      name: "IndoorPathfinding",
      error:
          "startFloor=$startFloor destinationFloor=$destinationFloor availableFloors=${floorplans.keys.toList()}",
    );
    throw StateError(description);
  }
  return floorsToTraverse;
}

// Inter-floor helpers

class _TransitionCandidate {
  final FloorTransition fromTransition;
  final FloorTransition toTransition;

  const _TransitionCandidate({required this.fromTransition, required this.toTransition});
}

/// Finds transition pairs that connect two floors by matching their transition type
List<_TransitionCandidate> _findMatchingTransitions(
  final List<FloorTransition> fromFloorTransitions,
  final List<FloorTransition> toFloorTransitions,
  final TransitionType? preferredType,
) {
  final Map<String, FloorTransition> toTransitionsByGroup = {
    for (final t in toFloorTransitions) t.groupTag: t,
  };

  final List<_TransitionCandidate> preferred = [];
  final List<_TransitionCandidate> others = [];

  for (final fromTransition in fromFloorTransitions) {
    final toTransition = toTransitionsByGroup[fromTransition.groupTag];
    if (toTransition == null) {
      continue;
    }

    final transitionCandidate = _TransitionCandidate(
      fromTransition: fromTransition,
      toTransition: toTransition,
    );

    if (preferredType != null && fromTransition.type == preferredType) {
      preferred.add(transitionCandidate);
    } else {
      others.add(transitionCandidate);
    }
  }

  return [...preferred, ...others];
}

/// Computes the total  length of a polyline path.
double _pathLength(final List<Point<double>> path) {
  double total = 0;
  for (int i = 0; i < path.length - 1; i++) {
    total += _euclideanDistanceBtwnPoints(path[i], path[i + 1]);
  }
  return total;
}

double _euclideanDistanceBtwnPoints(final Point<double> a, final Point<double> b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return sqrt(dx * dx + dy * dy);
}

double _distanceToNearestCorridorBoundary(final Point<double> p, final List<Corridor> corridors) {
  var minDistance = double.infinity;

  for (final corridor in corridors) {
    final polygon = corridor.bounds;
    if (polygon.length < 2) {
      continue;
    }

    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      final distance = _distancePointToSegment(p, a, b);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
  }

  return minDistance.isFinite ? minDistance : 0;
}

double _distancePointToSegment(
  final Point<double> p,
  final Point<double> a,
  final Point<double> b,
) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final lenSq = dx * dx + dy * dy;

  if (lenSq == 0) {
    return _euclideanDistanceBtwnPoints(p, a);
  }

  final t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq;
  final clampedT = t.clamp(0.0, 1.0);
  final projection = Point<double>(a.x + dx * clampedT, a.y + dy * clampedT);
  return _euclideanDistanceBtwnPoints(p, projection);
}

_GridPathResult _computeIndoorShortestPathOnWalkableGrid({
  required final List<Corridor> corridors,
  required final Point<double> startPoint,
  required final Point<double> endPoint,
}) {
  final validCorridors = corridors.where((final c) => c.bounds.length >= 3).toList(growable: false);
  if (validCorridors.isEmpty) {
    return const _GridPathResult(path: <Point<double>>[], traversed: <Point<double>>[]);
  }

  final bounds = _computeCorridorBounds(validCorridors);
  const cellSize = 8.0;
  final originX = bounds.minX - cellSize;
  final originY = bounds.minY - cellSize;
  final cols = max(3, ((bounds.maxX - bounds.minX) / cellSize).ceil() + 3);
  final rows = max(3, ((bounds.maxY - bounds.minY) / cellSize).ceil() + 3);

  Point<double> cellCenter(final int row, final int col) =>
      Point<double>(originX + (col + 0.5) * cellSize, originY + (row + 0.5) * cellSize);

  final walkable = _buildWalkable(rows, cols, cellCenter, validCorridors);

  final clearance = _buildClearance(rows, cols, walkable, cellCenter, validCorridors);

  final startCell = _nearestWalkableCell(
    startPoint,
    rows,
    cols,
    walkable,
    cellCenter,
    originX,
    originY,
    cellSize,
  );

  final endCell = _nearestWalkableCell(
    endPoint,
    rows,
    cols,
    walkable,
    cellCenter,
    originX,
    originY,
    cellSize,
  );

  if (startCell == null || endCell == null) {
    return const _GridPathResult(path: <Point<double>>[], traversed: <Point<double>>[]);
  }

  int id(final int row, final int col) => row * cols + col;
  (int row, int col) decode(final int nodeId) => (nodeId ~/ cols, nodeId % cols);

  final startId = id(startCell.$1, startCell.$2);
  final endId = id(endCell.$1, endCell.$2);
  final total = rows * cols;

  final g = List<double>.filled(total, double.infinity);
  final f = List<double>.filled(total, double.infinity);
  final prev = List<int?>.filled(total, null);
  final open = <int>[];
  final openSet = List<bool>.filled(total, false);
  final closed = List<bool>.filled(total, false);
  final traversed = <Point<double>>[];

  double heuristic(final int nodeId) {
    final (r, c) = decode(nodeId);
    final (er, ec) = decode(endId);
    final dr = (r - er).abs().toDouble();
    final dc = (c - ec).abs().toDouble();
    return sqrt(dr * dr + dc * dc) * cellSize;
  }

  g[startId] = 0;
  f[startId] = heuristic(startId);
  open.add(startId);
  openSet[startId] = true;

  const neighborOffsets = <(int dr, int dc, double scale)>[
    (-1, 0, 1.0),
    (1, 0, 1.0),
    (0, -1, 1.0),
    (0, 1, 1.0),
    (-1, -1, 1.41421356237),
    (-1, 1, 1.41421356237),
    (1, -1, 1.41421356237),
    (1, 1, 1.41421356237),
  ];

  while (open.isNotEmpty) {
    var bestIndex = 0;
    var bestF = f[open[0]];
    for (var i = 1; i < open.length; i++) {
      final cand = open[i];
      if (f[cand] < bestF) {
        bestF = f[cand];
        bestIndex = i;
      }
    }

    final current = open.removeAt(bestIndex);
    openSet[current] = false;
    if (closed[current]) {
      continue;
    }
    closed[current] = true;

    final (cr, cc) = decode(current);
    traversed.add(cellCenter(cr, cc));

    if (current == endId) {
      break;
    }

    for (final (dr, dc, scale) in neighborOffsets) {
      final nr = cr + dr;
      final nc = cc + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) {
        continue;
      }
      if (!walkable[nr][nc]) {
        continue;
      }

      final neighbor = id(nr, nc);
      if (closed[neighbor]) {
        continue;
      }

      final edgeBase = cellSize * scale;
      final edgeClearance = min(clearance[cr][cc], clearance[nr][nc]);
      final effectiveClearance = max(_minClearanceForCenterBias, edgeClearance);
      final stepCost = edgeBase * (1 + (_centerBiasStrength / effectiveClearance));

      final tentative = g[current] + stepCost;
      if (tentative < g[neighbor]) {
        g[neighbor] = tentative;
        prev[neighbor] = current;
        f[neighbor] = tentative + heuristic(neighbor);

        if (!openSet[neighbor]) {
          open.add(neighbor);
          openSet[neighbor] = true;
        }
      }
    }
  }

  if (startId != endId && prev[endId] == null) {
    return _GridPathResult(path: const <Point<double>>[], traversed: traversed);
  }

  final reverseIds = <int>[];
  int? cursor = endId;
  while (cursor != null) {
    reverseIds.add(cursor);
    if (cursor == startId) {
      break;
    }
    cursor = prev[cursor];
  }
  final ids = reverseIds.reversed.toList(growable: false);
  final coarsePath = ids
      .map((final nodeId) {
        final (r, c) = decode(nodeId);
        return cellCenter(r, c);
      })
      .toList(growable: false);

  final smoothed = coarsePath;
  final finalPath = <Point<double>>[startPoint];
  for (var i = 1; i < smoothed.length - 1; i++) {
    finalPath.add(smoothed[i]);
  }
  if (startPoint != endPoint) {
    finalPath.add(endPoint);
  }

  return _GridPathResult(path: finalPath, traversed: traversed);
}

List<List<bool>> _buildWalkable(
  final int rows,
  final int cols,
  final Point<double> Function(int, int) cellCenter,
  final List<Corridor> validCorridors,
) {
  final walkable = List<List<bool>>.generate(
    rows,
    (_) => List<bool>.filled(cols, false),
    growable: false,
  );

  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      walkable[r][c] = _pointInsideAnyCorridorOrBoundary(cellCenter(r, c), validCorridors);
    }
  }

  return walkable;
}

List<List<double>> _buildClearance(
  final int rows,
  final int cols,
  final List<List<bool>> walkable,
  final Point<double> Function(int, int) cellCenter,
  final List<Corridor> validCorridors,
) {
  final clearance = List<List<double>>.generate(
    rows,
    (_) => List<double>.filled(cols, 0),
    growable: false,
  );

  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (!walkable[r][c]) continue;

      clearance[r][c] = _distanceToNearestCorridorBoundary(cellCenter(r, c), validCorridors);
    }
  }

  return clearance;
}

(int row, int col)? _nearestWalkableCell(
  final Point<double> p,
  final int rows,
  final int cols,
  final List<List<bool>> walkable,
  final Point<double> Function(int, int) cellCenter,
  final double originX,
  final double originY,
  final double cellSize,
) {
  final approxCol = ((p.x - originX) / cellSize).floor();
  final approxRow = ((p.y - originY) / cellSize).floor();

  if (approxRow >= 0 && approxRow < rows && approxCol >= 0 && approxCol < cols) {
    if (walkable[approxRow][approxCol]) {
      return (approxRow, approxCol);
    }
  }

  double best = double.infinity;
  int? bestRow;
  int? bestCol;

  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (!walkable[r][c]) continue;

      final pCenter = cellCenter(r, c);
      final dx = pCenter.x - p.x;
      final dy = pCenter.y - p.y;
      final d2 = dx * dx + dy * dy;

      if (d2 < best) {
        best = d2;
        bestRow = r;
        bestCol = c;
      }
    }
  }

  if (bestRow == null || bestCol == null) {
    return null;
  }

  return (bestRow, bestCol);
}

bool _pointInsideAnyCorridorOrBoundary(final Point<double> p, final List<Corridor> corridors) {
  for (final corridor in corridors) {
    if (_pointInPolygon(p, corridor.bounds) || _pointOnPolygonBoundary(p, corridor.bounds)) {
      return true;
    }
  }
  return false;
}

({double minX, double minY, double maxX, double maxY}) _computeCorridorBounds(
  final List<Corridor> corridors,
) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;

  for (final corridor in corridors) {
    for (final p in corridor.bounds) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
  }

  return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

bool _pointOnPolygonBoundary(final Point<double> point, final List<Point<double>> polygon) {
  if (polygon.length < 2) {
    return false;
  }

  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    if (_pointOnSegment(point, a, b)) {
      return true;
    }
  }

  return false;
}

bool _pointOnSegment(final Point<double> p, final Point<double> a, final Point<double> b) {
  const epsilon = 1e-6;

  final cross = (p.y - a.y) * (b.x - a.x) - (p.x - a.x) * (b.y - a.y);
  if (cross.abs() > epsilon) {
    return false;
  }

  final dot = (p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y);
  if (dot < -epsilon) {
    return false;
  }

  final lenSq = (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y);
  if (dot - lenSq > epsilon) {
    return false;
  }

  return true;
}

/// Even–odd point-in-polygon test.
bool _pointInPolygon(final Point<double> point, final List<Point<double>> polygon) {
  if (polygon.length < 3) {
    return false;
  }

  var inside = false;
  for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].x;
    final yi = polygon[i].y;
    final xj = polygon[j].x;
    final yj = polygon[j].y;

    final intersect =
        ((yi > point.y) != (yj > point.y)) &&
        (point.x < (xj - xi) * (point.y - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);
    if (intersect) {
      inside = !inside;
    }
  }

  return inside;
}
