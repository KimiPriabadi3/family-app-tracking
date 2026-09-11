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
/// Returns the status written, or null if nothing changed.
Future<PresenceStatus?> applyPlaceEdge({
  required String profileId,
  required PresenceStatus placeStatus,
  required GeofenceEdge edge,
  required AutoStatusOrigin origin,
  Profile? current,
}) async {
  final now = DateTime.now();
  final me = current ?? await FirestoreService.instance.getProfile(profileId);
  final where = placeNameOf(placeStatus);
  final what = edge == GeofenceEdge.entered ? 'Masuk $where' : 'Keluar dari $where';
  if (me == null) {
    await PlaceStore.recordEvent('$what (${origin.label}) — profil tidak ditemukan');
    return null;
  }

  final next = decideAutoStatus(
    currentStatus: me.status,
    currentSource: me.statusSource,
    statusUpdatedAt: me.statusUpdatedAt,
    placeStatus: placeStatus,
    edge: edge,
    now: now,
  );
  if (next == null) {
    await PlaceStore.recordEvent(
      '$what (${origin.label}) — status tetap ${me.status.label}',
      at: now,
    );
    return null;
  }

  // An automatic change clears the note: "otw pulang, telat 30 menit" is
  // wrong the moment you actually arrive.
  await FirestoreService.instance
      .updateStatus(profileId, next, note: null, source: StatusSource.auto)
      .timeout(const Duration(seconds: 10));
  await PlaceStore.recordEvent(
    '$what (${origin.label}) — status jadi ${next.label}',
    at: now,
  );
  return next;
}
