
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF176B65),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7F7),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF176B65),
        foregroundColor: Colors.white,
      ),
    );
  }
}
