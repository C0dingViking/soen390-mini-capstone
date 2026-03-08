class InvalidLocationFormatException implements Exception {
  final String message;

  InvalidLocationFormatException(this.message);

  @override
  String toString() => message;
}
