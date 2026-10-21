// Simulates the first hours of play with the real game code and a greedy
// buyer, to check the first-hour pacing against docs/economy_model.xlsx.
//
//   dart run tool/first_hours_sim.dart [hours] [seeds]
//
// Defaults: 3 hours, 20 seeds. It changes no balance numbers: everything comes
// from assets/config/economy.json.
//
// The player model
// - Starts with the starting cash and one free Sathi Plus on R01 (General dry).
// - The app stays in the foreground the whole time and ticks every 3 seconds,
//   so Turbo Start runs for the first 60 minutes.
// - Whenever cash allows, it buys the cheapest useful vehicle and sends it out
//   at once. Useful means: it can run a route that starts in Dhaka (no
//   terminal needed yet), it earns a profit, and the route still has demand
//   left for it. "Demand left" means the route's daily demand minus what the
//   fleet already uses per game day, so the new vehicle would not starve.
// - Line hauls are sent out again as soon as they arrive. Local hauls repeat
//   by themselves.
// - Vehicle unlocks (licenses, deliveries) are not modelled.

// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';
import 'package:vehicle_manager_bd/core/sim/game_calendar.dart';
import 'package:vehicle_manager_bd/core/sim/game_simulator.dart';
import 'package:vehicle_manager_bd/core/sim/turbo.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';

/// Routes that start in Dhaka, so they need no terminal elsewhere.
const dhakaRoutes = {
  'M01', 'M02', 'R01', 'R02', 'R03', 'R04', 'R05', //
  'R07', 'R08', 'R09', 'R10', 'R11', 'R12',
};

const tick = Duration(seconds: 3);

class Policy {
  const Policy(this.name, {required this.minTier, required this.includeLine});

  final String name;

  /// Vehicles below this tier are never bought.
  final int minTier;

  /// Whether Line hauls count as useful. They need the player at every
  /// departure.
  final bool includeLine;
}

void main(List<String> args) {
  final hours = args.isNotEmpty ? int.parse(args[0]) : 3;
  final seeds = args.length > 1 ? int.parse(args[1]) : 20;
  final config = EconomyConfig.parse(
    File('assets/config/economy.json').readAsStringSync(),
  );

  print('First hours simulation, $hours h, default config, $seeds seeds');
  print('Spreadsheet (First Hour sheet): 3 purchases in 60 min, 4 in 4 h, '
      'fleet profit after turbo Tk 2,47,607 per hour at 1x');

  const policies = [
    Policy(
      'POLICY A: all tiers, Local hauls only (pedal vans and 3-wheelers allowed)',
      minTier: 1,
      includeLine: false,
    ),
    Policy(
      'POLICY B: tier 3 and up, Local hauls only (the baseline: no attention '
      'needed after buying)',
      minTier: 3,
      includeLine: false,
    ),
    Policy(
      'POLICY C: tier 3 and up, Local and Line hauls (an attentive player '
      'sends every Line haul out again at once)',
      minTier: 3,
      includeLine: true,
    ),
  ];

  for (final policy in policies) {
    print('');
    print('=' * 72);
    print(policy.name);
    print('=' * 72);

    final runs = [
      for (var seed = 1; seed <= seeds; seed++)
        simulate(
          config: config,
          seed: seed,
          hours: hours,
          policy: policy,
        ),
    ];

    print('');
    print('Seed 1 in detail');
    runs.first.printDetail();

    print('');
    print('Over $seeds seeds (min / median / max)');
    summary('Purchases in hour 1', runs.map((r) => r.purchasesBefore(60)));
    summary(
      'Minutes from turbo end (60) to next purchase',
      runs.map((r) => r.minutesToNextPurchaseAfterTurbo()),
      unit: 'min',
    );
    summary(
      'R01 demand first runs out (real min)',
      runs.map((r) => r.firstR01DryMin),
      unit: 'min',
    );
    summary(
      'R01 dry share of the last hour',
      runs.map((r) => r.r01DryShareOfLastHour * 100),
      unit: '%',
    );
    summary('Vehicles owned at end', runs.map((r) => r.vehicleCount));
    summary('Income in hour 1 (Tk)', runs.map((r) => r.incomeInHour(1)));
    if (hours >= 2) {
      summary('Income in hour 2 (Tk)', runs.map((r) => r.incomeInHour(2)));
    }
    summary(
      'Income in the last hour (Tk)',
      runs.map((r) => r.incomeInHour(hours)),
    );
    summary('Cash at end (Tk)', runs.map((r) => r.finalCash));
  }
}

