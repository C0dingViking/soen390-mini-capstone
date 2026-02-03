import 'package:logger/logger.dart';

final Logger logger = Logger(
  filter: null,
  output: null,
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart
  )
);
