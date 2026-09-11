import '../models/announcement.dart';
import '../models/calendar_event.dart';
import '../models/errand_item.dart';
import '../models/job_assignment.dart';
import '../models/job_template.dart';
import '../models/profile.dart';

enum NotifKind { errand, announcement, cancelledEvent, chore, arrival }

class PlannedNotification {
  final NotifKind kind;
  final int id;
  final String title;
  final String body;

  /// Which tab to open when tapped.
  final String payload;

  const PlannedNotification({
    required this.kind,
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });
}

/// Decides what deserves to interrupt someone, given what changed since the
/// last check.
///
/// Pure on purpose — no Firestore, no plugins, no clock of its own — so the
/// rules below are testable and stay honest. Note what this function cannot
/// see: manual status edits, location updates, and shopping items being ticked
/// off are not parameters at all. That is the strongest form of "never notify
/// about this", and it is deliberate: a family that gets pinged for everything
/// mutes the app, and then the messages that mattered are lost too.
List<PlannedNotification> planNotifications({
  required String myProfileId,
  required Map<String, String> names,
  required List<ErrandItem> newErrands,
  required List<Announcement> newAnnouncements,
  required List<CalendarEvent> newlyCancelled,
  required List<Arrival> arrivals,
  required List<JobAssignment> myChoresThisWeek,
  required List<JobTemplate> templates,
  required bool choreDue,
}) {
  final plans = <PlannedNotification>[];
  String nameOf(String? id) => id == null ? '-' : (names[id] ?? id);
  int idFor(String key) => key.hashCode & 0x7fffffff;

  // --- Shopping list ---
  final errands =
      newErrands.where((e) => e.requestedByProfileId != myProfileId).toList();
  if (errands.length > 2) {
    plans.add(PlannedNotification(
      kind: NotifKind.errand,
      id: 1001,
      title: 'Titip beli',
      body: '${errands.length} titipan baru di daftar belanja',
      payload: 'errands',
    ));
  } else {
    for (final e in errands) {
      plans.add(PlannedNotification(
        kind: NotifKind.errand,
        id: idFor(e.id),
        title: 'Titip beli',
        body: '${nameOf(e.requestedByProfileId)} nitip: ${e.name}',
        payload: 'errands',
      ));
    }
  }

  // --- Announcements ---
  final notices = newAnnouncements
      .where((a) => a.authorProfileId != myProfileId)
      .toList();
  if (notices.length > 2) {
    plans.add(PlannedNotification(
      kind: NotifKind.announcement,
      id: 1002,
      title: 'Pengumuman',
      body: '${notices.length} pengumuman baru',
      payload: 'announcements',
    ));
  } else {
    for (final a in notices) {
      final message =
          a.message.length > 120 ? '${a.message.substring(0, 117)}...' : a.message;
      plans.add(PlannedNotification(
        kind: NotifKind.announcement,
        id: idFor(a.id),
        title: 'Pengumuman dari ${nameOf(a.authorProfileId)}',
        body: message,
        payload: 'announcements',
      ));
    }
  }

  // --- Cancelled plans ---
  for (final e
      in newlyCancelled.where((e) => e.cancelledByProfileId != myProfileId)) {
    plans.add(PlannedNotification(
      kind: NotifKind.cancelledEvent,
      id: idFor('cancel_${e.id}'),
      title: 'Jadwal dibatalkan',
      body: '${e.title} dibatalkan ${nameOf(e.cancelledByProfileId)}',
      payload: 'calendar',
    ));
  }

  // --- Someone arrived somewhere ---
  for (final a in arrivals.where((a) => a.profileId != myProfileId)) {
    plans.add(PlannedNotification(
      kind: NotifKind.arrival,
      id: idFor('arrive_${a.profileId}_${a.where}'),
      title: nameOf(a.profileId),
      body: 'Sudah sampai di ${a.where}',
      payload: 'status',
    ));
  }

  // --- Monday chore reminder ---
  if (choreDue) {
    final myJobIds =
        myChoresThisWeek.where((a) => a.assignedProfileId == myProfileId);
    final jobNames = <String>[];
    for (final assignment in myJobIds) {
      for (final t in templates) {
        if (t.id == assignment.jobTemplateId) jobNames.add(t.name.toLowerCase());
      }
    }
    if (jobNames.isNotEmpty) {
      plans.add(PlannedNotification(
        kind: NotifKind.chore,
        id: 1004,
        title: 'Piket minggu ini',
        body: 'Minggu ini giliranmu ${jobNames.join(' dan ')}.',
        payload: 'jobs',
      ));
    }
  }

  return plans;
}

/// A member turning up somewhere, worked out by comparing their status between
/// two checks. Only arrivals count — departures were deliberately left out, so
/// the family gets "sudah sampai rumah" without also getting every time
/// somebody walks out of a door.
class Arrival {
  final String profileId;

  /// The place as it reads after "Sudah sampai di": "kantor", or a member's
  /// own name for it, "Bimbel Primagama".
  final String where;

  const Arrival({required this.profileId, required this.where});
}

/// Arrival means: their status is now a real place, and it was something else
/// last time we looked.
List<Arrival> arrivalsBetween({
  required Map<String, String> previousStatuses,
  required List<Profile> current,
}) {
  final arrivals = <Arrival>[];
  for (final p in current) {
    if (!p.status.isSomewhere) continue;
    if (p.statusSource != StatusSource.auto) continue;
    // By key, not by status: from one named place to another is an arrival.
    if (previousStatuses[p.id] == p.statusKey) continue;
    if (!previousStatuses.containsKey(p.id)) continue; // first run: no baseline
    final where = p.status == PresenceStatus.place
        ? (p.statusPlace ?? '')
        : p.status.label.replaceFirst('Di ', '').toLowerCase();
    if (where.isEmpty) continue;
    arrivals.add(Arrival(profileId: p.id, where: where));
  }
  return arrivals;
}