void summary(String label, Iterable<num?> values, {String unit = ''}) {
  final known = values.whereType<num>().toList()..sort();
  final never = values.length - known.length;
  if (known.isEmpty) {
    print('  $label: never ($never of ${values.length} runs)');
    return;
  }
  String f(num v) => unit == 'min' || unit == '%'
      ? v.toStringAsFixed(1)
      : money(v.round());
  final suffix = unit.isEmpty ? '' : ' $unit';
  final note = never == 0 ? '' : '  [never in $never of ${values.length}]';
  print(
    '  $label: ${f(known.first)}$suffix / '
    '${f(known[known.length ~/ 2])}$suffix / ${f(known.last)}$suffix$note',
  );
}

/// 1234567 -> 12,34,567 (lakh and crore grouping).
String money(int v) {
  final negative = v < 0;
  var s = v.abs().toString();
  if (s.length > 3) {
    final tail = s.substring(s.length - 3);
    var head = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (head.length > 2) {
      parts.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) parts.insert(0, head);
    s = '${parts.join(',')},$tail';
  }
  return negative ? '-$s' : s;
}

class Candidate {
  Candidate(this.vehicle, this.route, this.cargo, this.quote, this.gmpm);

  final VehicleSpec vehicle;
  final RouteSpec route;
  final CargoSpec cargo;
  final TripQuote quote;
  final double gmpm;

  double get profitPerRealHour =>
      quote.profit / (quote.tripGameHours / gmpm);

  /// Tons a vehicle on this route moves per game day (the same at any turbo
  /// speed, because trips and days speed up together).
  double get tonsPerGameDay => 24 / quote.tripGameHours * quote.loadT;

  String get label => '${vehicle.name} on ${route.id} (${cargo.name})';
}

List<Candidate> buildCandidates(EconomyConfig config, Policy policy) {
  final gmpm = config.settings.gameMinutesPerRealMinute;
  final out = <Candidate>[];
  for (final vehicle in config.vehicles) {
    if (vehicle.tier < policy.minTier) continue;
    for (final route in config.routes) {
      if (!dhakaRoutes.contains(route.id)) continue;
      if (!policy.includeLine && route.haulType == HaulType.line) continue;
      Candidate? best;
      for (final cargo in config.cargo) {
        final rejection = checkTripEligibility(
          settings: config.settings,
          vehicle: vehicle,
          route: route,
          cargo: cargo,
        );
        if (rejection != null) continue;
        final quote = quoteTrip(
          config: config,
          vehicle: vehicle,
          route: route,
          cargo: cargo,
        );
        final c = Candidate(vehicle, route, cargo, quote, gmpm);
        if (c.quote.profit <= 0) continue;
        if (best == null || c.profitPerRealHour > best.profitPerRealHour) {
          best = c;
        }
      }
      if (best != null) out.add(best);
    }
  }
  return out;
}

class Purchase {
  Purchase(this.minute, this.label, this.price, this.cashAfter);

  final double minute;
  final String label;
  final int price;
  final int cashAfter;
}

class RunResult {
  RunResult({required this.hours});

  final int hours;
  final purchases = <Purchase>[];
  final incomeByHour = <int, int>{};
  double? firstR01DryMin;
  double? firstR01WaitMin;
  int r01DrySecondsLastHour = 0;
  int vehicleCount = 0;
  int finalCash = 0;
  int completedTrips = 0;

  double get r01DryShareOfLastHour => r01DrySecondsLastHour / 3600;

