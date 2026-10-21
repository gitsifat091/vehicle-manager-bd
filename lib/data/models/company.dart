import '../../core/config/economy_config.dart';

/// The player's company. One per save.
///
/// [createdAt] doubles as the Turbo Start clock: the first 60 real minutes
/// after it run at the boosted speeds from the config.
class Company {
  Company({
    required this.name,
    required this.cash,
    required DateTime createdAt,
    this.completedTrips = 0,
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

  Company copyWith({String? name, int? cash, int? completedTrips}) {
    return Company(
      name: name ?? this.name,
      cash: cash ?? this.cash,
      createdAt: createdAt,
      completedTrips: completedTrips ?? this.completedTrips,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Company &&
      other.name == name &&
      other.cash == cash &&
      other.createdAt == createdAt &&
      other.completedTrips == completedTrips;

  @override
  int get hashCode => Object.hash(name, cash, createdAt, completedTrips);

  @override
  String toString() =>
      'Company($name, cash: $cash, completedTrips: $completedTrips)';
}
