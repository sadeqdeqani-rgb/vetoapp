import 'package:flutter/material.dart';

class AppTheme {
  // رنگ‌های رسمی هویت بصری VetoApp
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color primaryRed = Color(0xFFB71C1C);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primaryColor = Color(0xFF2E7D32);
  static const Color accentColor = Color(0xFFC62828);
  static const Color backgroundColor = Color(0xFFFFFFFF);

  // لوگوی رسمی برنامه
  static const String appLogo = 'assets/images/vetoapp.png';
  static const String iranMap = 'assets/images/persianmap.png';

  // گرادیان سه‌رنگ ثابت و استاندارد (۱۲٪ سبز، ۷۶٪ سفید، ۱۲٪ قرمز)
  static const BoxDecoration pageBackground = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primaryGreen,
        Colors.white,
        Colors.white,
        primaryRed,
      ],
      stops: [0.0, 0.12, 0.88, 1.0],
    ),
  );

  // سایه استاندارد متن‌ها
  static const List<Shadow> textShadows = [
    Shadow(
      color: Color(0x66000000),
      offset: Offset(1.5, 2.0),
      blurRadius: 3.5,
    ),
  ];

  // استایل پایه متن‌های رسمی با فونت B Mitra و بولد
  static TextStyle getTitleStyle({
    double fontSize = 20,
    Color color = Colors.black,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'B Mitra',
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color,
      letterSpacing: letterSpacing,
      shadows: textShadows,
    );
  }

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
