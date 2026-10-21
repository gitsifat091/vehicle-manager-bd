import 'package:vehicle_manager_bd/data/models/models.dart';

final t0 = DateTime.utc(2026, 1, 1, 10);

Trip sampleTrip({String id = 't1', DateTime? arriveAt, bool settled = false}) {
  return Trip(
    id: id,
    vehicleId: 'v1',
    routeId: 'R05',
    cargo: 'General dry',
    loadT: 10,
    departAt: t0,
    arriveAt: arriveAt ?? t0.add(const Duration(minutes: 9)),
    revenue: 36375,
    costs: const TripCosts(
      energy: 7500,
      toll: 800,
      crew: 1480,
      maintenance: 1000,
      fines: 0,
      accident: 1600,
    ),
    settled: settled,
  );
}