  int incomeInHour(int hour) => incomeByHour[hour - 1] ?? 0;

  int purchasesBefore(double minute) =>
      purchases.where((p) => p.minute < minute).length;

  /// Minutes between the end of the turbo (minute 60) and the next purchase.
  double? minutesToNextPurchaseAfterTurbo() {
    final next = purchases.where((p) => p.minute >= 60);
    return next.isEmpty ? null : next.first.minute - 60;
  }

  void printDetail() {
    for (var i = 0; i < purchases.length; i++) {
      // A long run of identical buys is summarised.
      if (purchases.length > 24 && i >= 8 && i < purchases.length - 8) {
        if (i == 8) {
          print('  ... ${purchases.length - 16} more purchases ...');
        }
        continue;
      }
      final p = purchases[i];
      print(
        '  ${p.minute.toStringAsFixed(1).padLeft(6)} min  '
        '${p.label.padRight(46)} Tk ${money(p.price).padLeft(10)}  '
        'cash after Tk ${money(p.cashAfter).padLeft(10)}',
      );
    }
    for (var h = 0; h < hours; h++) {
      print('  income in hour ${h + 1}: Tk ${money(incomeByHour[h] ?? 0)}');
    }
    print(
      '  R01 demand first ran dry at '
      '${firstR01DryMin?.toStringAsFixed(1) ?? 'never'} min; '
      'a vehicle first had to wait at '
      '${firstR01WaitMin?.toStringAsFixed(1) ?? 'never'} min',
    );
    print(
      '  trips completed: $completedTrips, vehicles: $vehicleCount, '
      'cash at end: Tk ${money(finalCash)}',
    );
  }
}

