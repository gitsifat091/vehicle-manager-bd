// Edits a local save for manual testing. Close the game first: the save is
// locked while it runs.
//
//   dart run tool/debug_save.dart [--dir <folder>] cash <taka>
//   dart run tool/debug_save.dart [--dir <folder>] last-van
//
// cash      sets the company's cash.
// last-van  replaces the whole garage with one bought Sonar Van (tier 1, not
//           assigned) and sets the cash to 0. Selling that van is then
//           refused as the last vehicle (lastVehicleUnaffordable), because
//           its resale value does not buy a new one.
//
// The folder defaults to Documents\vehicle_manager_bd, where the Windows
// build keeps its save (Hive.initFlutter). It refuses a save with a trip on
// the road or a half-written change, so it never has to touch trips. A
// debugging aid only: it writes the records directly, not through the
// ChangeCommitter.

// ignore_for_file: avoid_print
import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';
import 'package:vehicle_manager_bd/data/repositories/save_database.dart';

Future<void> main(List<String> args) async {
  final rest = [...args];
  var dir = _defaultDir();
  final dirAt = rest.indexOf('--dir');
  if (dirAt >= 0 && dirAt + 1 < rest.length) {
    dir = rest[dirAt + 1];
    rest.removeRange(dirAt, dirAt + 2);
  }
  if (rest.isEmpty) _usage();
  if (dir == null || !File('$dir/company.hive').existsSync()) {
    _fail('No save found in ${dir ?? '(no folder)'}. Pass --dir <folder>.');
  }

  final db = await SaveDatabase.openAt(dir);
  try {
    final company = db.company.load();
    if (company == null) _fail('The save has no company. Start a game first.');
    if (db.pending.load() != null) {
      _fail('The save has a half-written change. Open the game once first.');
    }
    if (db.trips.unsettled().isNotEmpty) {
      _fail(
        'A vehicle is on the road. Let its trip finish, then close the '
        'game and try again.',
      );
    }

    switch (rest.first) {
      case 'cash' when rest.length == 2 && int.tryParse(rest[1]) != null:
        final cash = int.parse(rest[1]);
        await db.company.save(company.copyWith(cash: cash));
        print('Cash set to Tk $cash in $dir');
      case 'last-van' when rest.length == 1:
        await db.vehicles.clear();
        await db.vehicles.put(
          Vehicle(
            id: 'debug-van',
            tier: 1,
            purchasedAt: DateTime.now().toUtc(),
          ),
        );
        await db.company.save(company.copyWith(cash: 0));
        print('The garage is one Sonar Van and the cash is Tk 0 in $dir');
      default:
        _usage();
    }
  } finally {
    await Hive.close();
  }
}

String? _defaultDir() {
  final home = Platform.environment['USERPROFILE'];
  return home == null ? null : '$home\\Documents\\vehicle_manager_bd';
}

Never _usage() {
  print('Usage: dart run tool/debug_save.dart [--dir <folder>] cash <taka>');
  print('       dart run tool/debug_save.dart [--dir <folder>] last-van');
  exit(64);
}

Never _fail(String message) {
  print(message);
  exit(1);
}
