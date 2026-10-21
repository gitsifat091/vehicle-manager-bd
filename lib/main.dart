import 'package:flutter/material.dart';

import 'ui/theme/app_theme.dart';

void main() {
  runApp(const VehicleManagerApp());
}

class VehicleManagerApp extends StatelessWidget {
  const VehicleManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Manager Bangladesh',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const PlaceholderScreen(),
    );
  }
}

// Temporary home screen until the map screen exists (Milestone 4).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Manager Bangladesh')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
