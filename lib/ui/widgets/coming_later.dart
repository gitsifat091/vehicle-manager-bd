import 'package:flutter/material.dart';

import '../../l10n/l10n_context.dart';
import '../theme/game_colors.dart';
import '../theme/lal_sabuj_tokens.dart';

/// Stand-in for a screen that a later Milestone 4 step builds: its title and
/// a short note. With [onMap] it is drawn on the map's land colour, so the
/// map area of the wide layout already reads as the map.
class ComingLater extends StatelessWidget {
  const ComingLater({super.key, required this.title, this.onMap = false});

  final String title;
  final bool onMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = theme.extension<GameColors>()!;
    return ColoredBox(
      color: onMap ? game.mapLand : theme.scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: Space.s1),
              Text(
                context.l10n.comingLater,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
