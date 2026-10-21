import 'route_state.dart';
import 'trip.dart';
import 'vehicle.dart';

/// Everything one step of the game changes, as absolute values.
///
/// It is both what the simulator returns and what is written to disk first as
/// the pending record. Because every field is an absolute value (the new cash
/// total, the whole trip), applying a change set twice gives the same result
/// as applying it once. That is what makes a crash in the middle harmless.
class ChangeSet {
  ChangeSet({
    required this.cashAfter,
    required this.completedTripsAfter,
    List<Vehicle> vehicles = const [],
    List<Trip> trips = const [],
    List<RouteState> routeStates = const [],
  }) : vehicles = List.unmodifiable(vehicles),
       trips = List.unmodifiable(trips),
       routeStates = List.unmodifiable(routeStates);

  /// The company's cash after the change, not the amount to add.
  final int cashAfter;
  final int completedTripsAfter;
  final List<Vehicle> vehicles;

  /// New trips and trips that changed (settled, with their final costs).
  final List<Trip> trips;
  final List<RouteState> routeStates;

  /// True when there is nothing to write. Cash only changes through settled
  /// trips, so an empty list of trips means cash is unchanged too.
  bool get isEmpty => vehicles.isEmpty && trips.isEmpty && routeStates.isEmpty;

  /// Trips in this change that are paid out.
  Iterable<Trip> get settledTrips => trips.where((t) => t.settled);

  @override
  String toString() =>
      'ChangeSet(cash: $cashAfter, trips: ${trips.length}, '
      'vehicles: ${vehicles.length}, routes: ${routeStates.length})';
}
