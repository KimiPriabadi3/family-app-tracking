import 'package:latlong2/latlong.dart';

import '../models/family_place.dart';
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

/// What one position fix says about the member's marked places.
class PlaceReading {
  final PresenceStatus place;
  final GeofenceEdge edge;

  const PlaceReading(this.place, this.edge);
}

/// A fix vaguer than this cannot tell a 120 m circle from the house next door.
const double kMaxUsableAccuracy = 100;

/// Turns a single position fix into the same kind of event a geofence
/// crossing would produce, so the app can check where someone is when it is
/// opened instead of waiting for Android to report a crossing.
///
/// Inside a place counts as arriving there (the nearest, if circles overlap).
/// Being outside only counts as leaving the place the status currently
/// claims, and only when even the far edge of the fix's error is outside it —
/// a wobbly fix must not flip someone at home to "Di jalan".
PlaceReading? readPlaces({
  required Map<PresenceStatus, FamilyPlace> places,
  required double latitude,
  required double longitude,
  required double accuracyMeters,
  required PresenceStatus currentStatus,
}) {
  if (places.isEmpty || accuracyMeters > kMaxUsableAccuracy) return null;

  const distance = Distance();
  final here = LatLng(latitude, longitude);
  double metersTo(FamilyPlace p) =>
      distance.as(LengthUnit.Meter, here, LatLng(p.latitude, p.longitude));

  PresenceStatus? nearest;
  double? nearestMeters;
  for (final entry in places.entries) {
    final meters = metersTo(entry.value);
    if (meters <= entry.value.radiusMeters &&
        (nearestMeters == null || meters < nearestMeters)) {
      nearest = entry.key;
      nearestMeters = meters;
    }
  }
  if (nearest != null) return PlaceReading(nearest, GeofenceEdge.entered);

  final claimed = places[currentStatus];
  if (claimed != null &&
      metersTo(claimed) > claimed.radiusMeters + accuracyMeters) {
    return PlaceReading(currentStatus, GeofenceEdge.exited);
  }
  return null;
}
