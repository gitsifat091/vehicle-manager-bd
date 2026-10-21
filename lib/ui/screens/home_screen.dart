import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/sim/vehicle_status.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_context.dart';
import '../../state/game_engine.dart';
import '../../state/ui_clock.dart';
import '../layout.dart';
import '../theme/app_theme.dart';
import '../theme/lal_sabuj_tokens.dart';
import '../widgets/vehicle_tile.dart';

/// Temporary home screen: cash, turbo speed and a read-only list of the
/// player's vehicles, so the starter vehicle can be watched while the real
/// screens are built (Milestone 4). Replaced by the responsive shell in step 5.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The snapshot changes when the game does; the UI clock moves the bars,
    // the timers and the turbo speed once a second.
    final snapshot = context.select((GameEngine e) => e.snapshot);
    final now = context.select((UiClock c) => c.now);
    final engine = context.read<GameEngine>();
    final company = snapshot.company;
    final fmt = context.fmt;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: company == null
          ? Center(child: Text(l10n.noGameYet))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Layout.formMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(Space.s4),
                  children: [
                    Text(company.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: Space.s1),
                    Text(
                      l10n.cashLine(fmt.money(company.cash)),
                      style: GameText.money(context),
                    ),
                    Text(
                      l10n.turboLine(fmt.decimal(engine.turboSpeed, places: 0)),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Space.s6),
                    Text(
                      l10n.homeVehiclesTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      l10n.garageSlotsLine(
                        fmt.integer(snapshot.vehicles.length),
                        fmt.integer(snapshot.garageSlots),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Space.s2),
                    for (final vehicle in snapshot.vehicles)
                      _tile(
                        context,
                        engine,
                        vehicle,
                        snapshot.activityOf(vehicle, now),
                        now,
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _tile(
    BuildContext context,
    GameEngine engine,
    Vehicle vehicle,
    VehicleActivity activity,
    DateTime now,
  ) {
    return VehicleTile(
      vehicle: vehicle,
      activity: activity,
      now: now,
      // TEMPORARY, removed in step 10 when the assign-route screen exists:
      // an idle vehicle can be sent to work on the first city route so the
      // game can be watched running.
      action: activity.status == VehicleStatus.idle
          ? FilledButton.tonal(
              onPressed: () => engine.assignVehicle(
                vehicle.id,
                routeId: 'R01',
                cargoName: 'General dry',
              ),
              child: Text(context.l10n.tempStartWorking),
            )
          : null,
    );
  }
}
