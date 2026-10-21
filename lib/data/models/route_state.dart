import '../../core/config/economy_config.dart';

/// The saved, changing part of a route. The fixed part (distance, tolls,
/// weighbridges) is a RouteSpec in the config, found through [routeId].
class RouteState {
  RouteState({
    required this.routeId,
    required this.demandRemainingT,
    required DateTime updatedAt,
  }) : updatedAt = updatedAt.toUtc();

  /// A route with its full daily demand.
  factory RouteState.initial(RouteSpec route, DateTime now) {
    return RouteState(
      routeId: route.id,
      demandRemainingT: route.dailyDemandT,
      updatedAt: now,
    );
  }

  final String routeId;

  /// Tons still available today. Regenerates over time (Milestone 5).
  final double demandRemainingT;

  /// When [demandRemainingT] was last brought up to date.
  final DateTime updatedAt;

  RouteState copyWith({double? demandRemainingT, DateTime? updatedAt}) {
    return RouteState(
      routeId: routeId,
      demandRemainingT: demandRemainingT ?? this.demandRemainingT,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RouteState &&
      other.routeId == routeId &&
      other.demandRemainingT == demandRemainingT &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(routeId, demandRemainingT, updatedAt);

  @override
  String toString() => 'RouteState($routeId, demand: $demandRemainingT t)';
}
