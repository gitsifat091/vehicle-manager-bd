// Lal Sabuj design tokens, copied from the Lal Sabuj design system
// (tokens.json, version 1). Change values there first, then mirror them here.
//
// Game-only colours (map, routes, money) live in game_colors.dart.

import 'package:flutter/painting.dart';

/// One set of colour tokens for a single theme (light or dark).
class LalSabujPalette {
  const LalSabujPalette({
    required this.surface,
    required this.surfaceRaised,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.sabuj,
    required this.sabujSoft,
    required this.onSabuj,
    required this.lal,
    required this.onLal,
    required this.lalStrong,
    required this.onLalStrong,
    required this.lalSoft,
    required this.holud,
    required this.onHolud,
    required this.holudSoft,
  });

  /// Page background.
  final Color surface;

  /// Cards, sheets, menus and inputs, one step above surface.
  final Color surfaceRaised;

  /// Hairlines and dividers only. Never control borders.
  final Color line;

  /// Primary text.
  final Color ink;

  /// Secondary text, placeholders and control borders.
  final Color inkMuted;

  /// The flag green. Primary actions, selection, links.
  final Color sabuj;

  /// Tinted background behind sabuj or ink text.
  final Color sabujSoft;

  /// Text and icons on a sabuj fill.
  final Color onSabuj;

  /// The flag red. Hero mark and large numerals (24 px and up) only.
  final Color lal;

  /// Text on a lal fill. Not in tokens.json; chosen for contrast on lal.
  final Color onLal;

  /// Danger and error text, destructive actions.
  final Color lalStrong;

  /// Text on a lalStrong fill. Not in tokens.json; chosen for contrast.
  final Color onLalStrong;

  /// Tinted background behind error messages.
  final Color lalSoft;

  /// Turmeric gold. Highlights, warnings, festive accents.
  final Color holud;

  /// Text and icons on a holud fill.
  final Color onHolud;

  /// Tinted background behind warnings.
  final Color holudSoft;

  /// Links follow sabuj.
  Color get link => sabuj;

  /// Keyboard focus ring follows sabuj.
  Color get focusRing => sabuj;

  static const light = LalSabujPalette(
    surface: Color(0xFFFBF8F1),
    surfaceRaised: Color(0xFFFFFFFF),
    line: Color(0xFFD9D2BF),
    ink: Color(0xFF14231C),
    inkMuted: Color(0xFF56625B),
    sabuj: Color(0xFF006A4E),
    sabujSoft: Color(0xFFDCEFE5),
    onSabuj: Color(0xFFFFFFFF),
    lal: Color(0xFFF42A41),
    onLal: Color(0xFFFFFFFF),
    lalStrong: Color(0xFFB3121F),
    onLalStrong: Color(0xFFFFFFFF),
    lalSoft: Color(0xFFFDE3E5),
    holud: Color(0xFFE0A42B),
    onHolud: Color(0xFF14231C),
    holudSoft: Color(0xFFFBF0D5),
  );

  static const dark = LalSabujPalette(
    surface: Color(0xFF0E1915),
    surfaceRaised: Color(0xFF16241E),
    line: Color(0xFF33463C),
    ink: Color(0xFFEEF3EE),
    inkMuted: Color(0xFFA3B3AA),
    sabuj: Color(0xFF3CC08C),
    sabujSoft: Color(0xFF123528),
    onSabuj: Color(0xFF0E1915),
    lal: Color(0xFFFF4D5E),
    onLal: Color(0xFF0E1915),
    lalStrong: Color(0xFFFF8A94),
    onLalStrong: Color(0xFF0E1915),
    lalSoft: Color(0xFF3D1418),
    holud: Color(0xFFF2C25A),
    onHolud: Color(0xFF0E1915),
    holudSoft: Color(0xFF3A2C0B),
  );
}

/// Spacing scale on a 4 px base.
abstract final class Space {
  /// Icon to label gaps.
  static const double s1 = 4;

  /// Gaps inside controls and between related items.
  static const double s2 = 8;

  /// Card and input padding, default stack gap.
  static const double s4 = 16;

  /// Section padding on mobile, gutters between cards.
  static const double s6 = 24;

  /// Gaps between page sections.
  static const double s8 = 32;
}

/// Corner radii.
abstract final class Radii {
  /// Badges, chips, checkboxes.
  static const double sm = 4;

  /// Buttons, inputs, cards.
  static const double md = 8;

  /// Pills, avatars, the sun disc.
  static const double full = 9999;
}

/// Font family names. They must match the families declared in pubspec.yaml.
/// Fonts are bundled as assets so the game works fully offline.
abstract final class Fonts {
  /// Headings and big numbers.
  static const String display = 'AnekBangla';

  /// Everything else.
  static const String sans = 'HindSiliguri';

  /// Fallbacks when a glyph is missing.
  static const List<String> fallback = ['NotoSansBengali'];
}
