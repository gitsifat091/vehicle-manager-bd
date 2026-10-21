import '../../core/config/economy_config.dart';

/// The player's company. One per save.
///
/// [createdAt] anchors the game days (demand resets at each day boundary).
/// [turboElapsed] is the foreground play time used up by Turbo Start.
class Company {
  Company({
    required this.name,
    required this.cash,
    required DateTime createdAt,
    this.completedTrips = 0,
    this.turboElapsed = Duration.zero,
  }) : createdAt = createdAt.toUtc();

  /// A fresh company with the config's starting cash.
  factory Company.newGame({
    required EconomyConfig config,
    required String name,
    required DateTime now,
  }) {
    return Company(
      name: name,
      cash: config.settings.startingCash,
      createdAt: now,
    );
  }

  final String name;

  /// Whole Taka. Can go negative only if a rule allows debt later.
  final int cash;
  final DateTime createdAt;

  /// Trips settled so far. Drives unlocks such as "5 deliveries".
  final int completedTrips;

  /// Foreground play time so far. It only grows while the app is in the
  /// foreground, so time away does not use up the Turbo Start.
  final Duration turboElapsed;

  Company copyWith({
    String? name,
    int? cash,
    int? completedTrips,
    Duration? turboElapsed,
  }) {
    return Company(
      name: name ?? this.name,
      cash: cash ?? this.cash,
      createdAt: createdAt,
      completedTrips: completedTrips ?? this.completedTrips,
      turboElapsed: turboElapsed ?? this.turboElapsed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Company &&
      other.name == name &&
      other.cash == cash &&
      other.createdAt == createdAt &&
      other.completedTrips == completedTrips &&
      other.turboElapsed == turboElapsed;

  @override
  int get hashCode =>
      Object.hash(name, cash, createdAt, completedTrips, turboElapsed);

  @override
  String toString() =>
      'Company($name, cash: $cash, completedTrips: $completedTrips)';
}
