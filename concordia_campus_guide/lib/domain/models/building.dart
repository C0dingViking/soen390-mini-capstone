import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/utils/campus.dart";

class Building {
  final String id;
  final String name;
  final String street;
  final String postalCode;
  final Coordinate location;
  final Campus campus;
  List<Coordinate> outlinePoints;

  Building({
    required this.id,
    required this.name,
    required this.street,
    required this.postalCode,
    required this.location,
    required this.campus,
    required this.outlinePoints,
  });

  String get address => "$street, Montreal, QC $postalCode, Canada";

  @override
  String toString() => "$id: ($name - $address at ${location.toString()})";
}
