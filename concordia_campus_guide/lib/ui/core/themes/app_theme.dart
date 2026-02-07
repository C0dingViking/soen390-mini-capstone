import "package:flutter/material.dart";

class AppTheme {
  static const Color concordiaMaroon = Color(0xFF912338);
  static const Color concordiaDarkBlue = Color(0xFF004085);
  static const Color concordiaGold = Color(0xFFE9E3D3);
  static const Color concordiaForeground = Colors.black;

  static ThemeData mainTheme = ThemeData(
    appBarTheme: AppBarTheme(backgroundColor: concordiaMaroon),
  );
}
