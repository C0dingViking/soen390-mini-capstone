import "dart:developer" as developer;
import "dart:math";

import "package:concordia_campus_guide/domain/models/floorplan.dart";

class _IndoorGraphNode {
  final Point<double> position;
  final List<_IndoorGraphEdge> edges = <_IndoorGraphEdge>[];

  _IndoorGraphNode(this.position);
}

class _IndoorGraphEdge {
  final int to;
  final double weight;

  const _IndoorGraphEdge(this.to, this.weight);
}

class _IndoorGraph {
  final List<_IndoorGraphNode> nodes;
  final List<List<int>> corridorVertexNodeIds;
  final List<List<int>> corridorAllNodeIds;

  _IndoorGraph({
    required this.nodes,
    required this.corridorVertexNodeIds,
    required this.corridorAllNodeIds,
  });

  /// Builds a navigation graph from corridor polygons.
  factory _IndoorGraph.fromCorridors(final List<Corridor> corridors) {
    final List<_IndoorGraphNode> nodes = <_IndoorGraphNode>[];
    final Map<String, int> coordinateToNodeId = <String, int>{};
    final List<List<int>> corridorAllNodeIds = <List<int>>[];

    int getOrCreateNodeId(final Point<double> p) {
      final key = "${p.x.toStringAsFixed(3)}:${p.y.toStringAsFixed(3)}";
      final existing = coordinateToNodeId[key];
      if (existing != null) {
        return existing;
      }

      final id = nodes.length;
      nodes.add(_IndoorGraphNode(p));
      coordinateToNodeId[key] = id;
      return id;
    }
    final corridorVertexNodeIds = _createCorridorVertexNodes(
      corridors,
      getOrCreateNodeId,
      corridorAllNodeIds,
    );

    _connectCorridorEdges(nodes, corridorVertexNodeIds);
    _snapNearbyVertices(nodes);
    _addCorridorInteriorPoints(corridors, corridorAllNodeIds, getOrCreateNodeId);
    _addGlobalVisibilityEdges(nodes, corridorAllNodeIds, corridors);

    return _IndoorGraph(
      nodes: nodes,
      corridorVertexNodeIds: corridorVertexNodeIds,
      corridorAllNodeIds: corridorAllNodeIds,
    );
  }

  /// Adds a door node and connects it to the corridor graph.
  int addDoorNode(final Point<double> door, final List<Corridor> corridors) {
    final doorNodeId = nodes.length;
    nodes.add(_IndoorGraphNode(door));

    var containingCorridorIndex = -1;
    for (var i = 0; i < corridors.length; i++) {
      if (_pointInPolygon(door, corridors[i].bounds)) {
        containingCorridorIndex = i;
        break;
      }
    }

    if (containingCorridorIndex < 0 && corridors.isNotEmpty) {
      const double snapThreshold = 20.0;

      double bestCorridorDistance = double.infinity;
      int? bestCorridorIndex;

      for (var i = 0; i < corridors.length; i++) {
        final corridor = corridors[i];
        for (final point in corridor.bounds) {
          final d = _euclideanDistance(door, point);
          if (d < bestCorridorDistance) {
            bestCorridorDistance = d;
            bestCorridorIndex = i;
          }
        }
      }

      if (bestCorridorIndex != null && bestCorridorDistance <= snapThreshold) {
        containingCorridorIndex = bestCorridorIndex;
      }
    }

    Iterable<int> candidateVertexIds;
    if (containingCorridorIndex >= 0) {
      candidateVertexIds = corridorAllNodeIds[containingCorridorIndex];
    } else {
      candidateVertexIds = Iterable<int>.generate(doorNodeId);
    }

    double bestDistance = double.infinity;
    int? bestVertexId;

    for (final vertexId in candidateVertexIds) {
      final vertexPoint = nodes[vertexId].position;
      final d = _euclideanDistance(door, vertexPoint);
      if (d < bestDistance) {
        bestDistance = d;
        bestVertexId = vertexId;
      }
    }

    if (bestVertexId != null && bestDistance > 0) {
      nodes[doorNodeId].edges.add(_IndoorGraphEdge(bestVertexId, bestDistance));
      nodes[bestVertexId].edges.add(_IndoorGraphEdge(doorNodeId, bestDistance));
    }

    return doorNodeId;
  }
}

