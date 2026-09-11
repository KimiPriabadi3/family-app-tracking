import '../models/family_place.dart';
import '../models/profile.dart';
import 'auto_status.dart';
import 'firestore_service.dart';
import 'place_store.dart';

/// Where an automatic change came from, recorded so the Tempatku screen can
/// show whether background crossings are arriving at all.
enum AutoStatusOrigin { background, appOpened, marked }

extension on AutoStatusOrigin {
  String get label {
    switch (this) {
      case AutoStatusOrigin.background:
        return 'dari latar belakang';
      case AutoStatusOrigin.appOpened:
        return 'saat aplikasi dibuka';
      case AutoStatusOrigin.marked:
        return 'saat menandai';
    }
  }
}

/// Applies one arrival or departure to this member's status, the same way
/// whether Android reported it or the app worked it out itself.
///
/// Returns what was written, or null if nothing changed.
Future<AutoStatusChange?> applyPlaceEdge({
  required String profileId,
  required FamilyPlace place,
  required GeofenceEdge edge,
  required AutoStatusOrigin origin,
  Profile? current,
}) async {
  final now = DateTime.now();
  final me = current ?? await FirestoreService.instance.getProfile(profileId);
  final what = edge == GeofenceEdge.entered
      ? 'Masuk ${place.name}'
      : 'Keluar dari ${place.name}';
  if (me == null) {
    await PlaceStore.recordEvent('$what (${origin.label}) — profil tidak ditemukan');
    return null;
  }

  final lastInside = await PlaceStore.lastInside();
  final change = decideAutoStatus(
    current: me,
    place: place,
    edge: edge,
    now: now,
    // Never seen anywhere yet counts as elsewhere: the first reading after
    // switching this on should be allowed to set the status.
    cameFromElsewhere: lastInside != place.id,
  );
  // Remember where the phone is, whatever the status decision — the next
  // event is judged against it.
  if (edge == GeofenceEdge.entered) {
    await PlaceStore.setLastInside(place.id);
  } else if (lastInside == place.id) {
    await PlaceStore.setLastInside('');
  }
  if (change == null) {
    await PlaceStore.recordEvent(
      '$what (${origin.label}) — status tetap ${me.statusLabel}',
      at: now,
    );
    return null;
  }

  // An automatic change clears the note: "otw pulang, telat 30 menit" is
  // wrong the moment you actually arrive.
  await FirestoreService.instance
      .updateStatus(
        profileId,
        change.status,
        note: null,
        source: StatusSource.auto,
        placeName: change.place?.name,
        placeIcon: change.place?.icon.name,
      )
      .timeout(const Duration(seconds: 10));
  await PlaceStore.recordEvent(
    '$what (${origin.label}) — status jadi ${change.label}',
    at: now,
  );
  return change;
}
