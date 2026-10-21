// Game layer on top of Lal Sabuj: colours the design system does not cover,
// such as the map, routes, money and trip progress.
//
// Read them in widgets with: Theme.of(context).extension<GameColors>()!

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'lal_sabuj_tokens.dart';

@immutable
class GameColors extends ThemeExtension<GameColors> {
  const GameColors({
    required this.mapLand,
    required this.mapRiver,
    required this.mapBorder,
    required this.routeIdle,
    required this.routeActive,
    required this.routeMainCorridor,
    required this.routeBlocked,
    required this.cityNode,
    required this.terminalNode,
    required this.onTerminalNode,
    required this.moneyGain,
    required this.moneyLoss,
    required this.demandLow,
    required this.demandHigh,
    required this.tripProgress,
    required this.tripTrack,
    required this.turboBadge,
    required this.onTurboBadge,
    required this.routeStrokeWidth,
  });

  /// Land fill on the schematic map.
  final Color mapLand;

  /// Rivers. The one blue in the game: Lal Sabuj has no blue, and rivers
  /// must read as water at a glance.
  final Color mapRiver;

  /// Country outline.
  final Color mapBorder;

  /// A route with no vehicle on it.
  final Color routeIdle;

  /// A route with at least one vehicle running.
  final Color routeActive;

  /// The Dhaka-Chattogram N1 corridor.
  final Color routeMainCorridor;

  /// A route closed by an event (hartal, tailback, flood).
  final Color routeBlocked;

  /// A city without a terminal.
  final Color cityNode;

  /// A city where the player owns a terminal.
  final Color terminalNode;

  /// Icon or label on a terminal node.
  final Color onTerminalNode;

  /// Income, profit, positive change.
  final Color moneyGain;

  /// Costs, fines, negative change.
  final Color moneyLoss;

  /// Empty end of a demand bar.
  final Color demandLow;

  /// Full end of a demand bar.
  final Color demandHigh;

  /// Filled part of a trip progress bar.
  final Color tripProgress;

  /// Unfilled track behind a trip progress bar.
  final Color tripTrack;

  /// Turbo Start badge fill.
  final Color turboBadge;

  /// Text on the turbo badge.
  final Color onTurboBadge;

  /// Route line width on the map, in logical pixels.
  final double routeStrokeWidth;

  factory GameColors.fromPalette(LalSabujPalette p, {required bool dark}) {
    return GameColors(
      mapLand: p.surfaceRaised,
      mapRiver: dark ? const Color(0xFF1B3A47) : const Color(0xFFCFE3EC),
      mapBorder: p.inkMuted,
      routeIdle: p.inkMuted,
      routeActive: p.sabuj,
      routeMainCorridor: p.holud,
      routeBlocked: p.lalStrong,
      cityNode: p.ink,
      terminalNode: p.sabuj,
      onTerminalNode: p.onSabuj,
      moneyGain: p.sabuj,
      moneyLoss: p.lalStrong,
      demandLow: p.holudSoft,
      demandHigh: p.holud,
      tripProgress: p.sabuj,
      tripTrack: p.sabujSoft,
      turboBadge: p.holud,
      onTurboBadge: p.onHolud,
      routeStrokeWidth: 3,
    );
  }

  static final light = GameColors.fromPalette(
    LalSabujPalette.light,
    dark: false,
  );
  static final dark = GameColors.fromPalette(LalSabujPalette.dark, dark: true);

  @override
  GameColors copyWith({
    Color? mapLand,
    Color? mapRiver,
    Color? mapBorder,
    Color? routeIdle,
    Color? routeActive,
    Color? routeMainCorridor,
    Color? routeBlocked,
    Color? cityNode,
    Color? terminalNode,
    Color? onTerminalNode,
    Color? moneyGain,
    Color? moneyLoss,
    Color? demandLow,
    Color? demandHigh,
    Color? tripProgress,
    Color? tripTrack,
    Color? turboBadge,
    Color? onTurboBadge,
    double? routeStrokeWidth,
  }) {
    return GameColors(
      mapLand: mapLand ?? this.mapLand,
      mapRiver: mapRiver ?? this.mapRiver,
      mapBorder: mapBorder ?? this.mapBorder,
      routeIdle: routeIdle ?? this.routeIdle,
      routeActive: routeActive ?? this.routeActive,
      routeMainCorridor: routeMainCorridor ?? this.routeMainCorridor,
      routeBlocked: routeBlocked ?? this.routeBlocked,
      cityNode: cityNode ?? this.cityNode,
      terminalNode: terminalNode ?? this.terminalNode,
      onTerminalNode: onTerminalNode ?? this.onTerminalNode,
      moneyGain: moneyGain ?? this.moneyGain,
      moneyLoss: moneyLoss ?? this.moneyLoss,
      demandLow: demandLow ?? this.demandLow,
      demandHigh: demandHigh ?? this.demandHigh,
      tripProgress: tripProgress ?? this.tripProgress,
      tripTrack: tripTrack ?? this.tripTrack,
      turboBadge: turboBadge ?? this.turboBadge,
      onTurboBadge: onTurboBadge ?? this.onTurboBadge,
      routeStrokeWidth: routeStrokeWidth ?? this.routeStrokeWidth,
    );
  }

  @override
  GameColors lerp(ThemeExtension<GameColors>? other, double t) {
    if (other is! GameColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return GameColors(
      mapLand: c(mapLand, other.mapLand),
      mapRiver: c(mapRiver, other.mapRiver),
      mapBorder: c(mapBorder, other.mapBorder),
      routeIdle: c(routeIdle, other.routeIdle),
      routeActive: c(routeActive, other.routeActive),
      routeMainCorridor: c(routeMainCorridor, other.routeMainCorridor),
      routeBlocked: c(routeBlocked, other.routeBlocked),
      cityNode: c(cityNode, other.cityNode),
      terminalNode: c(terminalNode, other.terminalNode),
      onTerminalNode: c(onTerminalNode, other.onTerminalNode),
      moneyGain: c(moneyGain, other.moneyGain),
      moneyLoss: c(moneyLoss, other.moneyLoss),
      demandLow: c(demandLow, other.demandLow),
      demandHigh: c(demandHigh, other.demandHigh),
      tripProgress: c(tripProgress, other.tripProgress),
      tripTrack: c(tripTrack, other.tripTrack),
      turboBadge: c(turboBadge, other.turboBadge),
      onTurboBadge: c(onTurboBadge, other.onTurboBadge),
      routeStrokeWidth:
          lerpDouble(routeStrokeWidth, other.routeStrokeWidth, t) ??
          routeStrokeWidth,
    );
  }
}
