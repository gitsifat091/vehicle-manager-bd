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
  }) : vehicles = List.unmodifiable(vehicles),
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

  /// What [vehicle] is doing at [now].
  VehicleActivity activityOf(Vehicle vehicle, DateTime now) {
    return vehicleActivity(
      vehicle: vehicle,
      activeTrip: activeTripByVehicle[vehicle.id],
      now: now,
    );
  }
}
