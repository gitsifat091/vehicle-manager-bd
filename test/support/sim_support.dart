import 'dart:convert';
import 'dart:math';

import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/core/sim/clock.dart';
import 'package:vehicle_manager_bd/core/sim/game_simulator.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';

import '../core/test_config.dart';

/// The instant every sim test starts from.
final t0 = DateTime.utc(2026, 3, 1, 8);

/// A clock the test moves by hand.
class ManualClock implements Clock {
  ManualClock([DateTime? start]) : _now = start ?? t0;

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

/// The default config after [edit] changed the decoded economy.json.
EconomyConfig editedConfig(void Function(Map<String, dynamic> json) edit) {
  final json = jsonDecode(readEconomyJson()) as Map<String, dynamic>;
  edit(json);
  return EconomyConfig.parse(jsonEncode(json));
}

/// The default config with accidents switched off, so cash is exact.
EconomyConfig quietConfig([void Function(Map<String, dynamic> json)? edit]) {
  return editedConfig((json) {
    json['settings']['accidentChancePer100Km'] = 0;
    edit?.call(json);
  });
}

/// Sets the daily demand of one route in an economy.json map.
void setDemand(Map<String, dynamic> json, String routeId, num demandT) {
  final routes = json['routes'] as List<dynamic>;
  final route = routes.firstWhere((r) => r['id'] == routeId);
  route['dailyDemandT'] = demandT;
}

/// Ids like trip_1, trip_2 ... so tests can predict them.
String Function(String prefix) counterIds() {
  var n = 0;
  return (prefix) => '${prefix}_${++n}';
}

/// A vehicle assigned to a route and free to depart at [availableAt].
Vehicle assignedVehicle({
  String id = 'v1',
  int tier = 4,
  String routeId = 'R01',
  String cargo = 'General dry',
  double overloadT = 0,
  DateTime? availableAt,
}) {
  return Vehicle(
    id: id,
    tier: tier,
    purchasedAt: t0,
    assignedRouteId: routeId,
    assignedCargo: cargo,
    overloadT: overloadT,
    availableAt: availableAt ?? t0,
  );
}

SimWorld worldOf({
  Company? company,
  List<Vehicle> vehicles = const [],
  List<Trip> unsettledTrips = const [],
  List<RouteState> routeStates = const [],
  List<DayRollup> dayRollups = const [],
}) {
  final rollups = {for (final d in dayRollups) d.gameDay: d};
  return SimWorld(
    company: company ?? Company(name: 'Test Ltd', cash: 1500000, createdAt: t0),
    vehicles: vehicles,
    unsettledTrips: unsettledTrips,
    routeStates: routeStates,
    rollupOf: (day) => rollups[day],
  );
}

/// Day rollups saved by [applyChange], and the lookup of the world they
/// started from. Kept beside each world so a long run of changes reads one
/// map and one lookup instead of a chain of closures, which would overflow
/// the stack after a few thousand ticks.
final _savedRollups = Expando<Map<int, DayRollup>>('saved rollups');
final _firstLookup = Expando<DayRollup? Function(int)>('first lookup');

/// The world after [change] was saved, as the next load would see it.
SimWorld applyChange(SimWorld world, ChangeSet change) {
  final vehicles = {for (final v in world.vehicles) v.id: v};
  for (final v in change.vehicles) {
    vehicles[v.id] = v;
  }
  change.removedVehicleIds.forEach(vehicles.remove);
  final rollups = {
    ...?_savedRollups[world],
    for (final d in change.dayRollups) d.gameDay: d,
  };
  final first = _firstLookup[world] ?? world.rollupOf;
  final trips = {for (final t in world.unsettledTrips) t.id: t};
  for (final t in change.trips) {
    trips[t.id] = t;
  }
  final routes = {for (final r in world.routeStates) r.routeId: r};
  for (final r in change.routeStates) {
    routes[r.routeId] = r;
  }
  final next = SimWorld(
    company: world.company.copyWith(
      cash: change.cashAfter,
      completedTrips: change.completedTripsAfter,
      permits: change.permitsAfter,
      lifetimeRevenue: change.lifetimeRevenueAfter,
      lifetimeCosts: change.lifetimeCostsAfter,
    ),
    vehicles: vehicles.values,
    unsettledTrips: trips.values.where((t) => !t.settled),
    routeStates: routes.values,
    rollupOf: (day) => rollups[day] ?? first(day),
  );
  _savedRollups[next] = rollups;
  _firstLookup[next] = first;
  return next;
}

/// A Random that returns the given doubles in order and counts the draws.
class ScriptedRandom implements Random {
  ScriptedRandom(this._values);

  final List<double> _values;
  int draws = 0;

  @override
  double nextDouble() {
    if (draws >= _values.length) {
      throw StateError('ScriptedRandom ran out of values');
    }
    return _values[draws++];
  }

  @override
  bool nextBool() => nextDouble() < 0.5;

  @override
  int nextInt(int max) => (nextDouble() * max).floor();
}
