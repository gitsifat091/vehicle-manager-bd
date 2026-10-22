import 'package:hive_ce/hive_ce.dart';

import '../models/models.dart';
import 'box_repository.dart';

/// The single company of a save.
class CompanyRepository {
  CompanyRepository(this.box);

  static const _key = 'company';

  final Box<Company> box;

  bool get exists => box.containsKey(_key);

  /// The saved company, or null before a new game is started.
  Company? load() => box.get(_key);

  Future<void> save(Company company) => box.put(_key, company);

  Future<void> clear() => box.clear();
}

/// The change set that is being written to disk right now, if any.
///
/// It is written in a single put before anything else, so a crash leaves
/// either nothing or a complete record that startup can finish.
class PendingChangeRepository {
  PendingChangeRepository(this.box);

  static const _key = 'pending';

  final Box<ChangeSet> box;

  ChangeSet? load() => box.get(_key);

  Future<void> save(ChangeSet change) => box.put(_key, change);

  Future<void> clear() => box.delete(_key);
}

class VehicleRepository extends BoxRepository<Vehicle> {
  VehicleRepository(super.box);

  @override
  String keyOf(Vehicle item) => item.id;

  List<Vehicle> byTier(int tier) => all().where((v) => v.tier == tier).toList();
}

class TerminalRepository extends BoxRepository<Terminal> {
  TerminalRepository(super.box);

  @override
  String keyOf(Terminal item) => item.id;

  Terminal? atLocation(String location) {
    for (final t in box.values) {
      if (t.location == location) return t;
    }
    return null;
  }
}

class RouteStateRepository extends BoxRepository<RouteState> {
  RouteStateRepository(super.box);

  @override
  String keyOf(RouteState item) => item.routeId;
}

/// One [DayRollup] per game day that had a settled trip, keyed by the day.
class DayRollupRepository extends BoxRepository<DayRollup> {
  DayRollupRepository(super.box);

  @override
  String keyOf(DayRollup item) => keyOfDay(item.gameDay);

  static String keyOfDay(int gameDay) => '$gameDay';

  /// The rollup of [gameDay], or null when no trip was settled that day.
  DayRollup? forDay(int gameDay) => get(keyOfDay(gameDay));

  /// Every rollup, earliest day first.
  List<DayRollup> byDay() =>
      all()..sort((a, b) => a.gameDay.compareTo(b.gameDay));
}

class TripRepository extends BoxRepository<Trip> {
  TripRepository(super.box);

  @override
  String keyOf(Trip item) => item.id;

  List<Trip> forVehicle(String vehicleId) =>
      all().where((t) => t.vehicleId == vehicleId).toList();

  /// Trips not yet paid out, earliest arrival first.
  List<Trip> unsettled() => _byArrival(all().where((t) => !t.settled));

  /// Unsettled trips that have arrived by [now], in the order they must be
  /// settled (earliest arrival first, ties broken by departure then id).
  List<Trip> dueAt(DateTime now) =>
      _byArrival(all().where((t) => !t.settled && t.hasArrivedBy(now)));

  /// The vehicle's unsettled trip, if it is on the road.
  Trip? activeFor(String vehicleId) {
    for (final t in box.values) {
      if (t.vehicleId == vehicleId && !t.settled) return t;
    }
    return null;
  }

  List<Trip> _byArrival(Iterable<Trip> trips) {
    return trips.toList()..sort((a, b) {
      final byArrival = a.arriveAt.compareTo(b.arriveAt);
      if (byArrival != 0) return byArrival;
      final byDeparture = a.departAt.compareTo(b.departAt);
      if (byDeparture != 0) return byDeparture;
      return a.id.compareTo(b.id);
    });
  }
}
