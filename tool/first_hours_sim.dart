// Simulates the first hours of play with the real game code and a greedy
// buyer, to check the first-hour pacing against docs/economy_model.xlsx.
//
//   dart run tool/first_hours_sim.dart [hours] [seeds] [policies] [resale]
//
// Defaults: 3 hours, 20 seeds, policies ABCDE (for example "ADE" runs three).
// [resale] overrides settings.resaleShareOfPrice in memory for a sensitivity
// run. It changes no balance numbers: everything comes from
// assets/config/economy.json.
//
// The player model
// - Starts with the starting cash and one free Sathi Plus on R01 (General dry).
// - The app stays in the foreground the whole time and ticks every 3 seconds,
//   so Turbo Start runs for the first 60 minutes.
// - Whenever cash and a garage slot allow (the free Sathi Plus takes one, no
//   selling), it buys a useful vehicle and sends it out at once. Policies A to
//   C pick the cheapest one; policy D picks the affordable one with the
//   highest profit per real hour. Vehicle unlocks apply (tier 3 needs 5
//   settled trips) but the bots buy no permits, so tiers 5 and up stay shut.
//   Useful means: it can run a route that starts in Dhaka (no
//   terminal needed yet), it earns a profit, and the route still has demand
//   left for it. "Demand left" means the route's daily demand minus what the
//   fleet already uses per game day, so the new vehicle would not starve.
// - Line hauls are sent out again as soon as they arrive. Local hauls repeat
//   by themselves.
// - Vehicle unlocks (permits, deliveries) are not modelled.

// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/core/economy/purchase_rules.dart';
import 'package:vehicle_manager_bd/core/economy/route_economics.dart';
import 'package:vehicle_manager_bd/core/economy/unlock_rules.dart';
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
  const Policy(
    this.id,
    this.name, {
    required this.minTier,
    required this.includeLine,
    this.cheapestFirst = true,
    this.sells = false,
    this.buysPermits = false,
  });

  /// True: the bot also buys an operating permit when that unlocks a vehicle
  /// with a better profit per real hour than its worst vehicle, and it can
  /// afford the permit plus that vehicle (net of the worst one's resale value
  /// when the garage is full).
  final bool buysPermits;

  /// True: when the garage is full and a better vehicle (higher profit per
  /// real hour) becomes affordable after selling the worst one, the worst one
  /// is unassigned, sold once its trip has settled, and the better one bought.
  final bool sells;

  /// One letter, used to pick policies on the command line.
  final String id;
  final String name;

  /// True: buy the cheapest useful vehicle. False: buy the affordable useful
  /// vehicle with the highest profit per real hour.
  final bool cheapestFirst;

  /// Vehicles below this tier are never bought.
  final int minTier;

  /// Whether Line hauls count as useful. They need the player at every
  /// departure.
  final bool includeLine;
}

