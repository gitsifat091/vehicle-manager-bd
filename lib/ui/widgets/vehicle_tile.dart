import 'package:flutter/material.dart';

import '../../core/sim/vehicle_status.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_context.dart';
import '../theme/app_theme.dart';
import '../theme/game_colors.dart';
import '../theme/lal_sabuj_tokens.dart';

/// One vehicle in a list: name, what it is doing, its route and cargo, and a
/// progress bar with the time left while it is on the road.
///
/// [now] comes from the UI clock, so the bar and the timer move once a second.
/// [action] is an optional button at the bottom (the temporary "start
/// working" button for now).
class VehicleTile extends StatelessWidget {
  const VehicleTile({
    super.key,
    required this.vehicle,
    required this.activity,
    required this.now,
    this.action,
  });

  final Vehicle vehicle;
  final VehicleActivity activity;
  final DateTime now;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = theme.extension<GameColors>()!;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final routeId = vehicle.assignedRouteId;
    final cargo = vehicle.assignedCargo;

    final status = switch (activity.status) {
      VehicleStatus.idle => l10n.vehicleStatusIdle,
      VehicleStatus.onTheRoad => l10n.vehicleStatusOnTheRoad,
      VehicleStatus.waitingForDemand => l10n.vehicleStatusWaiting,
      VehicleStatus.readyToDispatch => l10n.vehicleStatusReady,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.vehicleNameOf(vehicle.tier),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(status, style: theme.textTheme.labelMedium),
              ],
            ),
            if (routeId != null && cargo != null) ...[
              const SizedBox(height: Space.s1),
              Text(
                l10n.vehicleRouteLine(
                  context.routeNameOf(routeId),
                  context.cargoNameOf(cargo),
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (activity.status == VehicleStatus.onTheRoad) ...[
              const SizedBox(height: Space.s2),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.full),
                child: LinearProgressIndicator(
                  value: activity.progress,
                  minHeight: Space.s2,
                  color: game.tripProgress,
                  backgroundColor: game.tripTrack,
                ),
              ),
              const SizedBox(height: Space.s1),
              Text(
                l10n.vehicleArrivesIn(
                  fmt.clock(activity.trip!.arriveAt.difference(now)),
                ),
                style: GameText.stat(context),
              ),
            ],
            if (activity.status == VehicleStatus.waitingForDemand) ...[
              const SizedBox(height: Space.s1),
              Text(
                l10n.vehicleDepartsIn(
                  fmt.clock(activity.until!.difference(now)),
                ),
                style: GameText.stat(context),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Space.s2),
              Align(alignment: AlignmentDirectional.centerStart, child: action),
            ],
          ],
        ),
      ),
    );
  }
}
