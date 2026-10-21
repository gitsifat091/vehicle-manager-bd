import 'package:hive_ce/hive_ce.dart';

import '../adapters/game_adapters.dart';
import '../models/models.dart';
import 'repositories.dart';

/// The local save: five Hive boxes and a repository for each.
///
/// Hive must already point at a folder. Tests call [openAt] with a temp
/// folder; the app uses the platform helper in lib/platform/, which picks the
/// folder for the device. Hive has no transaction across boxes, so code that
/// updates two boxes (a settled trip and the company cash) should write the
/// one that is safe to repeat first.
class SaveDatabase {
  SaveDatabase._({
    required this.company,
    required this.vehicles,
    required this.terminals,
    required this.routeStates,
    required this.trips,
  });

  static const companyBox = 'company';
  static const vehiclesBox = 'vehicles';
  static const terminalsBox = 'terminals';
  static const routeStatesBox = 'route_states';
  static const tripsBox = 'trips';

  final CompanyRepository company;
  final VehicleRepository vehicles;
  final TerminalRepository terminals;
  final RouteStateRepository routeStates;
  final TripRepository trips;

  /// Points Hive at [path] and opens the save there.
  static Future<SaveDatabase> openAt(String path) async {
    Hive.init(path);
    return openInitialized();
  }

  /// Opens the save in the folder Hive is already initialised with.
  static Future<SaveDatabase> openInitialized() async {
    registerGameAdapters(Hive);
    return SaveDatabase._(
      company: CompanyRepository(await Hive.openBox<Company>(companyBox)),
      vehicles: VehicleRepository(await Hive.openBox<Vehicle>(vehiclesBox)),
      terminals: TerminalRepository(await Hive.openBox<Terminal>(terminalsBox)),
      routeStates: RouteStateRepository(
        await Hive.openBox<RouteState>(routeStatesBox),
      ),
      trips: TripRepository(await Hive.openBox<Trip>(tripsBox)),
    );
  }

  /// Erases every record, for "new game".
  Future<void> clearAll() async {
    await company.clear();
    await vehicles.clear();
    await terminals.clear();
    await routeStates.clear();
    await trips.clear();
  }

  /// Flushes and closes all boxes.
  Future<void> close() async {
    await company.box.close();
    await vehicles.box.close();
    await terminals.box.close();
    await routeStates.box.close();
    await trips.box.close();
  }
}
