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
    );
  }

  Vehicle withoutAssignment() {
    return Vehicle(id: id, tier: tier, purchasedAt: purchasedAt);
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
      other.availableAt == availableAt;

  @override
  int get hashCode => Object.hash(
    id,
    tier,
    purchasedAt,
    assignedRouteId,
    assignedCargo,
    overloadT,
    availableAt,
  );

  @override
  String toString() => 'Vehicle($id, tier $tier, route: $assignedRouteId)';
}
