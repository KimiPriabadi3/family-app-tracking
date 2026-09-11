import 'package:latlong2/latlong.dart';

import '../models/family_place.dart';
import '../models/profile.dart';

enum GeofenceEdge { entered, exited }

/// How long a hand-set status is protected from being overwritten.
const Duration kManualHold = Duration(hours: 8);

/// What an automatic change should write.
class AutoStatusChange {
  final PresenceStatus status;

  /// Set when arriving: the place the status now names.
  final FamilyPlace? place;

  const AutoStatusChange.arrived(FamilyPlace this.place)
      : status = PresenceStatus.place;
  const AutoStatusChange.left()
      : status = PresenceStatus.travelling,
        place = null;

  String get label => place == null ? status.label : 'Di ${place!.name}';
}

/// Works out what a geofence crossing should do to someone's status.
///
/// Pure on purpose — no Firestore, no plugins — so the rules below can be
/// tested without a device, and so the family can be told exactly how it
/// behaves. A rule nobody can predict feels like a bug.
///
/// [cameFromElsewhere] says whether this phone last saw its owner somewhere
/// other than [place]. It is what separates arriving from merely still being
/// there when Android re-reports a place the member never left.
///
/// Returns null when nothing should be written.
AutoStatusChange? decideAutoStatus({
  required Profile current,
  required FamilyPlace place,
  required GeofenceEdge edge,
  required DateTime now,
  bool cameFromElsewhere = false,
}) {
  final claims = statusClaimsPlace(current, place);

  if (edge == GeofenceEdge.entered) {
    // Already says so: writing again would refresh statusUpdatedAt and make a
    // stale status look freshly confirmed. GPS noise must never do that.
    if (claims) return null;
  } else {
    // A late "left the office" must not undo a newer "arrived home".
    if (!claims) return null;
  }

  final manualHoldActive = current.statusSource == StatusSource.manual &&
      current.statusUpdatedAt != null &&
      now.difference(current.statusUpdatedAt!) < kManualHold;

  if (manualHoldActive) {
    // A hand-set status stands until the member actually moves — so it
    // protects "Tidur" from a re-reported "you're at home", but not from
    // really turning up somewhere else. And if you said "Di rumah" by hand and
    // then physically left, leaving it saying "Di rumah" would be a lie.
    final leavingTheClaimedPlace = edge == GeofenceEdge.exited && claims;
    final arrivingSomewhereNew =
        edge == GeofenceEdge.entered && cameFromElsewhere;
    if (!leavingTheClaimedPlace && !arrivingSomewhereNew) return null;
  }

  return edge == GeofenceEdge.entered
      ? AutoStatusChange.arrived(place)
      : const AutoStatusChange.left();
}

/// What one position fix says about the member's marked places.
class PlaceReading {
  final FamilyPlace place;
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
  required List<FamilyPlace> places,
  required double latitude,
  required double longitude,
  required double accuracyMeters,
  required Profile current,
}) {
  if (places.isEmpty || accuracyMeters > kMaxUsableAccuracy) return null;

  const distance = Distance();
  final here = LatLng(latitude, longitude);
  double metersTo(FamilyPlace p) =>
      distance.as(LengthUnit.Meter, here, LatLng(p.latitude, p.longitude));

  FamilyPlace? nearest;
  double? nearestMeters;
  for (final place in places) {
    final meters = metersTo(place);
    if (meters <= place.radiusMeters &&
        (nearestMeters == null || meters < nearestMeters)) {
      nearest = place;
      nearestMeters = meters;
    }
  }
  if (nearest != null) return PlaceReading(nearest, GeofenceEdge.entered);

  for (final place in places) {
    if (statusClaimsPlace(current, place) &&
        metersTo(place) > place.radiusMeters + accuracyMeters) {
      return PlaceReading(place, GeofenceEdge.exited);
    }
  }
  return null;
}
