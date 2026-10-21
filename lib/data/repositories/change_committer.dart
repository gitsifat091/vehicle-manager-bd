import 'dart:async';

import '../models/models.dart';
import 'save_database.dart';

/// The steps of [ChangeCommitter.commit], in order. Each is a separate write
/// to disk, so a crash can fall between any two of them.
enum CommitStep {
  /// The whole change set is on disk as the pending record.
  pendingWritten,

  /// The company has its new absolute cash and trip count.
  companySaved,
  vehiclesSaved,
  tripsSaved,
  routeStatesSaved,

  /// The pending record is removed. The change is complete.
  pendingCleared,
}

/// Writes a [ChangeSet] to disk so that a crash at any moment can never pay a
/// trip twice or lose a payout.
///
/// 1. Write the change set as the pending record, in one put.
/// 2. Apply it: company cash, vehicles, trips, route states.
/// 3. Clear the pending record.
///
/// Every value in a change set is absolute (the new cash total, the whole
/// trip), so step 2 can be repeated safely. If the app dies after step 1,
/// [recoverPending] runs step 2 and 3 again on the next start. If it dies
/// before step 1, nothing was written and the trips are still unsettled, so
/// they are settled again from scratch.
///
/// The pending record holds the settled trips with their final, rolled costs.
/// Recovery therefore never rolls the dice again.
class ChangeCommitter {
  ChangeCommitter(this._db, {this.afterStep});

  final SaveDatabase _db;

  /// Test seam: called after each step. A test throws from it to simulate a
  /// crash at that point. Not used in the app.
  final FutureOr<void> Function(CommitStep step)? afterStep;

  /// Finishes a change that a crash interrupted. Returns true if there was
  /// one. Run it at startup before anything else touches the save.
  Future<bool> recoverPending() async {
    final pending = _db.pending.load();
    if (pending == null) return false;
    await _apply(pending);
    await _db.pending.clear();
    await afterStep?.call(CommitStep.pendingCleared);
    return true;
  }

  /// Writes [change]. Finishes any leftover pending change first.
  Future<void> commit(ChangeSet change) async {
    await recoverPending();
    await _db.pending.save(change);
    await afterStep?.call(CommitStep.pendingWritten);
    await _apply(change);
    await _db.pending.clear();
    await afterStep?.call(CommitStep.pendingCleared);
  }

  Future<void> _apply(ChangeSet change) async {
    final company = _db.company.load();
    if (company != null) {
      await _db.company.save(
        company.copyWith(
          cash: change.cashAfter,
          completedTrips: change.completedTripsAfter,
        ),
      );
    }
    await afterStep?.call(CommitStep.companySaved);
    await _db.vehicles.putAll(change.vehicles);
    await afterStep?.call(CommitStep.vehiclesSaved);
    await _db.trips.putAll(change.trips);
    await afterStep?.call(CommitStep.tripsSaved);
    await _db.routeStates.putAll(change.routeStates);
    await afterStep?.call(CommitStep.routeStatesSaved);
  }
}
