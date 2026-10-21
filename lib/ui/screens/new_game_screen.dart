import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/economy_config.dart';
import '../../l10n/l10n_context.dart';
import '../../state/game_engine.dart';
import '../layout.dart';
import '../theme/lal_sabuj_tokens.dart';

/// Shown when there is no saved company: asks for a name and starts the game.
class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  /// Longest company name the field accepts.
  static const maxNameLength = 30;

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _starting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || !_formKey.currentState!.validate()) return;
    setState(() => _starting = true);
    final engine = context.read<GameEngine>();
    await engine.startNewGame(_controller.text.trim());
    // The home screen replaces this one as soon as the game exists.
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.read<EconomyConfig>().settings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.s4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Layout.formMaxWidth),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.newGameTitle,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: Space.s2),
                  Text(
                    l10n.newGameIntro(
                      context.fmt.money(settings.startingCash),
                      context.vehicleNameOf(settings.starterVehicleTier),
                    ),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: Space.s6),
                  TextFormField(
                    controller: _controller,
                    enabled: !_starting,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        NewGameScreen.maxNameLength,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.companyNameLabel,
                      hintText: l10n.companyNameHint,
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.companyNameRequired
                        : null,
                    onFieldSubmitted: (_) => _start(),
                  ),
                  const SizedBox(height: Space.s6),
                  FilledButton(
                    onPressed: _starting ? null : _start,
                    child: Text(l10n.startGameButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