void main(List<String> args) {
  final hours = args.isNotEmpty ? int.parse(args[0]) : 3;
  final seeds = args.length > 1 ? int.parse(args[1]) : 20;
  var jsonText = File('assets/config/economy.json').readAsStringSync();
  if (args.length > 3) {
    // Sensitivity run: only the resale share changes, in memory.
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    decoded['settings']['resaleShareOfPrice'] = double.parse(args[3]);
    jsonText = jsonEncode(decoded);
  }
  final config = EconomyConfig.parse(jsonText);

  print('First hours simulation, $hours h, '
      '${args.length > 3 ? 'resale share ${args[3]}' : 'default config'}, '
      '$seeds seeds');
  print('Resale share of price: ${config.settings.resaleShareOfPrice}');
  print('Spreadsheet (First Hour sheet): 3 purchases in 60 min, 4 in 4 h, '
      'fleet profit after turbo Tk 2,47,607 per hour at 1x');

  print('Garage slots: ${config.settings.startingGarageSlots} '
      '(the free Sathi Plus counts); no selling');

  const policies = [
    Policy(
      'A',
      'POLICY A: cheapest useful vehicle, all tiers, Local hauls only',
      minTier: 1,
      includeLine: false,
    ),
    Policy(
      'B',
      'POLICY B: cheapest useful vehicle, tier 3 and up, Local hauls only '
      '(no attention needed after buying)',
      minTier: 3,
      includeLine: false,
    ),
    Policy(
      'C',
      'POLICY C: cheapest useful vehicle, tier 3 and up, Local and Line hauls '
      '(an attentive player sends every Line haul out again at once)',
      minTier: 3,
      includeLine: true,
    ),
    Policy(
      'D',
      'POLICY D: highest profit per real hour among affordable useful '
      'vehicles, all tiers, Local hauls only',
      minTier: 1,
      includeLine: false,
      cheapestFirst: false,
    ),
    Policy(
      'E',
      'POLICY E: like D, but with a full garage it sells the worst vehicle '
      '(by profit per real hour) when a better one is then affordable',
      minTier: 1,
      includeLine: false,
      cheapestFirst: false,
      sells: true,
    ),
    Policy(
      'F',
      'POLICY F: like E, and it also buys an operating permit when that '
      'unlocks a vehicle with better profit per hour than its worst one',
      minTier: 1,
      includeLine: false,
      cheapestFirst: false,
      sells: true,
      buysPermits: true,
    ),
    Policy(
      'G',
      'POLICY G: like E, but Line hauls count too (an attentive player sends '
      'every Line haul out again at once)',
      minTier: 1,
      includeLine: true,
      cheapestFirst: false,
      sells: true,
    ),
    Policy(
      'H',
      'POLICY H: like F, but Line hauls count too (an attentive player sends '
      'every Line haul out again at once)',
      minTier: 1,
      includeLine: true,
      cheapestFirst: false,
      sells: true,
      buysPermits: true,
    ),
  ];
  final only = args.length > 2 ? args[2].toUpperCase() : 'ABCDEFGH';

  final results = <String, List<RunResult>>{};
  for (final policy in policies.where((p) => only.contains(p.id))) {
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
    printHourly(runs, hours);

    print('');
    print('Over $seeds seeds (min / median / max)');
    results[policy.id] = runs;
    summary(
      'Longest stretch with nothing to buy, even with unlimited cash',
      runs.map((r) => r.longestNothingToBuyMin),
      unit: 'min',
    );
    summary(
      'Longest stretch without a purchase, permit or sale',
      runs.map((r) => r.longestNoActionMin),
      unit: 'min',
    );
    summary(
      'Permits bought',
      runs.map((r) => r.permitPurchases.length),
    );
    summary('Purchases in hour 1', runs.map((r) => r.purchasesBefore(60)));
    summary(
      'Minute the garage cap is reached',
      runs.map((r) => r.capReachedMin),
      unit: 'min',
    );
    for (final vehicle in config.vehicles) {
      final counts = runs.map((r) => r.boughtOfTier(vehicle.tier)).toList();
      if (counts.every((c) => c == 0)) continue;
      summary('Bought: tier ${vehicle.tier} ${vehicle.name}', counts);
    }
    summary('Vehicles sold', runs.map((r) => r.sales.length));
    for (final vehicle in config.vehicles) {
      final sold = runs.map((r) => r.soldOfTier(vehicle.tier)).toList();
      if (sold.any((c) => c > 0)) {
        summary('Sold: tier ${vehicle.tier} ${vehicle.name}', sold);
      }
    }
    for (final vehicle in config.vehicles) {
      final held = runs.map((r) => r.inFleetOfTier(vehicle.tier)).toList();
      if (held.any((c) => c > 0)) {
        summary('In fleet at end: tier ${vehicle.tier} ${vehicle.name}', held);
      }
    }
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
    summary('Total income over $hours h (Tk)', runs.map((r) => r.totalIncome));
    summary('Cash at end (Tk)', runs.map((r) => r.finalCash));
    summary(
      'Net worth at end: cash + vehicle prices (Tk)',
      runs.map((r) => r.netWorth),
    );
    summary(
      'Net worth at end: cash + vehicle resale values (Tk)',
      runs.map((r) => r.netWorthAtResale),
    );
  }

  if (results.length > 1) {
    num median(Iterable<num> v) => (v.toList()..sort())[v.length ~/ 2];
    print('');
    print('=' * 72);
    print('Policies side by side, medians');
    print('=' * 72);
    final ids = results.keys.toList();
    String row(String label, num Function(RunResult) f) {
      final cells = ids.map(
        (id) =>
            '$id: ${money(median(results[id]!.map(f)).round())}'.padLeft(18),
      );
      return '  ${label.padRight(40)}${cells.join()}';
    }

    print(row('Total income over $hours h (Tk)', (r) => r.totalIncome));
    print(row('Income in hour $hours (Tk)', (r) => r.incomeInHour(hours)));
    print(row('Cash at end (Tk)', (r) => r.finalCash));
    print(row('Net worth, vehicles at price (Tk)', (r) => r.netWorth));
    print(row('Net worth, vehicles at resale (Tk)', (r) => r.netWorthAtResale));
    print(row('Vehicles sold', (r) => r.sales.length));
  }
}