// ---------------------------------------------------------------------------
// Single-floor path segment used in multi-floor routes
// ---------------------------------------------------------------------------

/// Represents the path on a single floor as part of a multi-floor route.
class IndoorFloorPathSegment {
  /// The floor number this segment belongs to.
  final int floorNumber;

  /// Ordered list of points forming the path on this floor.
  final List<Point<double>> path;

  /// The transition used to leave this floor (null for the final segment).
  final FloorTransition? exitTransition;

  /// The transition used to enter this floor (null for the first segment).
  final FloorTransition? entryTransition;

  const IndoorFloorPathSegment({
    required this.floorNumber,
    required this.path,
    this.exitTransition,
    this.entryTransition,
  });
}

/// Computes the shortest indoor path between two rooms.
extension FloorplanPathfinding on Floorplan {
  List<Point<double>> shortestPathBetweenRooms(
    final IndoorMapRoom startRoom,
    final IndoorMapRoom endRoom,
  ) {
    if (corridors.isEmpty) {
      developer.log(
        "Indoor pathfinding error: no corridors available",
        name: "IndoorPathfinding",
        error:
            "building=$buildingId floor=$floorNumber start=${startRoom.name} end=${endRoom.name}",
      );
      throw StateError("No indoor corridors available for pathfinding.");
    }

    final graph = _IndoorGraph.fromCorridors(corridors);

    final startId = graph.addDoorNode(startRoom.doorLocation, corridors);
    final endId = graph.addDoorNode(endRoom.doorLocation, corridors);

    final pathNodeIds = _dijkstra(graph, startId, endId);

    if (pathNodeIds.isEmpty) {
      developer.log(
        "Indoor pathfinding error: no path found between rooms",
        name: "IndoorPathfinding",
        error:
            "building=$buildingId floor=$floorNumber start=${startRoom.name} end=${endRoom.name} startDoor=${startRoom.doorLocation} endDoor=${endRoom.doorLocation} corridors=${corridors.length}",
      );
      throw StateError("No indoor path found between rooms ${startRoom.name} and ${endRoom.name}.");
    }

    return pathNodeIds.map((final id) => graph.nodes[id].position).toList(growable: false);
  }

  /// Computes the path from a room's door to a specific transition point on this floor.
  List<Point<double>> shortestPathToTransition(
    final Point<double> startPoint,
    final FloorTransition transition,
  ) {
    if (corridors.isEmpty) {
      throw StateError("No indoor corridors available for pathfinding.");
    }

    final graph = _IndoorGraph.fromCorridors(corridors);

    final startId = graph.addDoorNode(startPoint, corridors);
    final endId = graph.addDoorNode(transition.location, corridors);

    final pathNodeIds = _dijkstra(graph, startId, endId);

    if (pathNodeIds.isEmpty) {
      throw StateError(
        "No indoor path found to transition ${transition.id} on floor $floorNumber.",
      );
    }

    return pathNodeIds.map((final id) => graph.nodes[id].position).toList(growable: false);
  }
}

// ---------------------------------------------------------------------------
// Inter-floor pathfinding
// ---------------------------------------------------------------------------

