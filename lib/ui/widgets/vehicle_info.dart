import 'package:flutter/material.dart';

import '../../core/config/economy_config.dart';
import '../../core/economy/route_economics.dart';
import '../../core/economy/trip_planner.dart';
import '../../core/sim/vehicle_status.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_context.dart';
import '../../state/game_engine.dart';
import '../theme/app_theme.dart';
import '../theme/game_colors.dart';
import '../theme/lal_sabuj_tokens.dart';

/// The translated name of a vehicle's [status].
String vehicleStatusLabel(BuildContext context, VehicleStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    VehicleStatus.idle => l10n.vehicleStatusIdle,
    VehicleStatus.onTheRoad => l10n.vehicleStatusOnTheRoad,
    VehicleStatus.waitingForDemand => l10n.vehicleStatusWaiting,
    VehicleStatus.readyToDispatch => l10n.vehicleStatusReady,
  };
}

/// The route and cargo line of what [vehicle] is doing: the trip on the road
/// if there is one (it still runs after an unassign), otherwise its
/// assignment. Null for an idle vehicle.
String? vehicleWorkLine(
  BuildContext context,
  Vehicle vehicle,
  VehicleActivity activity,
) {
  final trip = activity.trip;
  final routeId = trip?.routeId ?? vehicle.assignedRouteId;
  final cargo = trip?.cargo ?? vehicle.assignedCargo;
  if (routeId == null || cargo == null) return null;
  return context.l10n.vehicleRouteLine(
    context.routeNameOf(routeId),
    context.cargoNameOf(cargo),
  );
}

/// Expected profit per real hour at 1x of [vehicle]'s assignment, in whole
/// Taka (`route_economics`, the same figure as the buy screen's preview).
/// Null when it is not assigned or the config no longer allows the job.
int? expectedProfitPerHourTk(EconomyConfig config, Vehicle vehicle) {
  final routeId = vehicle.assignedRouteId;
  final cargoName = vehicle.assignedCargo;
  if (routeId == null || cargoName == null) return null;
  final spec = config.vehicleByTier(vehicle.tier);
  final route = config.routeById(routeId);
  final cargo = config.cargoByName(cargoName);
  final rejection = checkTripEligibility(
    settings: config.settings,
    vehicle: spec,
    route: route,
    cargo: cargo,
  );
  if (rejection != null) return null;
  return routeEconomics(
    config: config,
    vehicle: spec,
    route: route,
    cargo: cargo,
  ).profitPerRealHour.round();
}

/// The moving part of a vehicle's status: a progress bar and the time left
/// while it is on the road, or the time until it goes again while it waits
/// for demand. Nothing in the other states.
///
/// [now] comes from the UI clock, so it moves once a second.
class VehicleProgress extends StatelessWidget {
  const VehicleProgress({super.key, required this.activity, required this.now});

  final VehicleActivity activity;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final game = Theme.of(context).extension<GameColors>()!;
    final l10n = context.l10n;
    final fmt = context.fmt;
    return switch (activity.status) {
      VehicleStatus.onTheRoad => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
      ),
      VehicleStatus.waitingForDemand => Text(
        l10n.vehicleDepartsIn(fmt.clock(activity.until!.difference(now))),
        style: GameText.stat(context),
      ),
      VehicleStatus.idle ||
      VehicleStatus.readyToDispatch => const SizedBox.shrink(),
    };
  }
}

/// TEMPORARY, removed in step 10 when the assign-route screen exists: sends
/// an idle vehicle to work on the first city route so the game can be
/// watched running.
Widget tempStartWorkingButton(
  BuildContext context,
  GameEngine engine,
  Vehicle vehicle,
) {
  return FilledButton.tonal(
    onPressed: () => engine.assignVehicle(
      vehicle.id,
      routeId: 'R01',
      cargoName: 'General dry',
    ),
    child: Text(context.l10n.tempStartWorking),
  );
}
