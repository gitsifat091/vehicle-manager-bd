import 'day_rollup.dart';
import 'route_state.dart';
import 'trip.dart';
import 'vehicle.dart';

/// Everything one step of the game changes, as absolute values.
///
/// It is both what the simulator returns and what is written to disk first as
/// the pending record. Because every field is an absolute value (the new cash
/// total, the whole trip), applying a change set twice gives the same result
/// as applying it once. That is what makes a crash in the middle harmless.
///
/// The optional company fields ([permitsAfter], [lifetimeRevenueAfter],
/// [lifetimeCostsAfter]) are null when the change leaves them as they are.
class ChangeSet {
  ChangeSet({
    required this.cashAfter,
    required this.completedTripsAfter,
    List<Vehicle> vehicles = const [],
    List<String> removedVehicleIds = const [],
    List<Trip> trips = const [],
    List<String> removedTripIds = const [],
    List<RouteState> routeStates = const [],
    Set<String>? permitsAfter,
    this.lifetimeRevenueAfter,
    this.lifetimeCostsAfter,
    List<DayRollup> dayRollups = const [],
  }) : vehicles = List.unmodifiable(vehicles),
       removedVehicleIds = List.unmodifiable(removedVehicleIds),
       trips = List.unmodifiable(trips),
       removedTripIds = List.unmodifiable(removedTripIds),
       routeStates = List.unmodifiable(routeStates),
       permitsAfter = permitsAfter == null
           ? null
           : Set.unmodifiable(permitsAfter),
       dayRollups = List.unmodifiable(dayRollups);

  /// The company's cash after the change, not the amount to add.
  final int cashAfter;
  final int completedTripsAfter;

  /// New vehicles (a purchase) and vehicles that changed.
  final List<Vehicle> vehicles;

  /// Vehicles to delete (a sale). Deleting one that is already gone is
  /// harmless, so this is safe to repeat too.
  final List<String> removedVehicleIds;

  /// New trips and trips that changed (settled, with their final costs).
  final List<Trip> trips;

  /// Old settled trips to delete (pruning). Only trips already counted in
  /// the lifetime totals and day rollups, so nothing is lost.
  final List<String> removedTripIds;
  final List<RouteState> routeStates;

  /// Every permit the company owns after the change (a permit purchase).
  final Set<String>? permitsAfter;

  /// `Company.lifetimeRevenue` after the trips settled in this change.
  final int? lifetimeRevenueAfter;

  /// `Company.lifetimeCosts` after the trips settled in this change.
  final TripCosts? lifetimeCostsAfter;

  /// The whole rollup of every game day a settled trip in this change counts
  /// towards, including what was counted before.
  final List<DayRollup> dayRollups;

  /// True when there is nothing to write. Cash and the lifetime totals only
  /// change through settled trips or a purchase, which always come with a
  /// trip, a vehicle or a permit set, so those are not checked.
  bool get isEmpty =>
      vehicles.isEmpty &&
      removedVehicleIds.isEmpty &&
      trips.isEmpty &&
      removedTripIds.isEmpty &&
      routeStates.isEmpty &&
      permitsAfter == null &&
      dayRollups.isEmpty;

  /// The same change that also prunes [tripIds].
  ChangeSet withRemovedTrips(List<String> tripIds) => ChangeSet(
    cashAfter: cashAfter,
    completedTripsAfter: completedTripsAfter,
    vehicles: vehicles,
    removedVehicleIds: removedVehicleIds,
    trips: trips,
    removedTripIds: [...removedTripIds, ...tripIds],
    routeStates: routeStates,
    permitsAfter: permitsAfter,
    lifetimeRevenueAfter: lifetimeRevenueAfter,
    lifetimeCostsAfter: lifetimeCostsAfter,
    dayRollups: dayRollups,
  );

  /// Trips in this change that are paid out.
  Iterable<Trip> get settledTrips => trips.where((t) => t.settled);

  @override
  String toString() =>
      'ChangeSet(cash: $cashAfter, trips: ${trips.length}, '
      'pruned: ${removedTripIds.length}, '
      'vehicles: ${vehicles.length}, removed: ${removedVehicleIds.length}, '
      'routes: ${routeStates.length}, days: ${dayRollups.length})';
}
