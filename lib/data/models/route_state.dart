import '../../core/config/economy_config.dart';

/// The saved, changing part of a route. The fixed part (distance, tolls,
/// weighbridges) is a RouteSpec in the config, found through [routeId].
class RouteState {
  RouteState({
    required this.routeId,
    required this.demandRemainingT,
    required DateTime updatedAt,
    this.gameDay,
  }) : updatedAt = updatedAt.toUtc();

  /// A route with its full daily demand, in game day [gameDay].
  factory RouteState.initial(RouteSpec route, DateTime now, {int? gameDay}) {
    return RouteState(
      routeId: route.id,
      demandRemainingT: route.dailyDemandT,
      updatedAt: now,
      gameDay: gameDay,
    );
  }

  final String routeId;

  /// Tons still available today. Regenerates over time (Milestone 5).
  final double demandRemainingT;

  /// When [demandRemainingT] was last brought up to date.
  final DateTime updatedAt;

  /// The game day [demandRemainingT] belongs to. The game clock runs faster
  /// than real time during Turbo Start, so the day cannot be worked out again
  /// from [updatedAt] later. Null in saves from before this field existed;
  /// those fall back to the day of [updatedAt].
  final int? gameDay;

  RouteState copyWith({
    double? demandRemainingT,
    DateTime? updatedAt,
    int? gameDay,
  }) {
    return RouteState(
      routeId: routeId,
      demandRemainingT: demandRemainingT ?? this.demandRemainingT,
      updatedAt: updatedAt ?? this.updatedAt,
      gameDay: gameDay ?? this.gameDay,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RouteState &&
      other.routeId == routeId &&
      other.demandRemainingT == demandRemainingT &&
      other.updatedAt == updatedAt &&
      other.gameDay == gameDay;

  @override
  int get hashCode =>
      Object.hash(routeId, demandRemainingT, updatedAt, gameDay);

  @override
  String toString() => 'RouteState($routeId, demand: $demandRemainingT t)';
}
