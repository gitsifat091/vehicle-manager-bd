import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/sim/clock.dart';

/// A once-a-second "now" for the parts of the screen that move with time:
/// progress bars, countdowns, the turbo speed.
///
/// It is separate from the 3 second [GameLoop] tick. The loop changes the
/// saved game; this only tells widgets to look at the clock again. A widget
/// that does `context.select((UiClock c) => c.now)` rebuilds once a second,
/// and nothing else does. It stops while the app is hidden or paused and
/// catches up at once when the app comes back.
class UiClock extends ChangeNotifier with WidgetsBindingObserver {
  UiClock(this._clock, {this.interval = const Duration(seconds: 1)})
    : _now = _clock.now();

  final Clock _clock;
  final Duration interval;
  DateTime _now;
  Timer? _timer;
  bool _running = false;

  DateTime get now => _now;
  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _startTimer();
  }

  void stop() {
    if (!_running) return;
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _refresh();
        _startTimer();
      case AppLifecycleState.inactive:
        // Still on screen (a window without focus): keep going.
        break;
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        _stopTimer();
    }
  }

  void _refresh() {
    _now = _clock.now();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _refresh());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
