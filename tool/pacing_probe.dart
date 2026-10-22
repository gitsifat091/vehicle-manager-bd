// Pacing probe for the "first upgrade" question (PROJECT_STATUS.md, open
// question 5). Runs first_hours_sim's simulate() on in-memory edits of
// economy.json (starting cash, prices of tiers 3 and 4) and prints, per
// variant and policy, the median first-upgrade minute and 3-hour income over
// 20 seeds. It changes no file.
//
//   dart run tool/pacing_probe.dart [filter ...]
//
// With filters, only variants whose name contains one of them run, for
// example `dart run tool/pacing_probe.dart base "cash 6"`.
//
// Policy U exists only here: the "saver" keeps the starter working and buys
// only tier 4 and up, so it buys nothing until a Sathi Plus is affordable.
// The other policies mirror first_hours_sim.dart (F and H are left out: they
// match E and G here). "Never" means most seeds had no upgrade in 3 hours; a
// star means some did not.

// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:vehicle_manager_bd/core/config/economy_config.dart';

import 'first_hours_sim.dart';

const policies = [
  // Saves for the upgrade: buys only tier 4 and up, so nothing until a
  // Sathi Plus is affordable.
  Policy('U', 'U', minTier: 4, includeLine: false),
  Policy('A', 'A', minTier: 1, includeLine: false),
  Policy('B', 'B', minTier: 3, includeLine: false),
  Policy('C', 'C', minTier: 3, includeLine: true),
  Policy('D', 'D', minTier: 1, includeLine: false, cheapestFirst: false),
  Policy(
    'E',
    'E',
    minTier: 1,
    includeLine: false,
    cheapestFirst: false,
    sells: true,
  ),
  Policy(
    'G',
    'G',
    minTier: 1,
    includeLine: true,
    cheapestFirst: false,
    sells: true,
  ),
];

void Function(Map<String, dynamic>) cash(int tk) =>
    (j) => j['settings']['startingCash'] = tk;

void Function(Map<String, dynamic>) prices(double factor, List<int> tiers) =>
    (j) {
      for (final v in j['vehicles'] as List) {
        if (tiers.contains(v['tier'])) {
          v['priceTk'] = ((v['priceTk'] as num) * factor).round();
        }
      }
    };

void Function(Map<String, dynamic>) both(
  void Function(Map<String, dynamic>) a,
  void Function(Map<String, dynamic>) b,
) => (j) {
  a(j);
  b(j);
};

void main(List<String> args) {
  final base = File('assets/config/economy.json').readAsStringSync();
  final variants = <String, void Function(Map<String, dynamic>)>{
    'base (cash 15 lakh)': (_) {},
    'cash 8 lakh': cash(800000),
    'cash 7 lakh': cash(700000),
    'cash 6 lakh': cash(600000),
    'cash 5 lakh': cash(500000),
    'cash 4 lakh': cash(400000),
    'tiers 3-4 x1.5': prices(1.5, [3, 4]),
    'tiers 3-4 x1.75': prices(1.75, [3, 4]),
    'tiers 3-4 x2': prices(2, [3, 4]),
    'cash 10 + tiers 3-4 x1.25': both(cash(1000000), prices(1.25, [3, 4])),
    'cash 10 + tiers 3-4 x1.4': both(cash(1000000), prices(1.4, [3, 4])),
    'cash 8 + tiers 3-4 x1.25': both(cash(800000), prices(1.25, [3, 4])),
  };
  final only = args.isEmpty ? null : args.toSet();
  const seeds = 20;
  const hours = 3;

  num? median(List<num?> v) {
    final known = v.whereType<num>().toList()..sort();
    if (known.length * 2 <= v.length) return null; // most never
    final all = [...known, ...List.filled(v.length - known.length, 1e9)]
      ..sort();
    return all[all.length ~/ 2];
  }

  print(
    'variant'.padRight(28) +
        policies.map((p) => '${p.id}: upg min / 3h lakh'.padLeft(22)).join(),
  );
  for (final entry in variants.entries) {
    if (only != null && !only.any((o) => entry.key.contains(o))) continue;
    final json = jsonDecode(base) as Map<String, dynamic>;
    entry.value(json);
    final config = EconomyConfig.parse(jsonEncode(json));
    final cells = <String>[];
    for (final policy in policies) {
      final runs = [
        for (var seed = 1; seed <= seeds; seed++)
          simulate(config: config, seed: seed, hours: hours, policy: policy),
      ];
      final up = median(runs.map((r) => r.firstUpgradeMin).toList());
      final never = runs.where((r) => r.firstUpgradeMin == null).length;
      final income = median(runs.map((r) => r.totalIncome).toList())!;
      final upText = up == null
          ? 'never'
          : '${up.toStringAsFixed(1)}${never > 0 ? '*' : ''}';
      cells.add(
        '$upText / ${(income / 100000).toStringAsFixed(1)}'.padLeft(22),
      );
    }
    print(entry.key.padRight(28) + cells.join());
  }
}
