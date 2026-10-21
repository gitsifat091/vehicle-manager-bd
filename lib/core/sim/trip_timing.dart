import '../config/economy_config.dart';

/// Real duration = game hours x 60 / gameMinutesPerRealMinute / turbo speed.
///
/// [turboSpeed] is the speed at dispatch time and stays fixed for the trip,
/// so arrival is a single timestamp that never needs to be recomputed.
Duration realTripDuration({
  required EconomySettings settings,
  required double gameHours,
  required double turboSpeed,
}) {
  final minutes =
      gameHours * 60 / settings.gameMinutesPerRealMinute / turboSpeed;
  return Duration(microseconds: (minutes * 60e6).round());
}
