import 'package:flutter/material.dart';

class AppTheme {
  // رنگ‌های رسمی پرچم ایران و هویت بصری VetoApp
  static const Color primaryGreen = Color(0xFF239F40);
  static const Color primaryRed = Color(0xFFDA0000);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primaryColor = Color(0xFF2E7D32);
  static const Color accentColor = Color(0xFFC62828);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  // لوگوی رسمی برنامه
  static const String appLogo = 'assets/images/vetoapp.png';

  // گرادینت سه‌رنگ ثابت پرچم ایران
  static const BoxDecoration pageBackground = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF239F40), // سبز
        Color(0xFFFFFFFF), // سفید
        Color(0xFFDA0000), // قرمز
      ],
      stops: [0.0, 0.5, 1.0],
    ),
  );

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'B Mitra',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryDark,
        secondary: accentColor,
        surface: backgroundColor,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
