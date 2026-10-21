import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../data/repositories/save_database.dart';

/// Opens the save in the app's own documents folder on this device.
///
/// This is the only place that picks a save location. The Windows folder is
/// reviewed in Milestone 8.
Future<SaveDatabase> openAppSaveDatabase() async {
  await Hive.initFlutter('vehicle_manager_bd');
  return SaveDatabase.openInitialized();
}
