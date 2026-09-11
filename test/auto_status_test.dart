import 'package:flutter_test/flutter_test.dart';

import 'package:family_app/models/family_place.dart';
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

  group('readPlaces', () {
    // ~0.001 degree of latitude is ~111 m.
    final home = FamilyPlace(
      latitude: -6.2000,
      longitude: 106.8000,
      radiusMeters: 120,
      setAt: DateTime(2026, 9, 1),
    );
    final office = FamilyPlace(
      latitude: -6.2500,
      longitude: 106.8000,
      radiusMeters: 120,
      setAt: DateTime(2026, 9, 1),
    );
    final places = {PresenceStatus.home: home, PresenceStatus.office: office};

    test('inside a place reads as arriving there', () {
      final r = readPlaces(
        places: places,
        latitude: -6.2003,
        longitude: 106.8000,
        accuracyMeters: 15,
        currentStatus: PresenceStatus.other,
      );
      expect(r?.place, PresenceStatus.home);
      expect(r?.edge, GeofenceEdge.entered);
    });

    test('far from the claimed place reads as leaving it', () {
      final r = readPlaces(
        places: places,
        latitude: -6.2250,
        longitude: 106.8000,
        accuracyMeters: 15,
        currentStatus: PresenceStatus.home,
      );
      expect(r?.place, PresenceStatus.home);
      expect(r?.edge, GeofenceEdge.exited);
    });

    test('just outside, within the fix error, says nothing', () {
      // ~140 m from home: outside 120 m, but not beyond 120 m + 40 m error.
      final r = readPlaces(
        places: places,
        latitude: -6.20126,
        longitude: 106.8000,
        accuracyMeters: 40,
        currentStatus: PresenceStatus.home,
      );
      expect(r, isNull);
    });

    test('outside everything with an unrelated status says nothing', () {
      final r = readPlaces(
        places: places,
        latitude: -6.2250,
        longitude: 106.8000,
        accuracyMeters: 15,
        currentStatus: PresenceStatus.sleeping,
      );
      expect(r, isNull);
    });

    test('a vague fix is ignored entirely', () {
      final r = readPlaces(
        places: places,
        latitude: -6.2000,
        longitude: 106.8000,
        accuracyMeters: 250,
        currentStatus: PresenceStatus.other,
      );
      expect(r, isNull);
    });
  });
}
