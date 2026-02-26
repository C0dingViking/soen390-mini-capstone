import "dart:math";

import "package:concordia_campus_guide/utils/app_logger.dart";
import "package:xml/xml.dart";

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

  // Tokenize the path data
  final tokens = _tokenizeSvgPath(pathData);

  var i = 0;
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
        // moveto or lineto - consume coordinate pairs
        while (i + 1 < tokens.length && _isNumber(tokens[i])) {
          final x = double.tryParse(tokens[i]) ?? 0;
          final y = double.tryParse(tokens[i + 1]) ?? 0;

          if (isRelative) {
            currentX += x;
            currentY += y;
          } else {
            currentX = x;
            currentY = y;
          }

          points.add(Point(currentX, currentY));
          i += 2;
        }
        break;

      case "h":
        // horizontal lineto - consume x values
        while (i < tokens.length && _isNumber(tokens[i])) {
          final x = double.tryParse(tokens[i]) ?? 0;
          if (isRelative) {
            currentX += x;
          } else {
            currentX = x;
          }
          points.add(Point(currentX, currentY));
          i++;
        }
        break;

      case "v":
        // vertical lineto - consume y values
        while (i < tokens.length && _isNumber(tokens[i])) {
          final y = double.tryParse(tokens[i]) ?? 0;
          if (isRelative) {
            currentY += y;
          } else {
            currentY = y;
          }
          points.add(Point(currentX, currentY));
          i++;
        }
        break;

      case "c":
        // cubic bezier - consume 3 coordinate pairs (6 numbers)
        while (i + 5 < tokens.length && _isNumber(tokens[i])) {
          // Skip two control points (4 numbers), use end point
          i += 4;
          final x = double.tryParse(tokens[i]) ?? 0;
          final y = double.tryParse(tokens[i + 1]) ?? 0;

          if (isRelative) {
            currentX += x;
            currentY += y;
          } else {
            currentX = x;
            currentY = y;
          }

          points.add(Point(currentX, currentY));
          i += 2;
        }
        break;

      case "s":
        // smooth cubic bezier - consume 2 coordinate pairs (4 numbers)
        while (i + 3 < tokens.length && _isNumber(tokens[i])) {
          // Skip first control point (2 numbers), use end point
          i += 2;
          final x = double.tryParse(tokens[i]) ?? 0;
          final y = double.tryParse(tokens[i + 1]) ?? 0;

          if (isRelative) {
            currentX += x;
            currentY += y;
          } else {
            currentX = x;
            currentY = y;
          }

          points.add(Point(currentX, currentY));
          i += 2;
        }
        break;

      case "q":
        // quadratic bezier - consume 2 coordinate pairs (4 numbers)
        while (i + 3 < tokens.length && _isNumber(tokens[i])) {
          // Skip control point (2 numbers), use end point
          i += 2;
          final x = double.tryParse(tokens[i]) ?? 0;
          final y = double.tryParse(tokens[i + 1]) ?? 0;

          if (isRelative) {
            currentX += x;
            currentY += y;
          } else {
            currentX = x;
            currentY = y;
          }

          points.add(Point(currentX, currentY));
          i += 2;
        }
        break;

      case "t":
        // smooth quadratic bezier - consume 1 coordinate pair (2 numbers)
        while (i + 1 < tokens.length && _isNumber(tokens[i])) {
          final x = double.tryParse(tokens[i]) ?? 0;
          final y = double.tryParse(tokens[i + 1]) ?? 0;

          if (isRelative) {
            currentX += x;
            currentY += y;
          } else {
            currentX = x;
            currentY = y;
          }

          points.add(Point(currentX, currentY));
          i += 2;
        }
        break;

      case "a":
        // arc - consume 7 numbers per arc
        while (i + 6 < tokens.length && _isNumber(tokens[i])) {
          // Skip rx, ry, x-axis-rotation, large-arc, sweep (5 numbers), use end point
          i += 5;
          final x = double.tryParse(tokens[i]) ?? 0;
          final y = double.tryParse(tokens[i + 1]) ?? 0;

          if (isRelative) {
            currentX += x;
            currentY += y;
          } else {
            currentX = x;
            currentY = y;
          }

          points.add(Point(currentX, currentY));
          i += 2;
        }
        break;

      case "z":
        // closepath - no coordinates
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
