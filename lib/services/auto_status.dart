import '../models/profile.dart';

enum GeofenceEdge { entered, exited }

/// How long a hand-set status is protected from being overwritten.
const Duration kManualHold = Duration(hours: 8);

/// Works out what a geofence crossing should do to someone's status.
///
/// Pure on purpose — no Firestore, no plugins — so the rules below can be
/// tested without a device, and so the family can be told exactly how it
/// behaves. A rule nobody can predict feels like a bug.
///
/// Returns null when nothing should be written.
PresenceStatus? decideAutoStatus({
  required PresenceStatus currentStatus,
  required StatusSource currentSource,
  required DateTime? statusUpdatedAt,
  required PresenceStatus placeStatus,
  required GeofenceEdge edge,
  required DateTime now,
}) {
  final PresenceStatus candidate;

  if (edge == GeofenceEdge.entered) {
    candidate = placeStatus;
  } else {
    // A late "left the office" must not undo a newer "arrived home".
    if (currentStatus != placeStatus) return null;
    candidate = PresenceStatus.travelling;
  }

  // Writing the same value again would refresh statusUpdatedAt, making a stale
  // status look freshly confirmed. GPS noise must never do that.
  if (candidate == currentStatus) return null;

  final manualHoldActive = currentSource == StatusSource.manual &&
      statusUpdatedAt != null &&
      now.difference(statusUpdatedAt) < kManualHold;

  if (manualHoldActive) {
    // One exception: if you said "Di rumah" by hand and then physically left,
    // leaving it saying "Di rumah" is a lie — worse than overriding you.
    final leavingTheClaimedPlace =
        edge == GeofenceEdge.exited && currentStatus == placeStatus;
    if (!leavingTheClaimedPlace) return null;
  }

  return candidate;
}