/// Computes a multi-floor route between rooms on different floors.
///
/// The algorithm:
/// 1. Finds transitions shared between the start and destination floors
///    (matched by [FloorTransition.groupTag]).
/// 2. For each candidate transition pair, computes the path on the start floor
///    (start room → transition) and the path on the destination floor
///    (transition → destination room).
/// 3. Picks the pair with the smallest combined path cost.
///
/// For routes spanning more than two floors (e.g. floor 1 → floor 3), the
/// method chains through intermediate floors by finding a transition that
/// connects each consecutive floor pair.
///
/// Returns a list of [IndoorFloorPathSegment]s, one per floor traversed,
/// in order from start to destination.
///
/// Throws [StateError] if no connecting transitions exist between the
/// required floors.
List<IndoorFloorPathSegment> computeInterFloorPath({
  required final Map<int, Floorplan> floorplans,
  required final int startFloor,
  required final int destinationFloor,
  required final IndoorMapRoom startRoom,
  required final IndoorMapRoom destinationRoom,
  final TransitionType? preferredTransitionType,
}) {
  if (startFloor == destinationFloor) {
    // Same-floor case: delegate to the existing single-floor pathfinding.
    final floorplan = floorplans[startFloor]!;
    final path = floorplan.shortestPathBetweenRooms(startRoom, destinationRoom);
    return [
      IndoorFloorPathSegment(floorNumber: startFloor, path: path),
    ];
  }

  // Determine the ordered list of floors to traverse.
  final int direction = destinationFloor > startFloor ? 1 : -1;
  final List<int> floorsToTraverse = [];
  for (int f = startFloor; f != destinationFloor + direction; f += direction) {
    if (!floorplans.containsKey(f)) {
      continue; // skip floors that don't have a floorplan
    }
    floorsToTraverse.add(f);
  }

  if (floorsToTraverse.length < 2) {
    throw StateError(
      "Cannot navigate between floor $startFloor and floor $destinationFloor: "
      "insufficient floorplan data.",
    );
  }

  // Build segments floor-by-floor.
  final List<IndoorFloorPathSegment> segments = [];
  Point<double> currentStartPoint = startRoom.doorLocation;

  for (int i = 0; i < floorsToTraverse.length - 1; i++) {
    final currentFloorNum = floorsToTraverse[i];
    final nextFloorNum = floorsToTraverse[i + 1];
    final currentFloorplan = floorplans[currentFloorNum]!;
    final nextFloorplan = floorplans[nextFloorNum]!;

    // Find matching transition pairs between these two floors.
    final candidates = _findMatchingTransitions(
      currentFloorplan.transitions,
      nextFloorplan.transitions,
      preferredTransitionType,
    );

    if (candidates.isEmpty) {
      throw StateError(
        "No connecting transition found between floor $currentFloorNum "
        "and floor $nextFloorNum.",
      );
    }

    // Evaluate each candidate pair and pick the shortest combined path.
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
        // This transition isn't reachable; try the next candidate.
        continue;
      }
    }

    if (bestCandidate == null || bestPath == null) {
      throw StateError(
        "No reachable transition found on floor $currentFloorNum "
        "to reach floor $nextFloorNum.",
      );
    }

    segments.add(IndoorFloorPathSegment(
      floorNumber: currentFloorNum,
      path: bestPath,
      exitTransition: bestCandidate.fromTransition,
      entryTransition: i > 0 ? segments.last.exitTransition : null,
    ));

    // The start point on the next floor is the matching transition's location.
    currentStartPoint = bestCandidate.toTransition.location;
  }

  // Final segment: from the transition on the destination floor to the destination room.
  final destFloorplan = floorplans[destinationFloor]!;
  final lastExitTransition = segments.last.exitTransition!;

  // Find the corresponding entry transition on the destination floor.
  final entryTransition = destFloorplan.transitions.firstWhere(
    (final t) => t.groupTag == lastExitTransition.groupTag,
    orElse: () => throw StateError(
      "No matching entry transition on floor $destinationFloor.",
    ),
  );

  try {
    final destPath = destFloorplan.shortestPathToTransition(
      entryTransition.location,
      // We need to path from the transition to the destination room.
      // Reuse shortestPathToTransition by creating a temporary FloorTransition
      // at the destination room's door location.
      FloorTransition(
        id: "dest-room",
        location: destinationRoom.doorLocation,
        type: TransitionType.stairs, // type doesn't matter for pathfinding
        groupTag: "",
      ),
    );
    segments.add(IndoorFloorPathSegment(
      floorNumber: destinationFloor,
      path: destPath,
      entryTransition: entryTransition,
    ));
  } on StateError {
    throw StateError(
      "No path found from transition to room ${destinationRoom.name} "
      "on floor $destinationFloor.",
    );
  }

  return segments;
}

// ---------------------------------------------------------------------------
// Inter-floor helpers
// ---------------------------------------------------------------------------

class _TransitionCandidate {
  final FloorTransition fromTransition;
  final FloorTransition toTransition;

