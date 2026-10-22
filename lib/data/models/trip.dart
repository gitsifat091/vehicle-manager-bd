import '../../core/economy/trip_quote.dart';

/// The cost parts of one trip, in whole Taka.
class TripCosts {
  const TripCosts({
    required this.energy,
    required this.toll,
    required this.crew,
    required this.maintenance,
    required this.fines,
    required this.accident,
  });

  /// Rounds each part of a quote to whole Taka.
  factory TripCosts.fromQuote(TripQuote quote) {
    return TripCosts(
      energy: quote.energyTk,
      toll: quote.tollTk,
      crew: quote.crewTk,
      maintenance: quote.maintenanceTk,
      fines: quote.expectedFinesTk,
      accident: quote.expectedAccidentTk,
    );
  }

  /// No costs, the start of a sum.
  static const zero = TripCosts(
    energy: 0,
    toll: 0,
    crew: 0,
    maintenance: 0,
    fines: 0,
    accident: 0,
  );

  final int energy;
  final int toll;
  final int crew;
  final int maintenance;
  final int fines;
  final int accident;

  int get total => energy + toll + crew + maintenance + fines + accident;

  /// Part by part sum, for lifetime totals and day rollups.
  TripCosts operator +(TripCosts other) => TripCosts(
    energy: energy + other.energy,
    toll: toll + other.toll,
    crew: crew + other.crew,
    maintenance: maintenance + other.maintenance,
    fines: fines + other.fines,
    accident: accident + other.accident,
  );

  @override
  bool operator ==(Object other) =>
      other is TripCosts &&
      other.energy == energy &&
      other.toll == toll &&
      other.crew == crew &&
      other.maintenance == maintenance &&
      other.fines == fines &&
      other.accident == accident;

  @override
  int get hashCode =>
      Object.hash(energy, toll, crew, maintenance, fines, accident);

  @override
  String toString() => 'TripCosts(total: $total)';
}

/// One dispatched trip. Progress is never simulated: position and arrival are
/// computed from [departAt] and [arriveAt], so offline progress is free.
class Trip {
  Trip({
    required this.id,
    required this.vehicleId,
    required this.vehicleTier,
    required this.routeId,
    required this.cargo,
    required this.loadT,
    required DateTime departAt,
    required DateTime arriveAt,
    required this.revenue,
    required this.costs,
    this.settled = false,
  }) : departAt = departAt.toUtc(),
       arriveAt = arriveAt.toUtc();

  final String id;
  final String vehicleId;

  /// Tier of the vehicle, kept so the trip can be settled on its own.
  final int vehicleTier;
  final String routeId;

  /// Cargo name, as in the config.
  final String cargo;
  final double loadT;

  /// Real UTC timestamps.
  final DateTime departAt;
  final DateTime arriveAt;

  /// Whole Taka.
  final int revenue;
  final TripCosts costs;

  /// True once the trip's money has been paid into the company.
  final bool settled;

  int get profit => revenue - costs.total;

  /// True when the trip has reached its destination at [now].
  bool hasArrivedBy(DateTime now) => !arriveAt.isAfter(now);

  /// How far along the trip is at [now], from 0 (just left) to 1 (arrived),
  /// worked out from the timestamps only.
  double progressAt(DateTime now) {
    final total = arriveAt.difference(departAt).inMicroseconds;
    if (total <= 0) return 1;
    final done = now.difference(departAt).inMicroseconds;
    return (done / total).clamp(0.0, 1.0);
  }

  Trip copyWith({int? revenue, TripCosts? costs, bool? settled}) {
    return Trip(
      id: id,
      vehicleId: vehicleId,
      vehicleTier: vehicleTier,
      routeId: routeId,
      cargo: cargo,
      loadT: loadT,
      departAt: departAt,
      arriveAt: arriveAt,
      revenue: revenue ?? this.revenue,
      costs: costs ?? this.costs,
      settled: settled ?? this.settled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Trip &&
      other.id == id &&
      other.vehicleId == vehicleId &&
      other.vehicleTier == vehicleTier &&
      other.routeId == routeId &&
      other.cargo == cargo &&
      other.loadT == loadT &&
      other.departAt == departAt &&
      other.arriveAt == arriveAt &&
      other.revenue == revenue &&
      other.costs == costs &&
      other.settled == settled;

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    vehicleTier,
    routeId,
    cargo,
    loadT,
    departAt,
    arriveAt,
    revenue,
    costs,
    settled,
  );

  @override
  String toString() => 'Trip($id, $vehicleId on $routeId, settled: $settled)';
}
