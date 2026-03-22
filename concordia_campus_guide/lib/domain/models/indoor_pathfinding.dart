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

  // Builds a navigation graph from corridor polygons.
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

  int addDoorNodeToCorridorGraph(final Point<double> door, final List<Corridor> corridors) {
    final doorNodeId = nodes.length;
    nodes.add(_IndoorGraphNode(door));

    final containingCorridorIndex = _findContainingOrNearestCorridorIndex(door, corridors);

    final candidateVertexIds = _candidateVertexIdsForDoor(doorNodeId, containingCorridorIndex);

    final bestConnection = _findBestDoorConnection(door, candidateVertexIds);

    if (bestConnection != null && bestConnection.distance > 0) {
      nodes[doorNodeId].edges.add(
        _IndoorGraphEdge(bestConnection.vertexId, bestConnection.distance),
      );
      nodes[bestConnection.vertexId].edges.add(
        _IndoorGraphEdge(doorNodeId, bestConnection.distance),
      );
    }

    return doorNodeId;
  }

  int _findContainingOrNearestCorridorIndex(
    final Point<double> door,
    final List<Corridor> corridors,
  ) {
    final containingCorridorIndex = _findContainingCorridorIndex(door, corridors);

    if (containingCorridorIndex >= 0 || corridors.isEmpty) {
      return containingCorridorIndex;
    }

    const double snapThreshold = 20.0;

    final nearest = _findNearestCorridorIndex(door, corridors);
    if (nearest == null) {
      return -1;
    }

    return nearest.distance <= snapThreshold ? nearest.index : -1;
  }

  int _findContainingCorridorIndex(final Point<double> door, final List<Corridor> corridors) {
    for (var i = 0; i < corridors.length; i++) {
      if (_pointInPolygon(door, corridors[i].bounds)) {
        return i;
      }
    }
    return -1;
  }

  _NearestCorridorResult? _findNearestCorridorIndex(
    final Point<double> door,
    final List<Corridor> corridors,
  ) {
    double bestCorridorDistance = double.infinity;
    int? bestCorridorIndex;

    for (var i = 0; i < corridors.length; i++) {
      final corridor = corridors[i];
      for (final point in corridor.bounds) {
        final d = _euclideanDistanceBtwnPoints(door, point);
        if (d < bestCorridorDistance) {
          bestCorridorDistance = d;
          bestCorridorIndex = i;
        }
      }
    }

    if (bestCorridorIndex == null) {
      return null;
    }

    return _NearestCorridorResult(index: bestCorridorIndex, distance: bestCorridorDistance);
  }

  Iterable<int> _candidateVertexIdsForDoor(
    final int doorNodeId,
    final int containingCorridorIndex,
  ) {
    if (containingCorridorIndex >= 0) {
      return corridorAllNodeIds[containingCorridorIndex];
    }

    return Iterable<int>.generate(doorNodeId);
  }

  _BestDoorConnection? _findBestDoorConnection(
    final Point<double> door,
    final Iterable<int> candidateVertexIds,
  ) {
    double bestDistance = double.infinity;
    int? bestVertexId;

    for (final vertexId in candidateVertexIds) {
      final vertexPoint = nodes[vertexId].position;
      final distanceBtwnDoorAndVertexPoint = _euclideanDistanceBtwnPoints(door, vertexPoint);
      if (distanceBtwnDoorAndVertexPoint < bestDistance) {
        bestDistance = distanceBtwnDoorAndVertexPoint;
        bestVertexId = vertexId;
      }
    }

    if (bestVertexId == null) {
      return null;
    }

    return _BestDoorConnection(vertexId: bestVertexId, distance: bestDistance);
  }
}

class _NearestCorridorResult {
  final int index;
  final double distance;

  const _NearestCorridorResult({required this.index, required this.distance});
}

class _BestDoorConnection {
  final int vertexId;
  final double distance;

  const _BestDoorConnection({required this.vertexId, required this.distance});
}

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

extension FloorplanPathfinding on Floorplan {
  List<Point<double>> shortestPathBetweenRooms(
    final IndoorMapRoom startRoom,
    final IndoorMapRoom endRoom,
  ) {
    if (corridors.isEmpty) {
      const description = "No indoor corridors available for pathfinding.";
      developer.log(
        description,
        name: "IndoorPathfinding",
        error:
            "building=$buildingId floor=$floorNumber start=${startRoom.name} end=${endRoom.name}",
      );
      throw StateError(description);
    }

    final graph = _IndoorGraph.fromCorridors(corridors);

    final startId = graph.addDoorNodeToCorridorGraph(startRoom.doorLocation, corridors);
    final endId = graph.addDoorNodeToCorridorGraph(endRoom.doorLocation, corridors);

    final pathNodeIds = _computeIndoorShortestPathWithDijkstra(graph, startId, endId);

    if (pathNodeIds.isEmpty) {
      final description =
          "No indoor path found between rooms ${startRoom.name} and ${endRoom.name}.";
      developer.log(
        description,
        name: "IndoorPathfinding",
        error:
            "building=$buildingId floor=$floorNumber start=${startRoom.name} end=${endRoom.name} startDoor=${startRoom.doorLocation} endDoor=${endRoom.doorLocation} corridors=${corridors.length}",
      );
      throw StateError(description);
    }

    return pathNodeIds.map((final id) => graph.nodes[id].position).toList(growable: false);
  }

