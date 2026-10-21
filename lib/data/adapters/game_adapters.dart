import 'package:hive_ce/hive_ce.dart';

import '../models/models.dart';
import 'field_codec.dart';

export 'field_codec.dart' show HiveTypeIds;

/// Registers every adapter. Safe to call more than once: an id that is
/// already registered is left alone.
void registerGameAdapters(HiveInterface hive) {
  void register<T>(TypeAdapter<T> adapter) {
    if (!hive.isAdapterRegistered(adapter.typeId)) {
      hive.registerAdapter(adapter);
    }
  }

  register(CompanyAdapter());
  register(VehicleAdapter());
  register(TerminalAdapter());
  register(RouteStateAdapter());
  register(TripAdapter());
  register(TripCostsAdapter());
}

class CompanyAdapter extends TypeAdapter<Company> {
  @override
  final int typeId = HiveTypeIds.company;

  @override
  Company read(BinaryReader reader) {
    final f = readFields(reader);
    return Company(
      name: f[0] as String,
      cash: f[1] as int,
      createdAt: decodeInstant(f[2]),
      completedTrips: (f[3] as int?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Company obj) {
    writeFields(writer, {
      0: obj.name,
      1: obj.cash,
      2: encodeInstant(obj.createdAt),
      3: obj.completedTrips,
    });
  }
}

class VehicleAdapter extends TypeAdapter<Vehicle> {
  @override
  final int typeId = HiveTypeIds.vehicle;

  @override
  Vehicle read(BinaryReader reader) {
    final f = readFields(reader);
    return Vehicle(
      id: f[0] as String,
      tier: f[1] as int,
      purchasedAt: decodeInstant(f[2]),
      assignedRouteId: f[3] as String?,
      assignedCargo: f[4] as String?,
      overloadT: (f[5] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Vehicle obj) {
    writeFields(writer, {
      0: obj.id,
      1: obj.tier,
      2: encodeInstant(obj.purchasedAt),
      3: obj.assignedRouteId,
      4: obj.assignedCargo,
      5: obj.overloadT,
    });
  }
}

class TerminalAdapter extends TypeAdapter<Terminal> {
  @override
  final int typeId = HiveTypeIds.terminal;

  @override
  Terminal read(BinaryReader reader) {
    final f = readFields(reader);
    return Terminal(
      id: f[0] as String,
      location: f[1] as String,
      purchasedAt: decodeInstant(f[2]),
    );
  }

  @override
  void write(BinaryWriter writer, Terminal obj) {
    writeFields(writer, {
      0: obj.id,
      1: obj.location,
      2: encodeInstant(obj.purchasedAt),
    });
  }
}

class RouteStateAdapter extends TypeAdapter<RouteState> {
  @override
  final int typeId = HiveTypeIds.routeState;

  @override
  RouteState read(BinaryReader reader) {
    final f = readFields(reader);
    return RouteState(
      routeId: f[0] as String,
      demandRemainingT: (f[1] as num).toDouble(),
      updatedAt: decodeInstant(f[2]),
    );
  }

  @override
  void write(BinaryWriter writer, RouteState obj) {
    writeFields(writer, {
      0: obj.routeId,
      1: obj.demandRemainingT,
      2: encodeInstant(obj.updatedAt),
    });
  }
}

class TripCostsAdapter extends TypeAdapter<TripCosts> {
  @override
  final int typeId = HiveTypeIds.tripCosts;

  @override
  TripCosts read(BinaryReader reader) {
    final f = readFields(reader);
    return TripCosts(
      energy: f[0] as int,
      toll: f[1] as int,
      crew: f[2] as int,
      maintenance: f[3] as int,
      fines: f[4] as int,
      accident: f[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TripCosts obj) {
    writeFields(writer, {
      0: obj.energy,
      1: obj.toll,
      2: obj.crew,
      3: obj.maintenance,
      4: obj.fines,
      5: obj.accident,
    });
  }
}

class TripAdapter extends TypeAdapter<Trip> {
  @override
  final int typeId = HiveTypeIds.trip;

  @override
  Trip read(BinaryReader reader) {
    final f = readFields(reader);
    return Trip(
      id: f[0] as String,
      vehicleId: f[1] as String,
      routeId: f[2] as String,
      cargo: f[3] as String,
      loadT: (f[4] as num).toDouble(),
      departAt: decodeInstant(f[5]),
      arriveAt: decodeInstant(f[6]),
      revenue: f[7] as int,
      costs: f[8] as TripCosts,
      settled: (f[9] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Trip obj) {
    writeFields(writer, {
      0: obj.id,
      1: obj.vehicleId,
      2: obj.routeId,
      3: obj.cargo,
      4: obj.loadT,
      5: encodeInstant(obj.departAt),
      6: encodeInstant(obj.arriveAt),
      7: obj.revenue,
      8: obj.costs,
      9: obj.settled,
    });
  }
}
