import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/economy_config.dart';
import '../../core/economy/purchase_rules.dart';
import '../../core/sim/vehicle_status.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_context.dart';
import '../../state/game_engine.dart';
import '../layout.dart';
import '../theme/app_theme.dart';
import '../theme/game_colors.dart';
import '../theme/lal_sabuj_tokens.dart';
import '../widgets/vehicle_info.dart';

/// One vehicle in full: status and trip progress, route and cargo, the money
/// of the trip on the road, expected profit per hour, what it sells for, its
/// recent trips and its specs from the config.
///
/// Shown by the garage in place of the list, so it sits wherever the garage
/// page is: the whole page area on a phone or a medium window, the side
/// panel on a wide one. [onBack] returns to the list.
class VehicleDetail extends StatelessWidget {
  const VehicleDetail({
    super.key,
    required this.vehicle,
    required this.activity,
    required this.now,
    required this.recentTrips,
    required this.onBack,
  });

  final Vehicle vehicle;
  final VehicleActivity activity;
  final DateTime now;

  /// Settled trips of this vehicle, newest first.
  final List<Trip> recentTrips;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final config = context.read<EconomyConfig>();
    final spec = config.vehicleByTier(vehicle.tier);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final fmt = context.fmt;
    final profitPerHour = expectedProfitPerHourTk(config, vehicle);
    final trip = activity.trip;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.formMaxWidth),
        child: ListView(
          padding: const EdgeInsets.all(Space.s4),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_outlined),
                label: Text(l10n.vehicleDetailBack),
              ),
            ),
            const SizedBox(height: Space.s2),
            Text(
              context.vehicleNameOf(vehicle.tier),
              style: theme.textTheme.titleLarge,
            ),
            Text(
              l10n.vehicleTierLine(fmt.integer(vehicle.tier)),
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: Space.s4),
            _StatusCard(vehicle: vehicle, activity: activity, now: now),
            _Section(
              title: l10n.vehicleEarningsTitle,
              children: [
                if (profitPerHour != null) ...[
                  Text(
                    l10n.vehicleProfitPerHourLabel,
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(
                    fmt.money(profitPerHour),
                    style: _moneyStyle(context, GameText.money, profitPerHour),
                  ),
                  Text(
                    l10n.vehicleProfitPerHourNote,
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: Space.s4),
                ],
                Text(
                  l10n.vehicleSaleValueLabel,
                  style: theme.textTheme.labelMedium,
                ),
                Text(
                  fmt.money(
                    saleValueTk(
                      settings: config.settings,
                      vehicle: spec,
                      isStarter: vehicle.isStarter,
                    ),
                  ),
                  style: GameText.money(context),
                ),
              ],
            ),
            if (trip != null)
              _Section(
                title: l10n.vehicleCurrentTripTitle,
                children: [
                  _ValueRow(
                    label: l10n.tripLoadLabel,
                    value: l10n.tonsValue(fmt.decimal(trip.loadT)),
                  ),
                  _ValueRow(
                    label: l10n.tripRevenueLabel,
                    value: fmt.money(trip.revenue),
                  ),
                  _ValueRow(
                    label: l10n.costEnergyLabel,
                    value: fmt.money(-trip.costs.energy),
                  ),
                  _ValueRow(
                    label: l10n.costTollLabel,
                    value: fmt.money(-trip.costs.toll),
                  ),
                  _ValueRow(
                    label: l10n.costCrewLabel,
                    value: fmt.money(-trip.costs.crew),
                  ),
                  _ValueRow(
                    label: l10n.costMaintenanceLabel,
                    value: fmt.money(-trip.costs.maintenance),
                  ),
                  // Fines and accidents are expected values until the trip
                  // arrives and they are rolled.
                  _ValueRow(
                    label: l10n.costFinesExpectedLabel,
                    value: fmt.money(-trip.costs.fines),
                  ),
                  _ValueRow(
                    label: l10n.costAccidentExpectedLabel,
                    value: fmt.money(-trip.costs.accident),
                  ),
                  const Divider(),
                  _ValueRow(
                    label: l10n.tripProfitExpectedLabel,
                    value: fmt.money(trip.profit),
                    profit: trip.profit,
                  ),
                ],
              ),
            _Section(
              title: l10n.vehicleRecentTripsTitle,
              children: [
                Text(
                  l10n.vehicleRecentTripsNote,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: Space.s2),
                if (recentTrips.isEmpty)
                  Text(
                    l10n.vehicleRecentTripsNone,
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  for (final t in recentTrips)
                    _ValueRow(
                      label: l10n.vehicleRouteLine(
                        context.routeNameOf(t.routeId),
                        context.cargoNameOf(t.cargo),
                      ),
                      value: fmt.money(t.profit),
                      profit: t.profit,
                    ),
              ],
            ),
            _Section(
              title: l10n.vehicleSpecsTitle,
              children: [
                _ValueRow(
                  label: l10n.specPriceLabel,
                  value: fmt.money(spec.priceTk),
                ),
                _ValueRow(
                  label: l10n.specLegalPayloadLabel,
                  value: l10n.tonsValue(fmt.decimal(spec.legalPayloadT)),
                ),
                _ValueRow(
                  label: l10n.specMaxLoadLabel,
                  value: l10n.tonsValue(fmt.decimal(spec.maxLoadT)),
                ),
                _ValueRow(
                  label: l10n.specSpeedLabel,
                  value: l10n.speedValue(fmt.decimal(spec.speedKmh)),
                ),
                if (spec.mileageKmPerL > 0)
                  _ValueRow(
                    label: l10n.specMileageLabel,
                    value: l10n.mileageValue(fmt.decimal(spec.mileageKmPerL)),
                  )
                else if (spec.otherEnergyTkPerKm > 0)
                  _ValueRow(
                    label: l10n.specEnergyCostLabel,
                    value: l10n.perKmValue(
                      fmt.decimal(spec.otherEnergyTkPerKm, places: 2),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Status, route and cargo, trip progress and the vehicle's buttons.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.vehicle,
    required this.activity,
    required this.now,
  });

  final Vehicle vehicle;
  final VehicleActivity activity;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final engine = context.read<GameEngine>();
    final work = vehicleWorkLine(context, vehicle, activity);
    final onTheRoad = activity.status == VehicleStatus.onTheRoad;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vehicleStatusLabel(context, activity.status),
              style: theme.textTheme.titleMedium,
            ),
            if (work != null) Text(work, style: theme.textTheme.bodyMedium),
            if (onTheRoad && !vehicle.isAssigned)
              Text(
                l10n.vehicleGoesHomeNote,
                style: theme.textTheme.labelMedium,
              ),
            const SizedBox(height: Space.s2),
            VehicleProgress(activity: activity, now: now),
            const SizedBox(height: Space.s2),
            Wrap(
              spacing: Space.s2,
              runSpacing: Space.s2,
              children: [
                if (vehicle.isAssigned)
                  OutlinedButton(
                    onPressed: () => engine.unassignVehicle(vehicle.id),
                    child: Text(l10n.vehicleUnassignButton),
                  ),
                if (activity.status == VehicleStatus.idle)
                  tempStartWorkingButton(context, engine, vehicle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled card of the detail.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Space.s2),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A label on the left and a number on the right. With [profit] the number
/// takes the loss colour when it is below zero.
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value, this.profit});

  final String label;
  final String value;
  final int? profit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: Space.s2),
          Text(value, style: _moneyStyle(context, GameText.stat, profit)),
        ],
      ),
    );
  }
}

/// [base] in the loss colour when [profit] is below zero.
TextStyle _moneyStyle(
  BuildContext context,
  TextStyle Function(BuildContext) base,
  int? profit,
) {
  final style = base(context);
  if (profit == null || profit >= 0) return style;
  return style.copyWith(
    color: Theme.of(context).extension<GameColors>()!.moneyLoss,
  );
}