  /// Computes the path from a room's door to a specific transition point on this floor.
  List<Point<double>> shortestPathToTransition(
    final Point<double> startPoint,
    final FloorTransition transition,
  ) {
    if (corridors.isEmpty) {
      const description = "No indoor corridors available for pathfinding.";
      developer.log(
        description,
        name: "IndoorPathfinding",
        error:
            "building=$buildingId floor=$floorNumber transition=${transition.id} startPoint=$startPoint",
      );
      throw StateError(description);
    }

    final graph = _IndoorGraph.fromCorridors(corridors);

    final startId = graph.addDoorNodeToCorridorGraph(startPoint, corridors);
    final endId = graph.addDoorNodeToCorridorGraph(transition.location, corridors);

    final pathNodeIds = _computeIndoorShortestPathWithDijkstra(graph, startId, endId);

    if (pathNodeIds.isEmpty) {
      final description =
          "No indoor path found to transition ${transition.id} on floor $floorNumber.";
      developer.log(
        description,
        name: "IndoorPathfinding",
        error:
            "building=$buildingId floor=$floorNumber transition=${transition.id} startPoint=$startPoint",
      );
      throw StateError(description);
    }

    return pathNodeIds.map((final id) => graph.nodes[id].position).toList(growable: false);
  }
}

List<IndoorFloorPathSegment> computeInterFloorPath({
  required final Map<String, Floorplan> floorplans,
  required final String startFloor,
  required final String destinationFloor,
  required final IndoorMapRoom startRoom,
  required final IndoorMapRoom destinationRoom,
  final TransitionType? preferredTransitionType,
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
  required final List<String> floorsToTraverse,
  required final List<IndoorFloorPathSegment> segments,
  required final int index,
  required final Point<double> currentStartPoint,
}) {
  final currentFloorNum = floorsToTraverse[index];
  final nextFloorNum = floorsToTraverse[index + 1];
  final currentFloorplan = floorplans[currentFloorNum]!;
  final nextFloorplan = floorplans[nextFloorNum]!;

  final candidates = _findMatchingTransitions(
    currentFloorplan.transitions,
    nextFloorplan.transitions,
    preferredTransitionType,
  );

  if (candidates.isEmpty) {
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

// Graph construction helpers

double _euclideanDistanceBtwnPoints(final Point<double> a, final Point<double> b) {
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
      final weight = _euclideanDistanceBtwnPoints(pa, pb);

      nodes[a].edges.add(_IndoorGraphEdge(b, weight));
      nodes[b].edges.add(_IndoorGraphEdge(a, weight));
    }
  }
}

/// Connects nearby corridor vertices to bridge small gaps.
void _snapNearbyVertices(final List<_IndoorGraphNode> nodes) {
  const double vertexSnapThreshold = 5.0;
  const double vertexSnapThresholdSquared = vertexSnapThreshold * vertexSnapThreshold;

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
    final polygons = corridors[corridorIndex].bounds;
    if (polygons.length < 3) {
      continue;
    }

    final allNodeIds = corridorAllNodeIds[corridorIndex];

    for (var i = 0; i < polygons.length; i++) {
      final a = polygons[i];
      final b = polygons[(i + 1) % polygons.length];
      final midpoint = Point<double>((a.x + b.x) / 2, (a.y + b.y) / 2);
      final midPointId = getOrCreateNodeId(midpoint);
      allNodeIds.add(midPointId);
    }

    var sumX = 0.0;
    var sumY = 0.0;
    for (final polygon in polygons) {
      sumX += polygon.x;
      sumY += polygon.y;
    }
    final centroid = Point<double>(sumX / polygons.length, sumY / polygons.length);
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
  const double maxVisibilityEdgeLengthSquared = maxVisibilityEdgeLength * maxVisibilityEdgeLength;

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

List<int> _computeIndoorShortestPathWithDijkstra(
  final _IndoorGraph graph,
  final int startId,
  final int endId,
) {
  final nodeCount = graph.nodes.length;
  if (startId < 0 || startId >= nodeCount || endId < 0 || endId >= nodeCount) {
    return <int>[];
  }

  final distances = List<double>.filled(nodeCount, double.infinity);
  final previous = List<int?>.filled(nodeCount, null);
  final visited = List<bool>.filled(nodeCount, false);

  distances[startId] = 0;

  _runDijkstra(graph, startId, endId, distances, previous, visited);

  if (distances[endId] == double.infinity) {
    return <int>[];
  }

  return _reconstructPath(endId, previous);
}

void _runDijkstra(
  final _IndoorGraph graph,
  final int startId,
  final int endId,
  final List<double> distances,
  final List<int?> previous,
  final List<bool> visited,
) {
  final nodeCount = graph.nodes.length;

  for (var iteration = 0; iteration < nodeCount; iteration++) {
    final u = _selectNextNode(nodeCount, distances, visited);

    if (u == -1 || u == endId) {
      break;
    }

    visited[u] = true;

    _relaxNeighbors(graph, u, distances, previous, visited);
  }
}

int _selectNextNode(final int nodeCount, final List<double> distances, final List<bool> visited) {
  var u = -1;
  var bestDistance = double.infinity;

  for (var i = 0; i < nodeCount; i++) {
    if (!visited[i] && distances[i] < bestDistance) {
      bestDistance = distances[i];
      u = i;
    }
  }

  return u;
}

void _relaxNeighbors(
  final _IndoorGraph graph,
  final int u,
  final List<double> distances,
  final List<int?> previous,
  final List<bool> visited,
) {
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

List<int> _reconstructPath(final int endId, final List<int?> previous) {
  final path = <int>[];
  int? current = endId;
  while (current != null) {
    path.add(current);
    current = previous[current];
  }

  return path.reversed.toList(growable: false);
}
