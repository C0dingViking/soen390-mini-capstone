class InvalidEventFormatException implements Exception {
  final String message;

  InvalidEventFormatException(this.message);

  @override
  String toString() => "InvalidEventFormatException: $message";
}
