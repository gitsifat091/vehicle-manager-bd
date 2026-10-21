import '../core/sim/clock.dart';

/// The real clock, in UTC. The only place that reads the system time.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