RunResult simulate({
  required EconomyConfig config,
  required int seed,
  required int hours,
  required Policy policy,
}) {
  final start = DateTime.utc(2026, 3, 1, 8);
  final schedule = TurboSchedule.fromSettings(config.settings);
  var n = 0;
  final sim = GameSimulator(
    config: config,
    random: Random(seed),
    newId: (prefix) => '${prefix}_${++n}',
  );
  final candidates = buildCandidates(config, policy)
    ..sort((a, b) {
      final byPrice = a.vehicle.priceTk.compareTo(b.vehicle.priceTk);
      if (byPrice != 0) return byPrice;
      return b.profitPerRealHour.compareTo(a.profitPerRealHour);
    });

  var company = Company.newGame(config: config, name: 'Sim', now: start);
  final vehicles = <String, Vehicle>{
    'v0': Vehicle(
      id: 'v0',
      tier: 4,
      purchasedAt: start,
      assignedRouteId: 'R01',
      assignedCargo: 'General dry',
      availableAt: start,
    ),
  };
  var open = <Trip>[];
  final routeStates = {
    for (final r in config.routes)
      r.id: RouteState.initial(r, start, gameDay: 0),
  };

  // Tons per game day the fleet already uses on each route.
  final committed = <String, double>{};
  void commit(String routeId, double tons) =>
      committed[routeId] = (committed[routeId] ?? 0) + tons;
  final starterVehicle = config.vehicleByTier(4);
  final starterRoute = config.routeById('R01');
  final starterCargo = config.cargoByName('General dry');
  final starter = Candidate(
    starterVehicle,
    starterRoute,
    starterCargo,
    quoteTrip(
      config: config,
      vehicle: starterVehicle,
      route: starterRoute,
      cargo: starterCargo,
    ),
    config.settings.gameMinutesPerRealMinute,
  );
  commit('R01', starter.tonsPerGameDay);

  final result = RunResult(hours: hours);
  final horizon = Duration(hours: hours);

  SimWorld world() => SimWorld(
    company: company,
    vehicles: vehicles.values,
    unsettledTrips: open,
    routeStates: routeStates.values,
  );

  void apply(ChangeSet change, {int hourIndex = 0}) {
    final gained = change.cashAfter - company.cash;
    if (gained != 0) {
      result.incomeByHour[hourIndex] =
          (result.incomeByHour[hourIndex] ?? 0) + gained;
    }
    company = company.copyWith(
      cash: change.cashAfter,
      completedTrips: change.completedTripsAfter,
    );
    for (final v in change.vehicles) {
      vehicles[v.id] = v;
    }
    final trips = {for (final t in open) t.id: t};
    for (final t in change.trips) {
      trips[t.id] = t;
    }
    open = trips.values.where((t) => !t.settled).toList();
    for (final r in change.routeStates) {
      routeStates[r.routeId] = r;
    }
  }

  var elapsed = Duration.zero;
  while (elapsed <= horizon) {
    final now = start.add(elapsed);
    final speed = schedule.speedAt(elapsed);
    final bonus = schedule.bonusAt(elapsed);
    final hourIndex = min(elapsed.inHours, hours - 1);
    final minute = elapsed.inMicroseconds / 6e7;

    apply(
      sim.advance(
        world: world(),
        now: now,
        turboSpeed: speed,
        turboBonus: bonus,
      ),
      hourIndex: hourIndex,
    );

    // Line hauls do not repeat by themselves: send idle ones out again.
    for (final v in vehicles.values.toList()) {
      final routeId = v.assignedRouteId;
      if (routeId == null) continue;
      if (config.routeById(routeId).haulType != HaulType.line) continue;
      if (open.any((t) => t.vehicleId == v.id)) continue;
      final ready = v.availableAt;
      if (ready != null && ready.isAfter(now)) continue;
      final outcome = sim.dispatchNow(
        world: world(),
        vehicleId: v.id,
        now: now,
        turboSpeed: speed,
        turboBonus: bonus,
      );
      final change = outcome.change;
      if (change != null) apply(change, hourIndex: hourIndex);
    }

    // Buy the cheapest useful vehicle, again and again while cash allows.
    var bought = true;
    while (bought) {
      bought = false;
      for (final c in candidates) {
        if (c.vehicle.priceTk > company.cash) continue;
        final spare =
            c.route.dailyDemandT - (committed[c.route.id] ?? 0);
        if (spare < c.tonsPerGameDay) continue;
        final id = 'v${vehicles.length}';
        company = company.copyWith(cash: company.cash - c.vehicle.priceTk);
        vehicles[id] = Vehicle(
          id: id,
          tier: c.vehicle.tier,
          purchasedAt: now,
          assignedRouteId: c.route.id,
          assignedCargo: c.cargo.name,
          availableAt: now,
        );
        commit(c.route.id, c.tonsPerGameDay);
        result.purchases.add(
          Purchase(minute, c.label, c.vehicle.priceTk, company.cash),
        );
        final outcome = sim.dispatchNow(
          world: world(),
          vehicleId: id,
          now: now,
          turboSpeed: speed,
          turboBonus: bonus,
        );
        final change = outcome.change;
        if (change != null) apply(change, hourIndex: hourIndex);
        bought = true;
        break;
      }
    }

    // Is R01's demand used up for today's game day?
    final calendar = GameCalendar.fromSettings(
      config.settings,
      start,
      bonus: bonus,
    );
    final r01 = routeStates['R01']!;
    final dry =
        r01.demandRemainingT < 1e-6 && r01.gameDay == calendar.dayIndex(now);
    if (dry) {
      result.firstR01DryMin ??= minute;
      if (elapsed >= horizon - const Duration(hours: 1)) {
        result.r01DrySecondsLastHour += tick.inSeconds;
      }
    }
    final waiting = vehicles.values.any(
      (v) =>
          v.assignedRouteId == 'R01' &&
          v.availableAt != null &&
          v.availableAt!.isAfter(now) &&
          !open.any((t) => t.vehicleId == v.id),
    );
    if (waiting) result.firstR01WaitMin ??= minute;

    elapsed += tick;
  }

  result.vehicleCount = vehicles.length;
  result.finalCash = company.cash;
  result.completedTrips = company.completedTrips;
  return result;
}
