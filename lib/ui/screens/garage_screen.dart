import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/sim/vehicle_status.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_context.dart';
import '../../state/game_engine.dart';
import '../../state/ui_clock.dart';
import '../layout.dart';
import '../theme/lal_sabuj_tokens.dart';
import '../widgets/vehicle_tile.dart';

/// The garage: the slot count and a read-only list of the player's vehicles.
///
/// A page of the shell, so it has no Scaffold: on a phone it fills the body,
/// on a wide window it sits in the side panel next to the map. Step 9 adds the
/// vehicle detail; step 10 replaces the temporary button.
class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The snapshot changes when the game does; the UI clock moves the bars
    // and the timers once a second.
    final snapshot = context.select((GameEngine e) => e.snapshot);
    final now = context.select((UiClock c) => c.now);
    final engine = context.read<GameEngine>();
    final fmt = context.fmt;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.formMaxWidth),
        child: ListView(
          padding: const EdgeInsets.all(Space.s4),
          children: [
            Text(l10n.garageVehiclesTitle, style: theme.textTheme.titleMedium),
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
