/// A vehicle the player owns. The static specs (price, payload, speed) stay in
/// the config and are found through [tier].
///
/// The assignment (route, cargo, overload) is what a Local haul repeats when
/// it auto-redispatches. Whether the vehicle is on the road is not stored
/// here: it is derived from its unsettled trip.
class Vehicle {
  Vehicle({
    required this.id,
    required this.tier,
    required DateTime purchasedAt,
    this.assignedRouteId,
    this.assignedCargo,
    this.overloadT = 0,
  }) : purchasedAt = purchasedAt.toUtc(),
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

  bool get isAssigned => assignedRouteId != null;

  Vehicle withAssignment({
    required String routeId,
    required String cargoName,
    double overloadT = 0,
  }) {
    return Vehicle(
      id: id,
      tier: tier,
      purchasedAt: purchasedAt,
      assignedRouteId: routeId,
      assignedCargo: cargoName,
      overloadT: overloadT,
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
      other.overloadT == overloadT;

  @override
  int get hashCode => Object.hash(
    id,
    tier,
    purchasedAt,
    assignedRouteId,
    assignedCargo,
    overloadT,
  );

  @override
  String toString() => 'Vehicle($id, tier $tier, route: $assignedRouteId)';
}
