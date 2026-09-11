import 'package:flutter_test/flutter_test.dart';

import 'package:family_app/models/announcement.dart';
import 'package:family_app/models/calendar_event.dart';
import 'package:family_app/models/errand_item.dart';
import 'package:family_app/models/job_assignment.dart';
import 'package:family_app/models/job_template.dart';
import 'package:family_app/models/profile.dart';
import 'package:family_app/services/notification_plan.dart';

void main() {
  final now = DateTime(2026, 9, 9, 8, 0);
  const names = {'bunda': 'Bunda', 'aku': 'Mas', 'adek': 'Adek'};

  ErrandItem errand(String id, String by, String name) => ErrandItem(
        id: id,
        name: name,
        requestedByProfileId: by,
        createdAt: now,
      );

  List<PlannedNotification> plan({
    List<ErrandItem> errands = const [],
    List<Announcement> announcements = const [],
    List<CalendarEvent> cancelled = const [],
    List<Arrival> arrivals = const [],
    List<JobAssignment> chores = const [],
    List<JobTemplate> templates = const [],
    bool choreDue = false,
  }) {
    return planNotifications(
      myProfileId: 'aku',
      names: names,
      newErrands: errands,
      newAnnouncements: announcements,
      newlyCancelled: cancelled,
      arrivals: arrivals,
      myChoresThisWeek: chores,
      templates: templates,
      choreDue: choreDue,
    );
  }

  test('titipan orang lain diberitahukan dengan nama penitipnya', () {
    final result = plan(errands: [errand('i1', 'bunda', 'Susu UHT')]);
    expect(result, hasLength(1));
    expect(result.first.body, 'Bunda nitip: Susu UHT');
  });

  test('tindakan sendiri tidak pernah diberitahukan', () {
    final result = plan(
      errands: [errand('i1', 'aku', 'Susu UHT')],
      announcements: [
        Announcement(
          id: 'n1',
          authorProfileId: 'aku',
          message: 'Token habis',
          createdAt: now,
        ),
      ],
      cancelled: [
        CalendarEvent(
          id: 'e1',
          ownerProfileId: 'bunda',
          date: now,
          title: 'Arisan',
          createdAt: now,
          cancelled: true,
          cancelledAt: now,
          cancelledByProfileId: 'aku',
        ),
      ],
      arrivals: const [Arrival(profileId: 'aku', status: PresenceStatus.home)],
    );
    expect(result, isEmpty);
  });

  test('lebih dari dua titipan diringkas jadi satu', () {
    final result = plan(errands: [
      errand('i1', 'bunda', 'Susu'),
      errand('i2', 'adek', 'Beras'),
      errand('i3', 'bunda', 'Sabun'),
    ]);
    expect(result, hasLength(1));
    expect(result.first.body, '3 titipan baru di daftar belanja');
  });

  test('kedatangan anggota lain diberitahukan', () {
    final result = plan(
      arrivals: const [Arrival(profileId: 'bunda', status: PresenceStatus.office)],
    );
    expect(result, hasLength(1));
    expect(result.first.title, 'Bunda');
    expect(result.first.body, 'Sudah sampai di kantor');
  });

  test('pengingat piket hanya menyebut giliran sendiri', () {
    final weekStart = JobAssignment.weekStartFor(now);
    final result = plan(
      choreDue: true,
      chores: [
        JobAssignment(
            id: 'a1',
            jobTemplateId: 'j1',
            assignedProfileId: 'aku',
            weekStart: weekStart),
        JobAssignment(
            id: 'a2',
            jobTemplateId: 'j2',
            assignedProfileId: 'bunda',
            weekStart: weekStart),
      ],
      templates: const [
        JobTemplate(id: 'j1', name: 'Pel rumah'),
        JobTemplate(id: 'j2', name: 'Sapu rumah'),
      ],
    );
    expect(result, hasLength(1));
    expect(result.first.body, 'Minggu ini giliranmu pel rumah.');
  });

  test('pengingat piket tidak muncul kalau tidak ada giliran', () {
    expect(plan(choreDue: true), isEmpty);
  });

  group('deteksi kedatangan', () {
    Profile at(String id, PresenceStatus status,
            {StatusSource source = StatusSource.auto}) =>
        Profile(
          id: id,
          name: names[id]!,
          isAdmin: false,
          status: status,
          statusSource: source,
        );

    test('perpindahan ke tempat dihitung sebagai kedatangan', () {
      final arrivals = arrivalsBetween(
        previousStatuses: {'bunda': 'travelling'},
        current: [at('bunda', PresenceStatus.home)],
      );
      expect(arrivals, hasLength(1));
      expect(arrivals.first.status, PresenceStatus.home);
    });

    test('keberangkatan tidak dihitung', () {
      final arrivals = arrivalsBetween(
        previousStatuses: {'bunda': 'home'},
        current: [at('bunda', PresenceStatus.travelling)],
      );
      expect(arrivals, isEmpty);
    });

    test('status yang diisi manual tidak dihitung sebagai kedatangan', () {
      final arrivals = arrivalsBetween(
        previousStatuses: {'bunda': 'travelling'},
        current: [at('bunda', PresenceStatus.home, source: StatusSource.manual)],
      );
      expect(arrivals, isEmpty);
    });

    test('pemeriksaan pertama tidak membanjiri notifikasi', () {
      // Tanpa data pembanding, semua orang akan terlihat "baru sampai".
      final arrivals = arrivalsBetween(
        previousStatuses: const {},
        current: [
          at('bunda', PresenceStatus.home),
          at('adek', PresenceStatus.campus),
        ],
      );
      expect(arrivals, isEmpty);
    });
  });
}
