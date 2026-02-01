import 'package:flutter_test/flutter_test.dart';
import 'package:concordia_campus_guide/utils/campus.dart';

void main() {
  test('parseCampus parses common campus names', () {
    expect(parseCampus('SGW'), Campus.sgw);
    expect(parseCampus('Sir George Williams'), Campus.sgw);
    expect(parseCampus('sIr georGe'), Campus.sgw);
    expect(parseCampus('Williams'), Campus.sgw);
    expect(parseCampus('loyola'), Campus.loyola);
    expect(parseCampus('LOY'), Campus.loyola);
    expect(parseCampus(''), isNull);
    expect(parseCampus('Lady Jane Smith'), isNull);
  });
}