/// One row per hour, medians over the seeds.
void printHourly(List<RunResult> runs, int hours) {
  num median(Iterable<num> v) => (v.toList()..sort())[v.length ~/ 2];
  print('Per hour, medians over ${runs.length} seeds');
  print('  Hour   Income (Tk)   Cash at end (Tk)   Vehicles bought   '
      'Permits bought   Vehicles sold');
  for (var h = 0; h < hours; h++) {
    String cell(num v, int width) => money(v.round()).padLeft(width);
    print(
      '  ${(h + 1).toString().padLeft(4)}'
      '${cell(median(runs.map((r) => r.incomeInHour(h + 1))), 14)}'
      '${cell(median(runs.map((r) => r.cashAtHourEnd[h])), 19)}'
      '${cell(median(runs.map((r) => r.vehiclesBoughtInHour(h))), 18)}'
      '${cell(median(runs.map((r) => r.permitsBoughtInHour(h))), 17)}'
      '${cell(median(runs.map((r) => r.soldInHour(h))), 16)}',
    );
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

/// A vehicle, route and cargo the bot could buy and run. The economics come
/// from lib/core/economy/route_economics.dart, the same as the buy screen.
typedef Candidate = RouteEconomics;

extension CandidateLabel on RouteEconomics {
  String get label => '${vehicle.name} on ${route.id} (${cargo.name})';
}

List<Candidate> buildCandidates(EconomyConfig config, Policy policy) {
  final out = <Candidate>[];
  for (final vehicle in config.vehicles) {
    if (vehicle.tier < policy.minTier) continue;
    for (final route in config.routes) {
      if (!dhakaRoutes.contains(route.id)) continue;
      if (!policy.includeLine && route.haulType == HaulType.line) continue;
      final best = bestCargoOn(config: config, vehicle: vehicle, route: route);
      if (best != null && best.quote.profit > 0) out.add(best);
    }
  }
  return out;
}

class Purchase {
  Purchase(this.minute, this.tier, this.label, this.price, this.cashAfter);

  final double minute;
  final int tier;
  final String label;
  final int price;
  final int cashAfter;
}

class Sale {
  Sale(this.minute, this.tier, this.price);

  final double minute;
  final int tier;
  final int price;
}

class PermitPurchase {
  PermitPurchase(this.minute, this.id, this.price);

  final double minute;
  final String id;
  final int price;
}

class RunResult {
  RunResult({required this.hours});

  final int hours;
  final purchases = <Purchase>[];
  final sales = <Sale>[];
  final permitPurchases = <PermitPurchase>[];

  /// Cash at the end of each hour, in order.
  final cashAtHourEnd = <int>[];

  /// Longest run of time in which the bot had no purchase, permit or sale.
  double longestNoActionMin = 0;

  /// Longest run of time in which nothing was left for the bot to buy even
  /// with unlimited cash: no free slot and no better vehicle to swap to, or
  /// no useful vehicle left.
  double longestNothingToBuyMin = 0;

  int _hourOf(double minute) => min(minute ~/ 60, hours - 1);

  int vehiclesBoughtInHour(int hour) =>
      purchases.where((p) => _hourOf(p.minute) == hour).length;

  int permitsBoughtInHour(int hour) =>
      permitPurchases.where((p) => _hourOf(p.minute) == hour).length;

  int soldInHour(int hour) =>
      sales.where((s) => _hourOf(s.minute) == hour).length;

  /// Tier of every vehicle still owned at the end, the starter included.
  final fleetTiers = <int>[];

  /// What the fleet at the end would sell for.
  int fleetResaleValue = 0;

  int get netWorthAtResale => finalCash + fleetResaleValue;

  int soldOfTier(int tier) => sales.where((s) => s.tier == tier).length;

  int inFleetOfTier(int tier) => fleetTiers.where((t) => t == tier).length;
  final incomeByHour = <int, int>{};
  double? firstR01DryMin;
  double? firstR01WaitMin;
  int r01DrySecondsLastHour = 0;
  int vehicleCount = 0;
  int finalCash = 0;
  int completedTrips = 0;

  /// Real minute the last free garage slot was taken.
  double? capReachedMin;

  /// Prices of every vehicle owned at the end, the free starter included.
  int fleetValue = 0;

  int get totalIncome => incomeByHour.values.fold(0, (a, b) => a + b);

  int get netWorth => finalCash + fleetValue;

  int boughtOfTier(int tier) => purchases.where((p) => p.tier == tier).length;

  double get r01DryShareOfLastHour => r01DrySecondsLastHour / 3600;

  int incomeInHour(int hour) => incomeByHour[hour - 1] ?? 0;

  int purchasesBefore(double minute) =>
      purchases.where((p) => p.minute < minute).length;

  /// Purchases of one vehicle name (labels start with the vehicle name),
  /// optionally only those before [beforeMinute].
  int boughtOf(String vehicleName, {double? beforeMinute}) => purchases
      .where(
        (p) =>
            p.label.startsWith('$vehicleName on') &&
            (beforeMinute == null || p.minute < beforeMinute),
      )
      .length;

  Map<String, int> countByVehicle() {
    final counts = <String, int>{};
    for (final p in purchases) {
      final name = p.label.split(' on ').first;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

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
    print('  bought: ${countByVehicle()}');
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
      final byProfit = b.profitPerRealHour.compareTo(a.profitPerRealHour);
      if (!policy.cheapestFirst) return byProfit;
      final byPrice = a.vehicle.priceTk.compareTo(b.vehicle.priceTk);
      return byPrice != 0 ? byPrice : byProfit;
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
  final starter = routeEconomics(
    config: config,
    vehicle: config.vehicleByTier(4),
    route: config.routeById('R01'),
    cargo: config.cargoByName('General dry'),
  );
  commit('R01', starter.tonsPerGameDay);

  // What each vehicle is doing, for policy E to rank by profit per hour.
  final doing = <String, Candidate>{'v0': starter};
  // Vehicles E has unassigned and will sell when their trip has settled.
  final retiring = <String>{};
  var nextVehicleNumber = 1;

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

  bool garageFull() =>
      checkGarageSlot(
        settings: config.settings,
        vehiclesOwned: vehicles.length,
      ) !=
      null;

  /// Whether the unlock rules let the bot buy [c]'s vehicle now.
  bool unlocked(Candidate c) =>
      checkVehicleUnlocked(
        vehicle: c.vehicle,
        completedTrips: company.completedTrips,
        ownedPermits: company.permits,
      ) ==
      null;

  /// Whether [c]'s route has demand left for it. [freeing] is a vehicle about
  /// to leave, whose share of its route's demand becomes free.
  bool hasSpare(Candidate c, {Candidate? freeing}) {
    final used =
        (committed[c.route.id] ?? 0) -
        (freeing != null && freeing.route.id == c.route.id
            ? freeing.tonsPerGameDay
            : 0);
    return RouteDemand(route: c.route, usedTonsPerGameDay: used).fits(c);
  }

  /// The vehicle with the lowest profit per real hour, or null for none.
  String? worstVehicleId() {
    String? worstId;
    for (final id in vehicles.keys) {
      final c = doing[id]!;
      if (worstId == null ||
          c.profitPerRealHour < doing[worstId]!.profitPerRealHour) {
        worstId = id;
      }
    }
    return worstId;
  }

  /// Whether the bot has anything it could buy if cash were no limit: a free
  /// slot and a useful vehicle, or (when it sells) a better vehicle than its
  /// worst one, and (when it buys permits) also a vehicle behind a permit.
  bool somethingToBuy() {
    final free = !garageFull();
    final worstId = free ? null : worstVehicleId();
    final worst = worstId == null ? null : doing[worstId]!;
    if (!free && (!policy.sells || worst == null)) return false;
    for (final c in candidates) {
      final open = unlocked(c) ||
          (policy.buysPermits &&
              c.vehicle.unlockPermitId != null &&
              !company.permits.contains(c.vehicle.unlockPermitId));
      if (!open) continue;
      if (!free && c.profitPerRealHour <= worst!.profitPerRealHour) continue;
      if (hasSpare(c, freeing: free ? null : worst)) return true;
    }
    return false;
  }

  var lastActionMinute = 0.0;
  double? nothingToBuySince;
  var nextHourMark = 1;
  var elapsed = Duration.zero;
  while (elapsed <= horizon) {
    var acted = false;
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

    // Sell retiring vehicles whose last trip has settled.
    for (final id in retiring.toList()) {
      if (checkSale(onTheRoad: open.any((t) => t.vehicleId == id)) != null) {
        continue;
      }
      final vehicle = vehicles.remove(id)!;
      final spec = config.vehicleByTier(vehicle.tier);
      final price = resaleValueTk(settings: config.settings, vehicle: spec);
      company = company.copyWith(cash: company.cash + price);
      result.sales.add(Sale(minute, vehicle.tier, price));
      doing.remove(id);
      retiring.remove(id);
      acted = true;
    }

    // Policy F: buy an operating permit when it unlocks a vehicle that earns
    // more per hour than the worst one, and the permit plus that vehicle are
    // affordable (counting the worst one's resale value when the garage is
    // full). The vehicle itself is bought by the normal steps below.
    if (policy.buysPermits && retiring.isEmpty) {
      final worstId = worstVehicleId();
      if (worstId != null) {
        final worst = doing[worstId]!;
        final full = garageFull();
        final resale = full
            ? resaleValueTk(settings: config.settings, vehicle: worst.vehicle)
            : 0;
        final unowned = config.permits
            .where((p) => !company.permits.contains(p.id))
            .toList()
          ..sort((a, b) => a.priceTk.compareTo(b.priceTk));
        for (final permit in unowned) {
          Candidate? target;
          for (final c in candidates) {
            if (c.vehicle.unlockPermitId != permit.id) continue;
            if (c.profitPerRealHour <= worst.profitPerRealHour) continue;
            if (!hasSpare(c, freeing: full ? worst : null)) continue;
            if (target == null ||
                c.profitPerRealHour > target.profitPerRealHour) {
              target = c;
            }
          }
          if (target == null) continue;
          final need = permit.priceTk + target.vehicle.priceTk - resale;
          if (company.cash < need) continue;
          if (checkPermitPurchase(
                permit: permit,
                cash: company.cash,
                ownedPermits: company.permits,
              ) !=
              null) {
            continue;
          }
          company = company.copyWith(
            cash: company.cash - permit.priceTk,
            permits: {...company.permits, permit.id},
          );
          result.permitPurchases.add(
            PermitPurchase(minute, permit.id, permit.priceTk),
          );
          acted = true;
          break;
        }
      }
    }

    // Buy the next vehicle by the policy's order, again and again while cash
    // and garage slots allow.
    var bought = true;
    while (bought) {
      bought = false;
      if (garageFull()) break;
      for (final c in candidates) {
        if (c.vehicle.priceTk > company.cash) continue;
        // Unlock rules apply: tier 3 after 5 settled trips, tiers 5 and up
        // only with the matching permit (only policy F buys permits).
        if (!unlocked(c)) continue;
        if (!hasSpare(c)) continue;
        acted = true;
        final id = 'v${nextVehicleNumber++}';
        doing[id] = c;
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
          Purchase(minute, c.vehicle.tier, c.label, c.vehicle.priceTk,
              company.cash),
        );
        if (checkGarageSlot(
              settings: config.settings,
              vehiclesOwned: vehicles.length,
            ) !=
            null) {
          result.capReachedMin ??= minute;
        }
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

    // Policy E: with a full garage, retire the worst vehicle when a better one
    // is affordable after selling it. One sale at a time.
    if (policy.sells && retiring.isEmpty && garageFull()) {
      final worstId = worstVehicleId();
      if (worstId != null) {
        final worst = doing[worstId]!;
        final cashAfterSale =
            company.cash +
            resaleValueTk(settings: config.settings, vehicle: worst.vehicle);
        final better = candidates.any((c) {
          if (c.profitPerRealHour <= worst.profitPerRealHour) return false;
          if (c.vehicle.priceTk > cashAfterSale) return false;
          if (!unlocked(c)) return false;
          return hasSpare(c, freeing: worst);
        });
        if (better) {
          retiring.add(worstId);
          commit(worst.route.id, -worst.tonsPerGameDay);
          apply(
            ChangeSet(
              cashAfter: company.cash,
              completedTripsAfter: company.completedTrips,
              vehicles: [vehicles[worstId]!.withoutAssignment()],
            ),
            hourIndex: hourIndex,
          );
        }
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

    // Stretches with no action, and with nothing to buy even with unlimited
    // cash, measured at the end of the tick.
    if (acted) {
      result.longestNoActionMin = max(
        result.longestNoActionMin,
        minute - lastActionMinute,
      );
      lastActionMinute = minute;
    }
    if (somethingToBuy()) {
      final since = nothingToBuySince;
      if (since != null) {
        result.longestNothingToBuyMin = max(
          result.longestNothingToBuyMin,
          minute - since,
        );
        nothingToBuySince = null;
      }
    } else {
      nothingToBuySince ??= minute;
    }
    while (elapsed >= Duration(hours: nextHourMark) && nextHourMark <= hours) {
      result.cashAtHourEnd.add(company.cash);
      nextHourMark++;
    }

    elapsed += tick;
  }

  final endMinute = horizon.inMicroseconds / 6e7;
  result.longestNoActionMin = max(
    result.longestNoActionMin,
    endMinute - lastActionMinute,
  );
  final idleSince = nothingToBuySince;
  if (idleSince != null) {
    result.longestNothingToBuyMin = max(
      result.longestNothingToBuyMin,
      endMinute - idleSince,
    );
  }

  result.vehicleCount = vehicles.length;
  result.fleetValue = vehicles.values.fold(
    0,
    (sum, v) => sum + config.vehicleByTier(v.tier).priceTk,
  );
  for (final v in vehicles.values) {
    result.fleetTiers.add(v.tier);
    result.fleetResaleValue += resaleValueTk(
      settings: config.settings,
      vehicle: config.vehicleByTier(v.tier),
    );
  }
  result.finalCash = company.cash;
  result.completedTrips = company.completedTrips;
  return result;
}
