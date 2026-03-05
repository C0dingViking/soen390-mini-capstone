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

  final points = <Point<double>>[];
  var currentX = 0.0;
  var currentY = 0.0;

  final tokens = _tokenizeSvgPath(pathData);
  var i = 0;

  double num(final String s) => double.tryParse(s) ?? 0;

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

  while (i < tokens.length) {
    final token = tokens[i];

    if (!_isCommand(token)) {
      i++;
      continue;
    }

    final command = token;
    final isRelative = command == command.toLowerCase();
    i++;

    switch (command.toLowerCase()) {
      case "m":
      case "l":
        while (i + 1 < tokens.length && _isNumber(tokens[i])) {
          final x = num(tokens[i]);
          final y = num(tokens[i + 1]);
          applyPoint(x, y, isRelative);
          i += 2;
        }
        break;

      case "h":
        while (i < tokens.length && _isNumber(tokens[i])) {
          final x = num(tokens[i]);
          applyPoint(x, 0, isRelative);
          i++;
        }
        break;

      case "v":
        while (i < tokens.length && _isNumber(tokens[i])) {
          final y = num(tokens[i]);
          applyPoint(0, y, isRelative);
          i++;
        }
        break;

      case "c":
        while (i + 5 < tokens.length && _isNumber(tokens[i])) {
          i += 4; // skip control points
          final x = num(tokens[i]);
          final y = num(tokens[i + 1]);
          applyPoint(x, y, isRelative);
          i += 2;
        }
        break;

      case "s":
        while (i + 3 < tokens.length && _isNumber(tokens[i])) {
          i += 2; // skip first control point
          final x = num(tokens[i]);
          final y = num(tokens[i + 1]);
          applyPoint(x, y, isRelative);
          i += 2;
        }
        break;

      case "q":
        while (i + 3 < tokens.length && _isNumber(tokens[i])) {
          i += 2; // skip control point
          final x = num(tokens[i]);
          final y = num(tokens[i + 1]);
          applyPoint(x, y, isRelative);
          i += 2;
        }
        break;

      case "t":
        while (i + 1 < tokens.length && _isNumber(tokens[i])) {
          final x = num(tokens[i]);
          final y = num(tokens[i + 1]);
          applyPoint(x, y, isRelative);
          i += 2;
        }
        break;

      case "a":
        while (i + 6 < tokens.length && _isNumber(tokens[i])) {
          i += 5; // skip arc params
          final x = num(tokens[i]);
          final y = num(tokens[i + 1]);
          applyPoint(x, y, isRelative);
          i += 2;
        }
        break;

      case "z":
        break;
    }
  }

  return points;
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
