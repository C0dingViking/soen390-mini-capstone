import "dart:math";

import "package:concordia_campus_guide/domain/models/floorplan.dart";

/// Represents a node in the indoor navigation graph.
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

/// Internal graph built from corridor polygons. Each corridor contributes
/// vertices (polygon points) that are connected along polygon edges.
class _IndoorGraph {
  final List<_IndoorGraphNode> nodes;
  final List<List<int>> corridorVertexNodeIds;

  _IndoorGraph({required this.nodes, required this.corridorVertexNodeIds});

  /// Builds a base graph from the provided corridors. Vertices that share
  /// the same coordinates (within a small rounding tolerance) are merged so
  /// that intersecting corridors become connected in the graph.
  factory _IndoorGraph.fromCorridors(final List<Corridor> corridors) {
    final List<_IndoorGraphNode> nodes = <_IndoorGraphNode>[];
    final Map<String, int> coordinateToNodeId = <String, int>{};
    final List<List<int>> corridorVertexNodeIds = <List<int>>[];

    int getOrCreateNodeId(final Point<double> p) {
      // Quantize coordinates to reduce floating point mismatches when
      // corridors share vertices.
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

    // First create nodes for all corridor vertices and keep track of which
    // node IDs belong to which corridor.
    for (final corridor in corridors) {
      final vertexIds = <int>[];
      for (final point in corridor.bounds) {
        vertexIds.add(getOrCreateNodeId(point));
      }
      corridorVertexNodeIds.add(vertexIds);
    }

    // Then connect successive vertices within each corridor to form the
    // polygon edges. Corridors are treated as closed polygons.
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

    return _IndoorGraph(nodes: nodes, corridorVertexNodeIds: corridorVertexNodeIds);
  }

  /// Adds a new node corresponding to a door or arbitrary point inside the
  /// walkable area and connects it to the nearest vertex of the containing
  /// corridor. If the point is not inside any corridor, it will connect to
  /// the globally nearest vertex.
  int addDoorNode(final Point<double> door, final List<Corridor> corridors) {
    final doorNodeId = nodes.length;
    nodes.add(_IndoorGraphNode(door));

    // Determine which corridor (if any) contains this point.
    var containingCorridorIndex = -1;
    for (var i = 0; i < corridors.length; i++) {
      if (_pointInPolygon(door, corridors[i].bounds)) {
        containingCorridorIndex = i;
        break;
      }
    }

    Iterable<int> candidateVertexIds;
    if (containingCorridorIndex >= 0) {
      candidateVertexIds = corridorVertexNodeIds[containingCorridorIndex];
    } else {
      // Fallback: consider all existing corridor vertices.
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

/// Computes the shortest path between two rooms on the same floorplan,
/// constrained to travel within the corridor polygons. The path is returned
/// as a series of points in SVG coordinate space, starting at the start
/// room's door location and ending at the destination room's door location.
extension FloorplanPathfinding on Floorplan {
  List<Point<double>> shortestPathBetweenRooms(
    final IndoorMapRoom startRoom,
    final IndoorMapRoom endRoom,
  ) {
    // If there are no corridor definitions, fall back to a straight line
    // between the two door locations.
    if (corridors.isEmpty) {
      return <Point<double>>[startRoom.doorLocation, endRoom.doorLocation];
    }

    final graph = _IndoorGraph.fromCorridors(corridors);

    final startId = graph.addDoorNode(startRoom.doorLocation, corridors);
    final endId = graph.addDoorNode(endRoom.doorLocation, corridors);

    final pathNodeIds = _dijkstra(graph, startId, endId);

    if (pathNodeIds.isEmpty) {
      // If the graph is disconnected and no path exists, fall back to a
      // straight line as a last resort.
      return <Point<double>>[startRoom.doorLocation, endRoom.doorLocation];
    }

    return pathNodeIds.map((final id) => graph.nodes[id].position).toList(growable: false);
  }
}

double _euclideanDistance(final Point<double> a, final Point<double> b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return sqrt(dx * dx + dy * dy);
}

/// Simple even–odd (ray casting) point-in-polygon test for a 2D point.
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

/// Dijkstra's algorithm on the indoor graph, returning the sequence of node
/// indices representing the shortest path between [startId] and [endId].
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
