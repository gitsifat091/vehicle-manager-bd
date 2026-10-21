enum TripRejectionReason {
  /// The vehicle is not allowed on highways (tier 1 and 2) but the route is a
  /// Line haul or crosses a bridge or ferry.
  vehicleNotAllowedOnHighway,

  /// Line haul longer than the game's 400 km limit.
  lineHaulTooLong,

  /// Overload below zero.
  negativeOverload,
}

/// Why a vehicle cannot run a route. [message] is for logs and tests; the UI
/// maps [reason] to an ARB string.
class TripRejection {
  const TripRejection(this.reason, this.message);

  final TripRejectionReason reason;
  final String message;

  @override
  String toString() => 'TripRejection(${reason.name}): $message';
}

/// Thrown by quoteTrip when the trip is not allowed.
class TripRejectedException implements Exception {
  const TripRejectedException(this.rejection);

  final TripRejection rejection;

  @override
  String toString() => 'TripRejectedException: ${rejection.message}';
}
