/// A vehicle the player owns. The static specs (price, payload, speed) stay in
/// the config and are found through [tier].
///
/// The assignment (route, cargo, overload) is what a Local haul repeats when
/// it auto-redispatches, starting at [availableAt]. Whether the vehicle is on
/// the road is not stored here: it is derived from its unsettled trip.
class Vehicle {
  Vehicle({
    required this.id,
    required this.tier,
    required DateTime purchasedAt,
    this.assignedRouteId,
    this.assignedCargo,
    this.overloadT = 0,
    DateTime? availableAt,
    this.isStarter = false,
  }) : purchasedAt = purchasedAt.toUtc(),
       availableAt = availableAt?.toUtc(),
       assert(
         (assignedRouteId == null) == (assignedCargo == null),
         'assignedRouteId and assignedCargo are set together',
       );

  final String id;
  final int tier;
  final DateTime purchasedAt;
  final String? assignedRouteId;

  /// Cargo name, as in the config.
  final String? assignedCargo;

  /// Tons above the legal payload that the player chose with the slider.
  final double overloadT;

  /// When an assigned vehicle is free to depart again: the moment it was
  /// assigned, the arrival of its last trip, or the start of the next game day
  /// when it is waiting for demand. Null when not assigned.
  final DateTime? availableAt;

  /// True for the free vehicle a new company starts with. It sells for
  /// `settings.starterSaleValue`, not the resale share of its price. False in
  /// saves from before the flag existed.
  final bool isStarter;

  bool get isAssigned => assignedRouteId != null;

  Vehicle withAssignment({
    required String routeId,
    required String cargoName,
    double overloadT = 0,
    required DateTime availableAt,
  }) {
    return Vehicle(
      id: id,
      tier: tier,
      purchasedAt: purchasedAt,
      assignedRouteId: routeId,
      assignedCargo: cargoName,
      overloadT: overloadT,
      availableAt: availableAt,
      isStarter: isStarter,
    );
  }

  /// The same assignment, free to depart again at [availableAt].
  Vehicle withAvailableAt(DateTime availableAt) {
    return Vehicle(
      id: id,
      tier: tier,
      purchasedAt: purchasedAt,
      assignedRouteId: assignedRouteId,
      assignedCargo: assignedCargo,
      overloadT: overloadT,
      availableAt: availableAt,
      isStarter: isStarter,
    );
  }

  Vehicle withoutAssignment() {
    return Vehicle(
      id: id,
      tier: tier,
      purchasedAt: purchasedAt,
      isStarter: isStarter,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Vehicle &&
      other.id == id &&
      other.tier == tier &&
      other.purchasedAt == purchasedAt &&
      other.assignedRouteId == assignedRouteId &&
      other.assignedCargo == assignedCargo &&
      other.overloadT == overloadT &&
      other.availableAt == availableAt &&
      other.isStarter == isStarter;

  @override
  int get hashCode => Object.hash(
    id,
    tier,
    purchasedAt,
    assignedRouteId,
    assignedCargo,
    overloadT,
    availableAt,
    isStarter,
  );

  @override
  String toString() => 'Vehicle($id, tier $tier, route: $assignedRouteId)';
}
