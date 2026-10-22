import 'package:hive_ce/hive_ce.dart';

import '../adapters/game_adapters.dart';
import '../models/models.dart';
import 'app_settings_repository.dart';
import 'repositories.dart';

/// The local save: seven Hive boxes and a repository for each, plus an eighth
/// for the device settings (language, theme) that a new game does not erase.
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
    required this.dayRollups,
    required this.pending,
    required this.settings,
  });

  static const companyBox = 'company';
  static const vehiclesBox = 'vehicles';
  static const terminalsBox = 'terminals';
  static const routeStatesBox = 'route_states';
  static const tripsBox = 'trips';
  static const dayRollupsBox = 'day_rollups';
  static const pendingBox = 'pending_change';
  static const settingsBox = 'app_settings';

  final CompanyRepository company;
  final VehicleRepository vehicles;
  final TerminalRepository terminals;
  final RouteStateRepository routeStates;
  final TripRepository trips;
  final DayRollupRepository dayRollups;
  final PendingChangeRepository pending;

  /// Device settings. Not part of a game, so [clearAll] leaves them alone.
  final AppSettingsRepository settings;

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
      dayRollups: DayRollupRepository(
        await Hive.openBox<DayRollup>(dayRollupsBox),
      ),
      pending: PendingChangeRepository(
        await Hive.openBox<ChangeSet>(pendingBox),
      ),
      settings: AppSettingsRepository(await Hive.openBox<String>(settingsBox)),
    );
  }

  /// Erases every record of the game, for "new game". The device settings
  /// stay.
  Future<void> clearAll() async {
    await company.clear();
    await vehicles.clear();
    await terminals.clear();
    await routeStates.clear();
    await trips.clear();
    await dayRollups.clear();
    await pending.box.clear();
  }

  /// Flushes and closes all boxes.
  Future<void> close() async {
    await company.box.close();
    await vehicles.box.close();
    await terminals.box.close();
    await routeStates.box.close();
    await trips.box.close();
    await dayRollups.box.close();
    await pending.box.close();
    await settings.box.close();
  }
}
