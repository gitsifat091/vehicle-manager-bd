import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await bootstrap();
  runApp(
    VehicleManagerApp(config: services.config, engine: services.engine),
  );
}
