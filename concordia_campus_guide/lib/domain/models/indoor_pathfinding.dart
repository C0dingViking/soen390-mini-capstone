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

  _IndoorGraph({required this.nodes, required this.corridorVertexNodeIds});

  /// Builds a graph from corridor polygons.
  factory _IndoorGraph.fromCorridors(final List<Corridor> corridors) {
    final List<_IndoorGraphNode> nodes = <_IndoorGraphNode>[];
    final Map<String, int> coordinateToNodeId = <String, int>{};
    final List<List<int>> corridorVertexNodeIds = <List<int>>[];

    int getOrCreateNodeId(final Point<double> p) {
      final key = "${p.x.toStringAsFixed(20)}:${p.y.toStringAsFixed(20)}";
      final existing = coordinateToNodeId[key];
      if (existing != null) {
        return existing;
      }

      final id = nodes.length;
      nodes.add(_IndoorGraphNode(p));
      coordinateToNodeId[key] = id;
      return id;
    }

    for (final corridor in corridors) {
      final vertexIds = <int>[];
      for (final point in corridor.bounds) {
        vertexIds.add(getOrCreateNodeId(point));
      }
      corridorVertexNodeIds.add(vertexIds);
    }

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

    // Snap nearby corridor vertices together to bridge tiny gaps between
    // separate corridor polygons that are visually connected in the SVG
    // but whose vertices do not match exactly due to drawing imprecision.
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

    return _IndoorGraph(nodes: nodes, corridorVertexNodeIds: corridorVertexNodeIds);
  }

  /// Adds a door node and connects it to the nearest corridor vertex.
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

    // If the door is not strictly inside any corridor polygon, but is very
    // close to one (for example due to SVG rounding or being drawn just on
    // the boundary), snap it to the nearest corridor instead of treating it
    // as completely disconnected.
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
      candidateVertexIds = corridorVertexNodeIds[containingCorridorIndex];
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

/// Computes the shortest indoor path between two rooms.
extension FloorplanPathfinding on Floorplan {
  List<Point<double>> shortestPathBetweenRooms(
    final IndoorMapRoom startRoom,
    final IndoorMapRoom endRoom,
  ) {
    if (corridors.isEmpty) {
      throw StateError("No indoor corridors available for pathfinding.");
    }

    final graph = _IndoorGraph.fromCorridors(corridors);

    final startId = graph.addDoorNode(startRoom.doorLocation, corridors);
    final endId = graph.addDoorNode(endRoom.doorLocation, corridors);

    final pathNodeIds = _dijkstra(graph, startId, endId);

    if (pathNodeIds.isEmpty) {
      throw StateError("No indoor path found between rooms ${startRoom.name} and ${endRoom.name}.");
    }

    return pathNodeIds.map((final id) => graph.nodes[id].position).toList(growable: false);
  }
}

double _euclideanDistance(final Point<double> a, final Point<double> b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return sqrt(dx * dx + dy * dy);
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
