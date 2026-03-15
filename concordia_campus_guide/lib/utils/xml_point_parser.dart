import "dart:math";

import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:xml/xml.dart";

Point<double> parsePointFromSvgCircle(final XmlElement circleElement) {
  try {
    final cx = double.parse(circleElement.getAttribute("cx") ?? "0");
    final cy = double.parse(circleElement.getAttribute("cy") ?? "0");

    return Point(cx, cy);
  } on FormatException catch (e) {
    logger.e("XML Parser: Invalid SVG circle attribute value", error: e);
  }

  return const Point(0, 0);
}

List<Point<double>> parsePointsFromSvgRect(final XmlElement rectElement) {
  try {
    final x = double.parse(rectElement.getAttribute("x") ?? "0");
    final y = double.parse(rectElement.getAttribute("y") ?? "0");
    final width = double.parse(rectElement.getAttribute("width") ?? "0");
    final height = double.parse(rectElement.getAttribute("height") ?? "0");

    return [Point(x, y), Point(x + width, y), Point(x + width, y + height), Point(x, y + height)];
  } on FormatException catch (e) {
    logger.e("XML Parser: Invalid SVG rect attribute value", error: e);
  }

  return [];
}

List<Point<double>> parsePointsFromSvgPath(final XmlElement pathElement) {
  final pathData = pathElement.getAttribute("d") ?? "";
  if (pathData.isEmpty) return [];

  final tokens = _tokenizeSvgPath(pathData);
  final state = _SvgPathState();
  var i = 0;

  while (i < tokens.length) {
    final token = tokens[i];

    if (!_isCommand(token)) {
      i++;
      continue;
    }

    final command = token.toLowerCase();
    final isRelative = token == token.toLowerCase();
    i++;

    final handler = _pathCommandHandlers[command];
    if (handler != null) {
      i = handler(tokens, i, isRelative, state);
    }
  }

  return state.points;
}

typedef _PathCommandHandler =
    int Function(List<String> tokens, int index, bool isRelative, _SvgPathState state);

final Map<String, _PathCommandHandler> _pathCommandHandlers = {
  "m": _handleMoveOrLine,
  "l": _handleMoveOrLine,
  "h": _handleHorizontal,
  "v": _handleVertical,
  "c": _handleCubicBezier,
  "s": _handleSmoothCubicBezier,
  "q": _handleQuadraticBezier,
  "t": _handleSmoothQuadraticBezier,
  "a": _handleArc,
  "z": _handleClosePath,
};

class _SvgPathState {
  var currentX = 0.0;
  var currentY = 0.0;
  final points = <Point<double>>[];

  void applyPoint(final double x, final double y, final bool relative) {
    if (relative) {
      currentX += x;
      currentY += y;
    } else {
      currentX = x;
      currentY = y;
    }
    points.add(Point(currentX, currentY));
  }
}

double _parsePathNumber(final String token) => double.tryParse(token) ?? 0;

int _handleMoveOrLine(
  final List<String> tokens,
  int index,
  final bool isRelative,
  final _SvgPathState state,
) {
  while (index + 1 < tokens.length && _isNumber(tokens[index])) {
    final x = _parsePathNumber(tokens[index]);
    final y = _parsePathNumber(tokens[index + 1]);
    state.applyPoint(x, y, isRelative);
    index += 2;
  }
  return index;
}

int _handleHorizontal(
  final List<String> tokens,
  int index,
  final bool isRelative,
  final _SvgPathState state,
) {
  while (index < tokens.length && _isNumber(tokens[index])) {
    final x = _parsePathNumber(tokens[index]);
    final targetX = isRelative ? x : x - state.currentX;
    state.applyPoint(targetX, 0, true);
    index++;
  }
  return index;
}

int _handleVertical(
  final List<String> tokens,
  int index,
  final bool isRelative,
  final _SvgPathState state,
) {
  while (index < tokens.length && _isNumber(tokens[index])) {
    final y = _parsePathNumber(tokens[index]);
    final targetY = isRelative ? y : y - state.currentY;
    state.applyPoint(0, targetY, true);
    index++;
  }
  return index;
}

int _handleCubicBezier(
  final List<String> tokens,
  int index,
  final bool isRelative,
  final _SvgPathState state,
) {
  while (index + 5 < tokens.length && _isNumber(tokens[index])) {
    index += 4;
    final x = _parsePathNumber(tokens[index]);
    final y = _parsePathNumber(tokens[index + 1]);
    state.applyPoint(x, y, isRelative);
    index += 2;
  }
  return index;
}

int _handleSmoothCubicBezier(
  final List<String> tokens,
  int index,
  final bool isRelative,
  final _SvgPathState state,
) {
  while (index + 3 < tokens.length && _isNumber(tokens[index])) {
    index += 2;
    final x = _parsePathNumber(tokens[index]);
    final y = _parsePathNumber(tokens[index + 1]);
    state.applyPoint(x, y, isRelative);
    index += 2;
  }
  return index;
}

int _handleQuadraticBezier(
  final List<String> tokens,
  int index,
  final bool isRelative,
  final _SvgPathState state,
) {
  while (index + 3 < tokens.length && _isNumber(tokens[index])) {
    index += 2;
    final x = _parsePathNumber(tokens[index]);
    final y = _parsePathNumber(tokens[index + 1]);
    state.applyPoint(x, y, isRelative);
    index += 2;
  }
  return index;
}

int _handleSmoothQuadraticBezier(
  final List<String> tokens,
  int index,
  final bool isRelative,
  final _SvgPathState state,
) {
  while (index + 1 < tokens.length && _isNumber(tokens[index])) {
    final x = _parsePathNumber(tokens[index]);
    final y = _parsePathNumber(tokens[index + 1]);
    state.applyPoint(x, y, isRelative);
    index += 2;
  }
  return index;
}

int _handleArc(
  final List<String> tokens,
  int index,
  final bool isRelative,
  final _SvgPathState state,
) {
  while (index + 6 < tokens.length && _isNumber(tokens[index])) {
    index += 5;
    final x = _parsePathNumber(tokens[index]);
    final y = _parsePathNumber(tokens[index + 1]);
    state.applyPoint(x, y, isRelative);
    index += 2;
  }
  return index;
}

int _handleClosePath(
  final List<String> tokens,
  final int index,
  final bool isRelative,
  final _SvgPathState state,
) {
  return index;
}

List<String> _tokenizeSvgPath(final String pathData) {
  final tokens = <String>[];
  final buffer = StringBuffer();

  for (final char in pathData.split("")) {
    if ("mMlLhHvVcCsSquQqAaZz".contains(char)) {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      tokens.add(char);
    } else if (char == " " || char == "," || char == "\n" || char == "\r" || char == "\t") {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
    } else {
      buffer.write(char);
    }
  }

  if (buffer.isNotEmpty) {
    tokens.add(buffer.toString());
  }

  return tokens;
}

bool _isCommand(final String token) {
  return token.length == 1 && "mMlLhHvVcCsSquQqAaZz".contains(token);
}

bool _isNumber(final String token) {
  return double.tryParse(token) != null;
}