  const _TransitionCandidate({
    required this.fromTransition,
    required this.toTransition,
  });
}

/// Finds transition pairs that connect two floors by matching [groupTag].
///
/// If [preferredType] is specified, transitions of that type are returned
/// first. Other types are still included as fallbacks.
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

  for (final fromT in fromFloorTransitions) {
    final toT = toTransitionsByGroup[fromT.groupTag];
    if (toT == null) {
      continue;
    }

    final candidate = _TransitionCandidate(
      fromTransition: fromT,
      toTransition: toT,
    );

    if (preferredType != null && fromT.type == preferredType) {
      preferred.add(candidate);
    } else {
      others.add(candidate);
    }
  }

  return [...preferred, ...others];
}

/// Computes the total Euclidean length of a polyline path.
double _pathLength(final List<Point<double>> path) {
  double total = 0;
  for (int i = 0; i < path.length - 1; i++) {
    total += _euclideanDistance(path[i], path[i + 1]);
  }
  return total;
}

// ---------------------------------------------------------------------------
// Graph construction helpers (unchanged)
// ---------------------------------------------------------------------------

/// Euclidean distance between two points.
double _euclideanDistance(final Point<double> a, final Point<double> b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return sqrt(dx * dx + dy * dy);
}

/// Creates graph nodes for corridor polygon vertices and returns their IDs per corridor.
List<List<int>> _createCorridorVertexNodes(
  final List<Corridor> corridors,
  final int Function(Point<double>) getOrCreateNodeId,
  final List<List<int>> corridorAllNodeIds,
) {
  final List<List<int>> corridorVertexNodeIds = <List<int>>[];

  for (final corridor in corridors) {
    final vertexIds = <int>[];
    for (final point in corridor.bounds) {
      vertexIds.add(getOrCreateNodeId(point));
    }
    corridorVertexNodeIds.add(vertexIds);
    corridorAllNodeIds.add(List<int>.from(vertexIds));
  }

  return corridorVertexNodeIds;
}

/// Connects consecutive corridor vertices along each corridor boundary.
void _connectCorridorEdges(
  final List<_IndoorGraphNode> nodes,
  final List<List<int>> corridorVertexNodeIds,
) {
  for (final vertexIds in corridorVertexNodeIds) {
    if (vertexIds.length < 2) {
      continue;
    }

    for (var i = 0; i < vertexIds.length; i++) {
      final int a = vertexIds[i];
      final int b = vertexIds[(i + 1) % vertexIds.length];

      if (a == b) {
        continue;
      }

      final pa = nodes[a].position;
      final pb = nodes[b].position;
      final weight = _euclideanDistance(pa, pb);

      nodes[a].edges.add(_IndoorGraphEdge(b, weight));
      nodes[b].edges.add(_IndoorGraphEdge(a, weight));
    }
  }
}

/// Connects nearby corridor vertices to bridge small gaps.
void _snapNearbyVertices(final List<_IndoorGraphNode> nodes) {
  const double vertexSnapThreshold = 5.0;
  final double vertexSnapThresholdSquared = vertexSnapThreshold * vertexSnapThreshold;

  for (var i = 0; i < nodes.length; i++) {
    final pi = nodes[i].position;
    for (var j = i + 1; j < nodes.length; j++) {
      final pj = nodes[j].position;
      final dx = pi.x - pj.x;
      final dy = pi.y - pj.y;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared > vertexSnapThresholdSquared) {
        continue;
      }

      final weight = sqrt(distanceSquared);
      nodes[i].edges.add(_IndoorGraphEdge(j, weight));
      nodes[j].edges.add(_IndoorGraphEdge(i, weight));
    }
  }
}

