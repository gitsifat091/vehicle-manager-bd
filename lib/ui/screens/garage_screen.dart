import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/economy_config.dart';
import '../../core/sim/vehicle_status.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_context.dart';
import '../../state/game_engine.dart';
import '../../state/game_snapshot.dart';
import '../../state/ui_clock.dart';
import '../layout.dart';
import '../theme/lal_sabuj_tokens.dart';
import '../widgets/vehicle_info.dart';
import '../widgets/vehicle_tile.dart';
import 'vehicle_detail.dart';

/// The garage: the slot count and the player's vehicles, or one vehicle in
/// full when [openVehicleId] is set.
///
/// A page of the shell, so it has no Scaffold: on a phone or a medium window
/// it fills the page area, on a wide window it sits in the side panel next to
/// the map, and the detail opens in the same place. The open vehicle is held
/// by the shell, not here, so a resize across a breakpoint keeps it open. The
/// system back button closes the detail before it leaves the garage. Step 10
/// replaces the temporary button.
class GarageScreen extends StatelessWidget {
  const GarageScreen({
    super.key,
    this.openVehicleId,
    required this.onOpenVehicle,
    required this.onCloseVehicle,
  });

  /// The vehicle whose detail is shown, or null for the list.
  final String? openVehicleId;
  final ValueChanged<String> onOpenVehicle;
  final VoidCallback onCloseVehicle;

  @override
  Widget build(BuildContext context) {
    // The snapshot changes when the game does; the UI clock moves the bars
    // and the timers once a second.
    final snapshot = context.select((GameEngine e) => e.snapshot);
    final now = context.select((UiClock c) => c.now);
    final id = openVehicleId;
    final open = id == null ? null : snapshot.vehicleById(id);
    if (id != null && open == null) {
      // The vehicle left the garage (sold). Forget it after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => onCloseVehicle());
    }

    return PopScope(
      canPop: open == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onCloseVehicle();
      },
      child: open == null
          ? _list(context, snapshot, now)
          : VehicleDetail(
              key: ValueKey(open.id),
              vehicle: open,
              activity: snapshot.activityOf(open, now),
              now: now,
              recentTrips: snapshot.recentTripsOf(open.id),
              onBack: onCloseVehicle,
            ),
    );
  }

  Widget _list(BuildContext context, GameSnapshot snapshot, DateTime now) {
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
            for (final vehicle in snapshot.vehicles) ...[
              _tile(context, vehicle, snapshot.activityOf(vehicle, now), now),
              const SizedBox(height: Space.s2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    Vehicle vehicle,
    VehicleActivity activity,
    DateTime now,
  ) {
    return VehicleTile(
      vehicle: vehicle,
      activity: activity,
      now: now,
      profitPerHourTk: expectedProfitPerHourTk(
        context.read<EconomyConfig>(),
        vehicle,
      ),
      onTap: () => onOpenVehicle(vehicle.id),
      action: activity.status == VehicleStatus.idle
          ? tempStartWorkingButton(context, context.read<GameEngine>(), vehicle)
          : null,
    );
  }
}
