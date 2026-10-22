import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_context.dart';
import '../../state/game_engine.dart';
import '../../state/ui_clock.dart';
import '../layout.dart';
import '../screens/garage_screen.dart';
import '../theme/app_theme.dart';
import '../theme/game_colors.dart';
import '../theme/lal_sabuj_tokens.dart';
import '../widgets/coming_later.dart';

/// The main places of the game, in navigation order.
enum ShellDestination { map, garage, finance, settings }

/// The frame around every screen once a game exists.
///
/// One layout per [WindowClass]:
/// - compact: the selected page fills the body and a bottom bar switches
///   pages
/// - medium: a navigation rail replaces the bar and the selected page fills
///   the area beside it (the map too, when it is selected). No side panel
/// - expanded: a rail, the map in the main area and the selected page in a
///   side panel next to it. Choosing the map closes the panel
///
/// All three share the header (company, cash, turbo) and the selection, so
/// resizing a window across a breakpoint keeps the page.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialDestination = ShellDestination.garage,
  });

  /// The garage until the map is built (step 12), because it is the page
  /// with something to do.
  final ShellDestination initialDestination;

  /// The map, in whichever layout shows it.
  static const mapAreaKey = Key('shell.mapArea');

  /// The side panel of the expanded layout.
  static const sidePanelKey = Key('shell.sidePanel');

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late ShellDestination _selected = widget.initialDestination;

  void _select(int index) =>
      setState(() => _selected = ShellDestination.values[index]);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final windowClass = Layout.windowClassOf(constraints.maxWidth);
        return Scaffold(
          appBar: const _ShellHeader(),
          body: switch (windowClass) {
            WindowClass.compact => _page(context, _selected),
            WindowClass.medium => _railBody(context, _page(context, _selected)),
            WindowClass.expanded => _railBody(context, _mapAndPanel(context)),
          },
          bottomNavigationBar: windowClass == WindowClass.compact
              ? NavigationBar(
                  selectedIndex: _selected.index,
                  onDestinationSelected: _select,
                  destinations: [
                    for (final d in ShellDestination.values)
                      NavigationDestination(
                        icon: Icon(_icon(d)),
                        label: _label(context, d),
                      ),
                  ],
                )
              : null,
        );
      },
    );
  }

  /// The rail on the left and [child] in the rest (medium and expanded).
  Widget _railBody(BuildContext context, Widget child) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selected.index,
          onDestinationSelected: _select,
          labelType: NavigationRailLabelType.all,
          destinations: [
            for (final d in ShellDestination.values)
              NavigationRailDestination(
                icon: Icon(_icon(d)),
                label: Text(_label(context, d)),
              ),
          ],
        ),
        const VerticalDivider(width: Layout.dividerWidth),
        Expanded(child: child),
      ],
    );
  }

  /// The expanded layout's area beside the rail: the map, and the selected
  /// page in a side panel unless the map itself is selected.
  Widget _mapAndPanel(BuildContext context) {
    return LayoutBuilder(
      builder: (context, area) => Row(
        children: [
          Expanded(child: _page(context, ShellDestination.map)),
          if (_selected != ShellDestination.map) ...[
            const VerticalDivider(width: Layout.dividerWidth),
            SizedBox(
              key: AppShell.sidePanelKey,
              width: Layout.sidePanelWidth(area.maxWidth),
              child: _page(context, _selected),
            ),
          ],
        ],
      ),
    );
  }

  Widget _page(BuildContext context, ShellDestination d) {
    return switch (d) {
      // Steps 12 (map), 13 (finance) and 14 (settings) replace these.
      ShellDestination.map => ComingLater(
        key: AppShell.mapAreaKey,
        title: _label(context, d),
        onMap: true,
      ),
      ShellDestination.garage => const GarageScreen(),
      ShellDestination.finance ||
      ShellDestination.settings => ComingLater(title: _label(context, d)),
    };
  }

  static IconData _icon(ShellDestination d) => switch (d) {
    ShellDestination.map => Icons.map_outlined,
    ShellDestination.garage => Icons.local_shipping_outlined,
    ShellDestination.finance => Icons.account_balance_wallet_outlined,
    ShellDestination.settings => Icons.settings_outlined,
  };

  static String _label(BuildContext context, ShellDestination d) {
    final l10n = context.l10n;
    return switch (d) {
      ShellDestination.map => l10n.navMap,
      ShellDestination.garage => l10n.navGarage,
      ShellDestination.finance => l10n.navFinance,
      ShellDestination.settings => l10n.navSettings,
    };
  }
}

/// The bar on top of every page: company name, cash, and the turbo badge
/// while Turbo Start runs.
class _ShellHeader extends StatelessWidget implements PreferredSizeWidget {
  const _ShellHeader();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final company = context.select((GameEngine e) => e.snapshot.company);
    final engine = context.read<GameEngine>();
    // The speed depends on the clock, so it is read on each UI clock second;
    // the header only rebuilds when it changes.
    final speed = context.select((UiClock _) => engine.turboSpeed);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final fmt = context.fmt;

    return AppBar(
      centerTitle: false,
      title: company == null
          ? Text(l10n.appTitle, style: theme.textTheme.titleMedium)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  company.name,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.cashLine(fmt.money(company.cash)),
                  style: GameText.stat(context),
                ),
              ],
            ),
      actions: [
        if (speed > 1) _TurboBadge(speed: speed),
        const SizedBox(width: Space.s4),
      ],
    );
  }
}

class _TurboBadge extends StatelessWidget {
  const _TurboBadge({required this.speed});

  final double speed;

  @override
  Widget build(BuildContext context) {
    final game = Theme.of(context).extension<GameColors>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: game.turboBadge,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s2,
          vertical: Space.s1,
        ),
        child: Text(
          context.l10n.turboBadge(context.fmt.decimal(speed, places: 0)),
          style: GameText.stat(context).copyWith(color: game.onTurboBadge),
        ),
      ),
    );
  }
}
