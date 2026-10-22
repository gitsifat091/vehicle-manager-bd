import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/economy_config.dart';
import '../../core/economy/purchase_rules.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_context.dart';
import '../../state/game_engine.dart';
import '../theme/app_theme.dart';
import '../theme/lal_sabuj_tokens.dart';

/// Sells [vehicle] after the player confirms.
///
/// A sale the engine would refuse is explained first, without a
/// confirmation: on the road (with an Unassign button while it is still
/// assigned) or the company's last vehicle. The confirmation shows what the
/// sale pays, and for the free starter its fixed sale value note. A vehicle
/// that is already gone (a second tap) closes the dialog and shows nothing.
/// The sale checks again, so a refusal that appears between the confirmation
/// and the sale is explained the same way.
Future<void> sellWithConfirmation(BuildContext context, Vehicle vehicle) async {
  final engine = context.read<GameEngine>();
  final config = context.read<EconomyConfig>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  final fmt = context.fmt;
  final name = context.vehicleNameOf(vehicle.tier);
  final value = saleValueTk(
    settings: config.settings,
    vehicle: config.vehicleByTier(vehicle.tier),
    isStarter: vehicle.isStarter,
  );

  final preview = await engine.previewSale(vehicle.id);
  if (!context.mounted) return;
  if (preview != null) return _explainRefusal(context, vehicle.id, preview);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _ConfirmSaleDialog(
      vehicleName: name,
      amount: fmt.money(value),
      isStarter: vehicle.isStarter,
    ),
  );
  if (confirmed != true) return;

  final rejection = await engine.sellVehicle(vehicle.id);
  if (rejection == null) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.vehicleSoldMessage(name, fmt.money(value)))),
    );
    return;
  }
  if (!context.mounted) return;
  return _explainRefusal(context, vehicle.id, rejection);
}

Future<void> _explainRefusal(
  BuildContext context,
  String vehicleId,
  SaleRejection rejection,
) async {
  final engine = context.read<GameEngine>();
  final l10n = context.l10n;
  // Read now: an unassign may already have happened.
  final stillAssigned =
      engine.snapshot.vehicleById(vehicleId)?.isAssigned ?? false;

  final String message;
  var offerUnassign = false;
  switch (rejection.reason) {
    case SaleRejectionReason.notOwned:
      return;
    case SaleRejectionReason.vehicleOnTheRoad:
      offerUnassign = stillAssigned;
      message = stillAssigned
          ? l10n.sellRefusedOnTheRoad
          : l10n.sellRefusedOnLastTrip;
    case SaleRejectionReason.lastVehicleUnaffordable:
      message = l10n.sellRefusedLastVehicle;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.sellRefusedTitle),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.closeButton),
        ),
        if (offerUnassign)
          FilledButton(
            onPressed: () {
              engine.unassignVehicle(vehicleId);
              Navigator.of(context).pop();
            },
            child: Text(l10n.vehicleUnassignButton),
          ),
      ],
    ),
  );
}

class _ConfirmSaleDialog extends StatelessWidget {
  const _ConfirmSaleDialog({
    required this.vehicleName,
    required this.amount,
    required this.isStarter,
  });

  final String vehicleName;
  final String amount;
  final bool isStarter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sellConfirmTitle(vehicleName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sellConfirmYouGet, style: theme.textTheme.labelMedium),
          Text(amount, style: GameText.money(context)),
          if (isStarter) ...[
            const SizedBox(height: Space.s2),
            Text(
              l10n.starterSaleNote(amount),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelButton),
        ),
        OutlinedButton(
          style: AppButtons.danger(context),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.vehicleSellButton),
        ),
      ],
    );
  }
}
