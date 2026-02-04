import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:flutter/material.dart";

class CampusDetails {
  final String name;
  final Coordinate coord;
  final IconData icon;

  const CampusDetails({required this.name, required this.coord, required this.icon});
}
