import 'package:flutter/material.dart';

/// منبع واحد توکن‌های رنگی و تایپوگرافی VetoApp.
abstract final class AppTheme {
  // رنگ‌های هویتی و محتوایی
  static const Color primary = Color(0xFF1A237E);
  static const Color primaryLight = Color(0xFFE8EAF6);
  static const Color primaryDark = Color(0xFF101552);
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerLight = Color(0xFFFFEBEE);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF607D8B);
  static const Color divider = Color(0xFFDDE3EA);
  static const Color pressedTab = Color(0xFFD1D5F0);

  // نام‌های سازگار با کدهای قدیمی صفحات.
  static const Color primaryGreen = success;
  static const Color primaryRed = danger;
  static const Color primaryColor = primary;
  static const Color accentColor = danger;
  static const Color backgroundColor = background;

  static const String appLogo = 'assets/images/vetoapp.png';
  static const String iranMap = 'assets/images/persianmap.png';

  static const BoxDecoration pageBackground = BoxDecoration(color: background);

  static const List<Shadow> textShadows = <Shadow>[];

  static TextStyle getTitleStyle({
    double fontSize = 20,
    Color color = textPrimary,
    double? letterSpacing,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return TextStyle(
      fontFamily: 'B Mitra',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: surface,
      primaryContainer: primaryLight,
      onPrimaryContainer: primaryDark,
      secondary: success,
      onSecondary: surface,
      secondaryContainer: successLight,
      onSecondaryContainer: textPrimary,
      error: danger,
      onError: surface,
      errorContainer: dangerLight,
      onErrorContainer: danger,
      surface: surface,
      onSurface: textPrimary,
      outline: divider,
      outlineVariant: divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: textPrimary,
      onInverseSurface: surface,
      inversePrimary: primaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'B Mitra',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      cardColor: surface,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'B Mitra',
          color: surface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: surface,
          disabledBackgroundColor: divider,
          disabledForegroundColor: textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger, width: 2),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return surface;
        }),
        checkColor: WidgetStateProperty.all(surface),
        side: const BorderSide(color: textSecondary),
      ),
    );
  }
}
