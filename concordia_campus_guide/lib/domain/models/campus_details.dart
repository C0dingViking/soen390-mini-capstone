import 'package:concordia_campus_guide/domain/models/coordinate.dart';
import 'package:flutter/material.dart';

class Campus_Details {
  final String name;
  final Coordinate coord;
  final IconData icon;

  const Campus_Details({required this.name, required this.coord, required this.icon});
}