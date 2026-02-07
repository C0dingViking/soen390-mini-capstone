import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

class AppTheme {
  static const Color concordiaMaroon = Color(0xFF912338);
  static const Color concordiaDarkBlue = Color(0xFF004085);
  static const Color concordiaGold = Color(0xFFE9E3D3);
  static const Color concordiaGreen = Color(0xFF508212);
  static const Color concordiaForeground = Colors.black;

  static ThemeData mainTheme = ThemeData(
    appBarTheme: AppBarTheme(backgroundColor: concordiaMaroon),
    textTheme: GoogleFonts.robotoTextTheme().apply(
      bodyColor: concordiaForeground,
      displayColor: concordiaForeground,
    ),
  );
}
