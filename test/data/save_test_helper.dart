import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:vehicle_manager_bd/data/repositories/save_database.dart';

/// Gives each test its own empty save folder and cleans up afterwards.
///
/// Call inside `main()`. Use [dir] for the folder of the current test.
class SaveFolder {
  late Directory dir;

  void register() {
    setUp(() {
      dir = Directory.systemTemp.createTempSync('vm_save_test_');
    });
    tearDown(() async {
      // A test that failed half way can leave a write waiting for a pump that
      // will never come. Do not let that hang the whole suite.
      await Hive.close().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <void>[],
      );
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  }

  Future<SaveDatabase> open() => SaveDatabase.openAt(dir.path);
}
