// coverage:ignore-file

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

class AppTheme {
  static const Color concordiaMaroon = Color(0xFF912338);
  static const Color concordiaDarkBlue = Color(0xFF004085);
  static const Color concordiaTurquoise = Color(0xFF057D78);
  static const Color concordiaBusCyan = Color(0xFF00ADEF);
  static const Color concordiaTrainMauve = Color(0xFF573996);
  static const Color concordiaRailGold = Color(0xFFCBB576);
  static const Color concordiaGold = Color(0xFFE9E3D3);
  static const Color concordiaGreen = Color(0xFF508212);
  static const Color concordiaForeground = Colors.black;
  static const Color concordiaButtonCyan = Color(0xCC00ADEF);
  static const Color concordiaButtonCyanSolid = Color(0xFF00ABEF);

  static ThemeData mainTheme = ThemeData(
    appBarTheme: const AppBarTheme(backgroundColor: concordiaMaroon),
    textTheme: GoogleFonts.robotoTextTheme().apply(
      bodyColor: concordiaForeground,
      displayColor: concordiaForeground,
    ),
  );

  static const InputDecoration indoorSearchFieldDecoration = InputDecoration(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.zero),
    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  );

  static ButtonStyle indoorNavigationButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: concordiaButtonCyan,
    foregroundColor: Colors.white,
  );
}
