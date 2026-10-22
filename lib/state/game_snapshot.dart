import '../core/config/economy_config.dart';
import '../core/economy/purchase_rules.dart' as rules;
import '../core/sim/vehicle_status.dart';
import '../data/models/models.dart';

/// A read-only copy of the saved game, built by [GameEngine.snapshot].
///
/// Screens read this instead of the database. The engine builds a new one
/// after every change it announces, so `context.select` on the snapshot
/// rebuilds a widget only when the game really changed. Anything that moves
/// with time (progress bars, the turbo speed) is computed from [DateTime]s on
/// the UI clock, not stored here.
///
/// `company.turboElapsed` is not kept up to date between ticks. Use
/// `GameEngine.turboElapsed` for that.
class GameSnapshot {
  GameSnapshot({
    required this.company,
    required Iterable<Vehicle> vehicles,
    required Iterable<Trip> activeTrips,
    required Iterable<RouteState> routeStates,
    required this.settings,
    Iterable<Trip> settledTrips = const [],
  }) : vehicles = List.unmodifiable(vehicles),
       recentTripsByVehicle = _recentByVehicle(settledTrips),
       activeTripByVehicle = Map.unmodifiable({
         for (final t in activeTrips) t.vehicleId: t,
       }),
       routeStateById = Map.unmodifiable({
         for (final r in routeStates) r.routeId: r,
       });

  /// Null before a game is started.
  final Company? company;

  /// Oldest purchase first.
  final List<Vehicle> vehicles;

  /// The unsettled trip of each vehicle that is on the road, by vehicle id.
  final Map<String, Trip> activeTripByVehicle;

  final Map<String, RouteState> routeStateById;
  final EconomySettings settings;

  /// The newest settled trips of each vehicle, newest first, at most
  /// [recentTripsPerVehicle] each. Taken from the trips the engine keeps
  /// (`GameEngine.keptSettledTrips`), so older ones are gone.
  final Map<String, List<Trip>> recentTripsByVehicle;

  /// How many settled trips per vehicle [recentTripsByVehicle] keeps.
  static const recentTripsPerVehicle = 10;

  bool get hasGame => company != null;

  /// Operating permits the company owns.
  Set<String> get permits => company?.permits ?? const {};

  int get garageSlots => rules.garageSlots(settings);

  int get freeGarageSlots =>
      rules.freeGarageSlots(settings: settings, vehiclesOwned: vehicles.length);

  Vehicle? vehicleById(String id) {
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// The newest settled trips of [vehicleId], newest first. Empty when it
  /// has none.
  List<Trip> recentTripsOf(String vehicleId) =>
      recentTripsByVehicle[vehicleId] ?? const [];

  /// What [vehicle] is doing at [now].
  VehicleActivity activityOf(Vehicle vehicle, DateTime now) {
    return vehicleActivity(
      vehicle: vehicle,
      activeTrip: activeTripByVehicle[vehicle.id],
      now: now,
    );
  }
}

Map<String, List<Trip>> _recentByVehicle(Iterable<Trip> settled) {
  final byVehicle = <String, List<Trip>>{};
  for (final t in settled) {
    if (t.settled) (byVehicle[t.vehicleId] ??= []).add(t);
  }
  return Map.unmodifiable({
    for (final e in byVehicle.entries)
      e.key: List<Trip>.unmodifiable(
        (e.value..sort((a, b) {
              final byArrival = b.arriveAt.compareTo(a.arriveAt);
              return byArrival != 0 ? byArrival : b.id.compareTo(a.id);
            }))
            .take(GameSnapshot.recentTripsPerVehicle),
      ),
  });
}