/// Adds midpoints and centroids as interior nodes for each corridor.
void _addCorridorInteriorPoints(
  final List<Corridor> corridors,
  final List<List<int>> corridorAllNodeIds,
  final int Function(Point<double>) getOrCreateNodeId,
) {
  for (var corridorIndex = 0; corridorIndex < corridors.length; corridorIndex++) {
    final polygon = corridors[corridorIndex].bounds;
    if (polygon.length < 3) {
      continue;
    }

    final allNodeIds = corridorAllNodeIds[corridorIndex];

    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      final midpoint = Point<double>((a.x + b.x) / 2, (a.y + b.y) / 2);
      final midId = getOrCreateNodeId(midpoint);
      allNodeIds.add(midId);
    }

    var sumX = 0.0;
    var sumY = 0.0;
    for (final p in polygon) {
      sumX += p.x;
      sumY += p.y;
    }
    final centroid = Point<double>(sumX / polygon.length, sumY / polygon.length);
    final centroidId = getOrCreateNodeId(centroid);
    allNodeIds.add(centroidId);
  }
}

/// Adds global visibility edges over the union of all corridors.
void _addGlobalVisibilityEdges(
  final List<_IndoorGraphNode> nodes,
  final List<List<int>> corridorAllNodeIds,
  final List<Corridor> corridors,
) {
  final Set<int> unionNodeIds = <int>{};
  for (final corridorNodes in corridorAllNodeIds) {
    unionNodeIds.addAll(corridorNodes);
  }

  final List<int> allVisibilityNodeIds = unionNodeIds.toList(growable: false);

  const double maxVisibilityEdgeLength = 200.0;
  final double maxVisibilityEdgeLengthSquared = maxVisibilityEdgeLength * maxVisibilityEdgeLength;

  for (var i = 0; i < allVisibilityNodeIds.length; i++) {
    final idA = allVisibilityNodeIds[i];
    final pa = nodes[idA].position;

    for (var j = i + 1; j < allVisibilityNodeIds.length; j++) {
      final idB = allVisibilityNodeIds[j];
      final pb = nodes[idB].position;

      final dx = pa.x - pb.x;
      final dy = pa.y - pb.y;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared > maxVisibilityEdgeLengthSquared) {
        continue;
      }

      if (!_segmentInsideAnyCorridor(pa, pb, corridors)) {
        continue;
      }

      final weight = sqrt(distanceSquared);
      nodes[idA].edges.add(_IndoorGraphEdge(idB, weight));
      nodes[idB].edges.add(_IndoorGraphEdge(idA, weight));
    }
  }
}

/// Checks whether segment AB lies entirely inside the union of all corridors.
bool _segmentInsideAnyCorridor(
  final Point<double> a,
  final Point<double> b,
  final List<Corridor> corridors,
) {
  const int samples = 4;

  for (var i = 1; i <= samples; i++) {
    final t = i / (samples + 1);
    final samplePoint = Point<double>(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);

    var insideAny = false;
    for (final corridor in corridors) {
      if (_pointInPolygon(samplePoint, corridor.bounds)) {
        insideAny = true;
        break;
      }
    }

    if (!insideAny) {
      return false;
    }
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

/// Dijkstra shortest path on the indoor graph.
List<int> _dijkstra(final _IndoorGraph graph, final int startId, final int endId) {
  final nodeCount = graph.nodes.length;
  if (startId < 0 || startId >= nodeCount || endId < 0 || endId >= nodeCount) {
    return <int>[];
  }

  final distances = List<double>.filled(nodeCount, double.infinity);
  final previous = List<int?>.filled(nodeCount, null);
  final visited = List<bool>.filled(nodeCount, false);

  distances[startId] = 0;

  for (var iteration = 0; iteration < nodeCount; iteration++) {
    var u = -1;
    var bestDistance = double.infinity;

    for (var i = 0; i < nodeCount; i++) {
      if (!visited[i] && distances[i] < bestDistance) {
        bestDistance = distances[i];
        u = i;
      }
    }

    if (u == -1 || u == endId) {
      break;
    }

    visited[u] = true;

    for (final edge in graph.nodes[u].edges) {
      if (visited[edge.to]) {
        continue;
      }

      final alt = distances[u] + edge.weight;
      if (alt < distances[edge.to]) {
        distances[edge.to] = alt;
        previous[edge.to] = u;
      }
    }
  }

  if (distances[endId] == double.infinity) {
    return <int>[];
  }

  final path = <int>[];
  int? current = endId;
  while (current != null) {
    path.add(current);
    current = previous[current];
  }

  return path.reversed.toList(growable: false);
}
