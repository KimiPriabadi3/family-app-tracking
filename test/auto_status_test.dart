import 'package:flutter_test/flutter_test.dart';

import 'package:family_app/models/family_place.dart';
import 'package:family_app/models/profile.dart';
import 'package:family_app/services/auto_status.dart';

void main() {
  final now = DateTime(2026, 9, 9, 12, 0);

  FamilyPlace place(String name, PlaceIcon icon,
          {double lat = -6.2000, double lng = 106.8000}) =>
      FamilyPlace(
        id: name.toLowerCase().replaceAll(' ', ''),
        name: name,
        icon: icon,
        latitude: lat,
        longitude: lng,
        radiusMeters: 120,
        setAt: DateTime(2026, 9, 1),
      );

  final rumah = place('Rumah', PlaceIcon.home);
  final bimbel = place('Bimbel Primagama', PlaceIcon.study, lat: -6.2500);

  Profile me(PresenceStatus status,
          {String? at,
          StatusSource source = StatusSource.auto,
          Duration age = const Duration(minutes: 1)}) =>
      Profile(
        id: 'adek',
        name: 'Adek',
        isAdmin: false,
        status: status,
        statusPlace: at,
        statusSource: source,
        statusUpdatedAt: now.subtract(age),
      );

  AutoStatusChange? decide(Profile current, FamilyPlace p, GeofenceEdge edge,
          {bool cameFromElsewhere = false}) =>
      decideAutoStatus(
        current: current,
        place: p,
        edge: edge,
        now: now,
        cameFromElsewhere: cameFromElsewhere,
      );

  test('tiba di tempat mengubah status jadi nama tempat itu', () {
    final change =
        decide(me(PresenceStatus.travelling), bimbel, GeofenceEdge.entered);
    expect(change?.status, PresenceStatus.place);
    expect(change?.label, 'Di Bimbel Primagama');
  });

  test('pergi dari tempat mengubah status jadi di jalan', () {
    final change = decide(
      me(PresenceStatus.place, at: 'Bimbel Primagama'),
      bimbel,
      GeofenceEdge.exited,
    );
    expect(change?.status, PresenceStatus.travelling);
  });

  test('status yang tidak berubah tidak ditulis ulang', () {
    // Menulis ulang nilai yang sama akan menyegarkan waktunya, membuat status
    // basi terlihat baru dikonfirmasi.
    expect(
      decide(me(PresenceStatus.place, at: 'Rumah'), rumah, GeofenceEdge.entered),
      isNull,
    );
  });

  test('"Di rumah" yang diisi manual sudah dianggap berada di tempat Rumah', () {
    expect(
      decide(me(PresenceStatus.home), rumah, GeofenceEdge.entered),
      isNull,
    );
  });

  test('status manual bertahan selama masih di tempat yang sama', () {
    // "Tidur" di rumah, lalu Android melaporkan ulang "kamu di rumah".
    expect(
      decide(
        me(PresenceStatus.sleeping,
            source: StatusSource.manual, age: const Duration(hours: 2)),
        rumah,
        GeofenceEdge.entered,
      ),
      isNull,
    );
  });

  test('status manual ditimpa kalau benar-benar sampai di tempat lain', () {
    // Mas sempat memilih "Lainnya" jam 12:42, lalu sampai di rumah.
    final change = decide(
      me(PresenceStatus.other,
          source: StatusSource.manual, age: const Duration(minutes: 40)),
      rumah,
      GeofenceEdge.entered,
      cameFromElsewhere: true,
    );
    expect(change?.label, 'Di Rumah');
  });

  test('status manual boleh ditimpa setelah masa tahan lewat', () {
    final change = decide(
      me(PresenceStatus.sleeping,
          source: StatusSource.manual,
          age: kManualHold + const Duration(minutes: 1)),
      rumah,
      GeofenceEdge.entered,
    );
    expect(change?.label, 'Di Rumah');
  });

  test('pergi dari tempat yang diklaim manual tetap berlaku dalam masa tahan',
      () {
    // Kalau seseorang menulis "Di rumah" lalu benar-benar pergi, membiarkannya
    // tertulis "Di rumah" itu berbohong.
    final change = decide(
      me(PresenceStatus.home,
          source: StatusSource.manual, age: const Duration(minutes: 30)),
      rumah,
      GeofenceEdge.exited,
    );
    expect(change?.status, PresenceStatus.travelling);
  });

  test('sinyal keluar yang telat tidak membatalkan kedatangan di tempat lain',
      () {
    // Sudah sampai bimbel; sinyal "keluar dari rumah" baru datang belakangan.
    expect(
      decide(
        me(PresenceStatus.place, at: 'Bimbel Primagama'),
        rumah,
        GeofenceEdge.exited,
      ),
      isNull,
    );
  });

  test('dua tempat bimbel dibedakan dari namanya', () {
    final ganesha = place('Bimbel Ganesha', PlaceIcon.study, lat: -6.3);
    final change = decide(
      me(PresenceStatus.place, at: 'Bimbel Primagama'),
      ganesha,
      GeofenceEdge.entered,
    );
    expect(change?.label, 'Di Bimbel Ganesha');
  });

  test('tidur tidak pernah dihasilkan otomatis', () {
    for (final edge in GeofenceEdge.values) {
      for (final p in [rumah, bimbel]) {
        final change = decide(me(PresenceStatus.place, at: p.name), p, edge);
        expect(change?.status, isNot(PresenceStatus.sleeping));
      }
    }
  });

  group('readPlaces', () {
    // ~0.001 degree of latitude is ~111 m.
    final kantor = place('Kantor', PlaceIcon.work, lat: -6.2500);
    final places = [rumah, kantor];

    PlaceReading? read(double lat, double accuracy, Profile current) =>
        readPlaces(
          places: places,
          latitude: lat,
          longitude: 106.8000,
          accuracyMeters: accuracy,
          current: current,
        );

    test('inside a place reads as arriving there', () {
      final r = read(-6.2003, 15, me(PresenceStatus.other));
      expect(r?.place.name, 'Rumah');
      expect(r?.edge, GeofenceEdge.entered);
    });

    test('far from the claimed place reads as leaving it', () {
      final r = read(-6.2250, 15, me(PresenceStatus.place, at: 'Rumah'));
      expect(r?.place.name, 'Rumah');
      expect(r?.edge, GeofenceEdge.exited);
    });

    test('a hand-set fixed status counts as claiming the matching place', () {
      final r = read(-6.2250, 15, me(PresenceStatus.home));
      expect(r?.edge, GeofenceEdge.exited);
    });

    test('just outside, within the fix error, says nothing', () {
      // ~140 m from home: outside 120 m, but not beyond 120 m + 40 m error.
      expect(read(-6.20126, 40, me(PresenceStatus.place, at: 'Rumah')), isNull);
    });

    test('outside everything with an unrelated status says nothing', () {
      expect(read(-6.2250, 15, me(PresenceStatus.sleeping)), isNull);
    });

    test('a vague fix is ignored entirely', () {
      expect(read(-6.2000, 250, me(PresenceStatus.other)), isNull);
    });
  });
}
