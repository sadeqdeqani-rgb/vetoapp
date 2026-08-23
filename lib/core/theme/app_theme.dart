import 'package:flutter/material.dart';

/// منبع واحد توکن‌های رنگی و تایپوگرافی VetoApp.
abstract final class AppTheme {
  static const String fontFamily = 'B Mitra';

  // رنگ‌های هویتی و محتوایی
  static const Color primary = Color(0xFF1A237E);
  static const Color primaryLight = Color(0xFFE8EAF6);
  static const Color primaryDark = Color(0xFF101552);
  static const Color election = Color(0xFF008C95);
  static const Color profile = Color(0xFFC77C00);
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
  static const Color shadow = Color(0x33263238);
  static const Color authCardSurface = Color(0xF7FFFFFF);
  static const double cardRadius = 24;
  static const double authCardRadius = cardRadius;
  static const double inputRadius = 16;
  static const double buttonRadius = 16;
  static const double authHeaderHeight = 52;
  static const double authLogoSize = 96;
  static const double authLogoGap = 28;
  static const double pageHorizontalPadding = 20;
  static const double pageVerticalPadding = 24;

  static const String appLogo = 'assets/images/vetoapp.png';
  static const String iranMap = 'assets/images/persianmap.png';

  static const BoxDecoration pageBackground = BoxDecoration(color: background);

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: authCardSurface,
    borderRadius: BorderRadius.circular(authCardRadius),
    border: Border.all(color: divider),
    boxShadow: [
      BoxShadow(
        color: shadow.withValues(alpha: 0.16),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration get authCardDecoration => cardDecoration;

  static BoxDecoration get authHeaderDecoration => BoxDecoration(
    color: primary,
    borderRadius: BorderRadius.circular(buttonRadius),
    boxShadow: [
      BoxShadow(
        color: primary.withValues(alpha: 0.24),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ],
  );

  static const TextStyle authHeaderTextStyle = TextStyle(
    fontFamily: fontFamily,
    color: surface,
    fontSize: 21,
    fontWeight: FontWeight.w700,
  );

  static const List<Shadow> textShadows = <Shadow>[];

  static TextStyle getTitleStyle({
    double fontSize = 20,
    Color color = textPrimary,
    double? letterSpacing,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
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
      shadow: shadow,
      scrim: shadow,
      inverseSurface: textPrimary,
      onInverseSurface: surface,
      inversePrimary: primaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      cardColor: surface,
      iconTheme: const IconThemeData(color: textPrimary),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: fontFamily, color: textPrimary),
        bodyMedium: TextStyle(fontFamily: fontFamily, color: textPrimary),
        bodySmall: TextStyle(fontFamily: fontFamily, color: textSecondary),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
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
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: surface,
          disabledBackgroundColor: divider,
          disabledForegroundColor: textSecondary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontSize: 17,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(fontFamily: fontFamily, color: surface),
        actionTextColor: primaryLight,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: textSecondary,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
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
