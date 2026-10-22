import 'package:flutter/material.dart';

import '../../core/sim/vehicle_status.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_context.dart';
import '../theme/app_theme.dart';
import '../theme/lal_sabuj_tokens.dart';
import 'vehicle_info.dart';

/// One vehicle in a list: name and tier, what it is doing, its route and
/// cargo, a progress bar with the time left while it is on the road, and the
/// expected profit per hour of its job.
///
/// [now] comes from the UI clock, so the bar and the timer move once a second.
/// [onTap] opens the vehicle; the whole card is the touch target and shows a
/// hover highlight under a mouse. [action] is an optional button at the
/// bottom (the temporary "start working" button for now).
class VehicleTile extends StatelessWidget {
  const VehicleTile({
    super.key,
    required this.vehicle,
    required this.activity,
    required this.now,
    this.profitPerHourTk,
    this.onTap,
    this.action,
  });

  final Vehicle vehicle;
  final VehicleActivity activity;
  final DateTime now;

  /// Expected profit per real hour of the vehicle's assignment, or null when
  /// it has none.
  final int? profitPerHourTk;
  final VoidCallback? onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final fmt = context.fmt;
    final work = vehicleWorkLine(context, vehicle, activity);
    final profit = profitPerHourTk;
    final moving =
        activity.status == VehicleStatus.onTheRoad ||
        activity.status == VehicleStatus.waitingForDemand;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  Text(
                    vehicleStatusLabel(context, activity.status),
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
              Text(
                l10n.vehicleTierLine(fmt.integer(vehicle.tier)),
                style: theme.textTheme.labelMedium,
              ),
              if (work != null) ...[
                const SizedBox(height: Space.s1),
                Text(work, style: theme.textTheme.bodyMedium),
              ],
              if (moving) ...[
                const SizedBox(height: Space.s2),
                VehicleProgress(activity: activity, now: now),
              ],
              if (profit != null) ...[
                const SizedBox(height: Space.s1),
                Text(
                  l10n.vehicleProfitPerHour(fmt.money(profit)),
                  style: GameText.stat(context),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Space.s2),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: action,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
