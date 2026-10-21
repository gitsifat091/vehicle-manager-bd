import '../../data/models/models.dart';

/// What a vehicle is doing right now, for the garage and the map.
enum VehicleStatus {
  /// Not assigned to a route.
  idle,

  /// Has an unsettled trip. Includes the few seconds between arriving and the
  /// next tick paying the trip out.
  onTheRoad,

  /// Assigned, but the route has no demand left today. It departs by itself
  /// when the next game day starts.
  waitingForDemand,

  /// Assigned and free to depart. A Line haul waits here for the player; a
  /// Local haul is only here for a moment before the next tick.
  readyToDispatch,
}

class VehicleActivity {
  const VehicleActivity(
    this.status, {
    this.progress = 0,
    this.trip,
    this.until,
  });

  final VehicleStatus status;

  /// 0 to 1 while [status] is [VehicleStatus.onTheRoad], otherwise 0.
  final double progress;

  /// The unsettled trip while on the road.
  final Trip? trip;

  /// When a vehicle waiting for demand departs again.
  final DateTime? until;
}

/// Works out the activity of [vehicle] at [now] from its unsettled trip (if it
/// has one) and its own timestamps. Nothing is simulated.
VehicleActivity vehicleActivity({
  required Vehicle vehicle,
  required Trip? activeTrip,
  required DateTime now,
}) {
  if (activeTrip != null) {
    return VehicleActivity(
      VehicleStatus.onTheRoad,
      progress: activeTrip.progressAt(now),
      trip: activeTrip,
    );
  }
  if (!vehicle.isAssigned) return const VehicleActivity(VehicleStatus.idle);
  final ready = vehicle.availableAt;
  if (ready != null && ready.isAfter(now)) {
    return VehicleActivity(VehicleStatus.waitingForDemand, until: ready);
  }
  return const VehicleActivity(VehicleStatus.readyToDispatch);
}
