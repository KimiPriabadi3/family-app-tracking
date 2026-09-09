import 'package:flutter_test/flutter_test.dart';

import 'package:family_app/models/profile.dart';
import 'package:family_app/services/auto_status.dart';

void main() {
  final now = DateTime(2026, 9, 9, 12, 0);

  PresenceStatus? decide({
    required PresenceStatus current,
    StatusSource source = StatusSource.auto,
    Duration age = const Duration(minutes: 1),
    required PresenceStatus place,
    required GeofenceEdge edge,
  }) {
    return decideAutoStatus(
      currentStatus: current,
      currentSource: source,
      statusUpdatedAt: now.subtract(age),
      placeStatus: place,
      edge: edge,
      now: now,
    );
  }

  test('tiba di rumah mengubah status jadi di rumah', () {
    expect(
      decide(
        current: PresenceStatus.travelling,
        place: PresenceStatus.home,
        edge: GeofenceEdge.entered,
      ),
      PresenceStatus.home,
    );
  });

  test('pergi dari rumah mengubah status jadi di jalan', () {
    expect(
      decide(
        current: PresenceStatus.home,
        place: PresenceStatus.home,
        edge: GeofenceEdge.exited,
      ),
      PresenceStatus.travelling,
    );
  });

  test('status yang tidak berubah tidak ditulis ulang', () {
    // Menulis ulang nilai yang sama akan menyegarkan waktunya, membuat status
    // basi terlihat baru dikonfirmasi.
    expect(
      decide(
        current: PresenceStatus.home,
        place: PresenceStatus.home,
        edge: GeofenceEdge.entered,
      ),
      isNull,
    );
  });

  test('status manual yang masih baru tidak ditimpa oleh kedatangan', () {
    expect(
      decide(
        current: PresenceStatus.sleeping,
        source: StatusSource.manual,
        age: const Duration(hours: 2),
        place: PresenceStatus.home,
        edge: GeofenceEdge.entered,
      ),
      isNull,
    );
  });

  test('status manual boleh ditimpa setelah masa tahan lewat', () {
    expect(
      decide(
        current: PresenceStatus.sleeping,
        source: StatusSource.manual,
        age: kManualHold + const Duration(minutes: 1),
        place: PresenceStatus.home,
        edge: GeofenceEdge.entered,
      ),
      PresenceStatus.home,
    );
  });

  test('pergi dari tempat yang diklaim manual tetap berlaku dalam masa tahan',
      () {
    // Kalau seseorang menulis "Di rumah" lalu benar-benar pergi, membiarkannya
    // tertulis "Di rumah" itu berbohong.
    expect(
      decide(
        current: PresenceStatus.home,
        source: StatusSource.manual,
        age: const Duration(minutes: 30),
        place: PresenceStatus.home,
        edge: GeofenceEdge.exited,
      ),
      PresenceStatus.travelling,
    );
  });

  test('sinyal keluar yang telat tidak membatalkan kedatangan di tempat lain',
      () {
    // Sudah sampai kantor; sinyal "keluar dari rumah" baru datang belakangan.
    expect(
      decide(
        current: PresenceStatus.office,
        place: PresenceStatus.home,
        edge: GeofenceEdge.exited,
      ),
      isNull,
    );
  });

  test('tidur tidak pernah dihasilkan otomatis', () {
    for (final edge in GeofenceEdge.values) {
      for (final place in [
        PresenceStatus.home,
        PresenceStatus.campus,
        PresenceStatus.office,
      ]) {
        final result = decide(
          current: PresenceStatus.travelling,
          place: place,
          edge: edge,
        );
        expect(result, isNot(PresenceStatus.sleeping));
      }
    }
  });
}
