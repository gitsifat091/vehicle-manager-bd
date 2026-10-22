import 'trip.dart';

/// What the company earned and spent on the trips settled in one game day,
/// for the finance screen.
///
/// Updated in the same `ChangeSet` as the settlement, as an absolute value,
/// so a trip is counted exactly once even if a save is interrupted. Settled
/// trips can therefore be pruned later without losing the history.
class DayRollup {
  const DayRollup({
    required this.gameDay,
    this.revenue = 0,
    this.costs = TripCosts.zero,
    this.trips = 0,
  });

  /// The game day, counted from the company's creation (day 0).
  final int gameDay;

  /// Whole Taka, the sum of the settled trips' revenue.
  final int revenue;

  /// The sum of the settled trips' final costs, part by part.
  final TripCosts costs;

  /// Trips settled this day.
  final int trips;

  int get profit => revenue - costs.total;

  /// This day with [trip] counted too.
  DayRollup add(Trip trip) => DayRollup(
    gameDay: gameDay,
    revenue: revenue + trip.revenue,
    costs: costs + trip.costs,
    trips: trips + 1,
  );

  @override
  bool operator ==(Object other) =>
      other is DayRollup &&
      other.gameDay == gameDay &&
      other.revenue == revenue &&
      other.costs == costs &&
      other.trips == trips;

  @override
  int get hashCode => Object.hash(gameDay, revenue, costs, trips);

  @override
  String toString() =>
      'DayRollup(day $gameDay, revenue: $revenue, trips: $trips)';
}
