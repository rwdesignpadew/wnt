import 'package:flutter/material.dart';
import 'wnt_colors.dart';

abstract final class WntTheme {
  static ThemeData light() {
    final textTheme = ThemeData.light().textTheme.apply(
      fontFamily: 'Outfit',
      bodyColor: WntColors.ink,
      displayColor: WntColors.ink,
    );
    const radius = BorderRadius.all(Radius.circular(8));

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Outfit',
      brightness: Brightness.light,
      scaffoldBackgroundColor: WntColors.canvas,
      colorScheme: const ColorScheme.light(
        primary: WntColors.brand,
        onPrimary: Colors.white,
        surface: WntColors.surface,
        onSurface: WntColors.ink,
        error: WntColors.error,
      ),
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 16),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 14),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: WntColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: WntColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: WntColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: WntColors.muted),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: WntColors.text,
          fontWeight: FontWeight.w600,
        ),
        border: const OutlineInputBorder(borderRadius: radius),
        enabledBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: WntColors.inputLine),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: WntColors.brand, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: WntColors.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: WntColors.brand,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: WntColors.text,
          side: const BorderSide(color: WntColors.inputLine),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: WntColors.brandSoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontSize: 10,
            height: 1,
            letterSpacing: -0.25,
            color: states.contains(WidgetState.selected)
                ? WntColors.brand
                : WntColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? WntColors.brand
                : WntColors.muted,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: WntColors.line, space: 1),
    );
  }
}
