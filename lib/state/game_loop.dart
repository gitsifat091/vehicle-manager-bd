import 'dart:async';

import 'package:flutter/widgets.dart';

import 'game_engine.dart';

/// Ticks the [GameEngine] every few seconds while the app is open, and tells
/// it when the app goes to the background and comes back.
///
/// It is a slow timer, not a frame loop: trips are finished by timestamps, so
/// a tick only has to notice that some have arrived.
///
/// Foreground means the app is on screen: `resumed` and `inactive`. On a
/// desktop a window that lost focus is `inactive`, and it keeps ticking and
/// keeps counting Turbo Start time (on Android `inactive` is the notification
/// shade or a dialog). Only `hidden`, `paused` and `detached` (minimised,
/// backgrounded, closing) freeze the turbo and stop the timer.
class GameLoop with WidgetsBindingObserver {
  GameLoop(this.engine, {this.interval = const Duration(seconds: 3)});

  final GameEngine engine;
  final Duration interval;
  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  /// Starts ticking and watching the app lifecycle.
  void start() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
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
    switch (state) {
      case AppLifecycleState.resumed:
        _resume();
      case AppLifecycleState.inactive:
        // Transient (a dialog, a notification shade): still on screen.
        break;
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        _pause();
    }
  }

  void _resume() {
    if (!_running) return;
    unawaited(engine.resume().then((_) => engine.tick()));
    _startTimer();
  }

  void _pause() {
    _stopTimer();
    unawaited(engine.pause());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(engine.tick()));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
