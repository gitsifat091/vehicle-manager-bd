// Builds the app's light and dark ThemeData from the Lal Sabuj tokens.
//
// Usage in main.dart:
//   MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, ...)

import 'package:flutter/material.dart';

import 'game_colors.dart';
import 'lal_sabuj_tokens.dart';

abstract final class AppTheme {
  static final ThemeData light = _build(
    LalSabujPalette.light,
    Brightness.light,
  );
  static final ThemeData dark = _build(LalSabujPalette.dark, Brightness.dark);

  static ThemeData _build(LalSabujPalette p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.sabuj,
      onPrimary: p.onSabuj,
      primaryContainer: p.sabujSoft,
      onPrimaryContainer: p.ink,
      secondary: p.holud,
      onSecondary: p.onHolud,
      secondaryContainer: p.holudSoft,
      onSecondaryContainer: p.ink,
      // Lal is identity red: one hero mark per view, never body text.
      tertiary: p.lal,
      onTertiary: p.onLal,
      tertiaryContainer: p.lalSoft,
      onTertiaryContainer: p.ink,
      // Errors use lalStrong so identity red and error red do not compete.
      error: p.lalStrong,
      onError: p.onLalStrong,
      errorContainer: p.lalSoft,
      onErrorContainer: p.lalStrong,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.inkMuted,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surfaceRaised,
      surfaceContainer: p.surfaceRaised,
      surfaceContainerHigh: p.surfaceRaised,
      surfaceContainerHighest: p.surfaceRaised,
      // Control borders use inkMuted so they reach 3:1. Line is for dividers.
      outline: p.inkMuted,
      outlineVariant: p.line,
      inverseSurface: p.ink,
      onInverseSurface: p.surface,
      inversePrimary: isDark
          ? LalSabujPalette.light.sabuj
          : LalSabujPalette.dark.sabuj,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    final text = _textTheme(p);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
    );
    const buttonSize = Size(64, 44);
    const buttonPadding = EdgeInsets.symmetric(horizontal: Space.s4);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.surface,
      fontFamily: Fonts.sans,
      fontFamilyFallback: Fonts.fallback,
      textTheme: text,
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineMedium,
      ),
      cardTheme: CardThemeData(
        color: p.surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: p.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.sabuj,
          foregroundColor: p.onSabuj,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.sabuj,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: shape,
          side: BorderSide(color: p.inkMuted),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.sabuj,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.s4,
          vertical: Space.s2 + 2,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: p.inkMuted),
        border: _inputBorder(p.inkMuted),
        enabledBorder: _inputBorder(p.inkMuted),
        focusedBorder: _inputBorder(p.sabuj, width: 2),
        errorBorder: _inputBorder(p.lalStrong),
        focusedErrorBorder: _inputBorder(p.lalStrong, width: 2),
        errorStyle: text.bodySmall?.copyWith(color: p.lalStrong),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceRaised,
        selectedColor: p.sabujSoft,
        side: BorderSide(color: p.inkMuted),
        labelStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surfaceRaised,
        indicatorColor: p.sabujSoft,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(text.labelLarge),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.sabuj : p.inkMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surfaceRaised,
        indicatorColor: p.sabujSoft,
        selectedIconTheme: IconThemeData(color: p.sabuj),
        unselectedIconTheme: IconThemeData(color: p.inkMuted),
        selectedLabelTextStyle: text.labelLarge?.copyWith(color: p.sabuj),
        unselectedLabelTextStyle: text.labelLarge?.copyWith(color: p.inkMuted),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.sabuj,
        linearTrackColor: p.sabujSoft,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.sabuj,
        inactiveTrackColor: p.sabujSoft,
        thumbColor: p.sabuj,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.surface),
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
      extensions: [isDark ? GameColors.dark : GameColors.light],
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  // Line heights come from tokens.json (lineHeight / fontSize). Bangla needs
  // the taller leading for matras and conjuncts. No letter-spacing anywhere:
  // it breaks the Bangla headstroke.
  static TextTheme _textTheme(LalSabujPalette p) {
    TextStyle style(
      String family,
      double size,
      double lineHeight,
      FontWeight weight,
      Color color,
    ) {
      return TextStyle(
        fontFamily: family,
        fontFamilyFallback: Fonts.fallback,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        color: color,
        letterSpacing: 0,
      );
    }

    return TextTheme(
      // display: hero headings and big numbers. One per screen.
      displayLarge: style(Fonts.display, 48, 56, FontWeight.w600, p.ink),
      // heading-1: page titles.
      headlineLarge: style(Fonts.display, 32, 44, FontWeight.w600, p.ink),
      // heading-2: section titles.
      headlineMedium: style(Fonts.display, 24, 34, FontWeight.w600, p.ink),
      titleLarge: style(Fonts.display, 24, 34, FontWeight.w600, p.ink),
      titleMedium: style(Fonts.sans, 18, 30, FontWeight.w600, p.ink),
      // body-lg: lead paragraphs.
      bodyLarge: style(Fonts.sans, 18, 30, FontWeight.w400, p.ink),
      // body: default text.
      bodyMedium: style(Fonts.sans, 16, 26, FontWeight.w400, p.ink),
      // caption: Latin-only metadata. Never set Bangla this small.
      bodySmall: style(Fonts.sans, 12, 18, FontWeight.w400, p.inkMuted),
      // label: buttons, form labels, tabs. Smallest size for Bangla.
      labelLarge: style(Fonts.sans, 14, 22, FontWeight.w500, p.ink),
      labelMedium: style(Fonts.sans, 14, 22, FontWeight.w500, p.inkMuted),
      labelSmall: style(Fonts.sans, 12, 18, FontWeight.w500, p.inkMuted),
    );
  }
}

/// Extra text styles the game needs that Material's TextTheme does not name.
abstract final class GameText {
  /// Cash, counters and timers. Tabular figures so digits do not jump
  /// while a number ticks up.
  static TextStyle money(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Small numbers inside cards and lists (trip time, demand, payload).
  static TextStyle stat(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

/// Button styles that are not the theme default.
abstract final class AppButtons {
  /// Destructive action (sell vehicle, close terminal): outlined in
  /// lalStrong, never a red fill.
  static ButtonStyle danger(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.styleFrom(
      foregroundColor: scheme.error,
      side: BorderSide(color: scheme.error),
    );
  }
}
