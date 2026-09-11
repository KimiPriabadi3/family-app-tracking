import 'dart:async';

import '../models/announcement.dart';
import '../models/calendar_event.dart';
import '../models/errand_item.dart';
import '../models/job_assignment.dart';
import '../models/job_template.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';

/// Backs the public web demo with invented household data held in memory.
///
/// The demo must never touch the family's real Firestore: the config would be
/// readable by anyone opening the page, and with no authentication that means
/// anyone could read their calendar and location. So the demo swaps the whole
/// data layer instead of pointing it somewhere else.
///
/// Writes work and are visible immediately, but they live only in this tab and
/// are gone on reload.
class DemoFirestore extends FirestoreService {
  DemoFirestore() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _profiles = [
      Profile(
        id: 'bunda',
        name: 'Bunda',
        isAdmin: false,
        status: PresenceStatus.home,
        statusNote: 'Masak dulu, nanti ke pasar',
        statusUpdatedAt: now.subtract(const Duration(minutes: 8)),
        locationSharingEnabled: true,
        lastLatitude: -6.2349,
        lastLongitude: 106.9896,
        lastLocationAt: now.subtract(const Duration(minutes: 6)),
      ),
      Profile(
        id: 'aku',
        name: 'Mas',
        isAdmin: true,
        status: PresenceStatus.place,
        statusPlace: 'Kampus',
        statusIcon: 'campus',
        statusSource: StatusSource.auto,
        statusUpdatedAt: now.subtract(const Duration(hours: 3)),
      ),
      Profile(
        id: 'adek',
        name: 'Adek',
        isAdmin: false,
        status: PresenceStatus.place,
        statusPlace: 'Bimbel Primagama',
        statusIcon: 'study',
        statusUpdatedAt: now.subtract(const Duration(hours: 20)),
      ),
    ];

    _events = [
      CalendarEvent(
        id: 'e1',
        ownerProfileId: 'bunda',
        date: today,
        title: 'Arisan RT',
        note: 'Di rumah Bu Tuti, jam 4 sore',
        createdAt: now,
      ),
      CalendarEvent(
        id: 'e2',
        ownerProfileId: 'aku',
        date: today,
        title: 'Rapat kantor',
        cancelled: true,
        createdAt: now,
      ),
      CalendarEvent(
        id: 'e3',
        ownerProfileId: 'adek',
        date: today,
        title: 'Les matematika',
        createdAt: now,
      ),
      CalendarEvent(
        id: 'e4',
        ownerProfileId: 'aku',
        date: today.add(const Duration(days: 2)),
        title: 'Sidang skripsi',
        createdAt: now,
      ),
    ];

    _announcements = [
      Announcement(
        id: 'n1',
        authorProfileId: 'bunda',
        message: 'Ada tamu sore ini, tolong rumah dirapikan dulu ya',
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      Announcement(
        id: 'n2',
        authorProfileId: 'adek',
        message: 'Token listrik habis',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    ];

    _errands = [
      ErrandItem(
        id: 'i1',
        name: 'Susu UHT 1 liter',
        requestedByProfileId: 'bunda',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      ErrandItem(
        id: 'i2',
        name: 'Beras 5 kg',
        requestedByProfileId: 'adek',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      ErrandItem(
        id: 'i3',
        name: 'Sabun cuci piring',
        requestedByProfileId: 'aku',
        done: true,
        doneByProfileId: 'bunda',
        createdAt: now.subtract(const Duration(days: 1)),
        doneAt: now.subtract(const Duration(hours: 6)),
      ),
    ];

    final weekStart = JobAssignment.weekStartFor(now);
    _assignments = [
      JobAssignment(
          id: 'a1',
          jobTemplateId: 'j1',
          assignedProfileId: 'bunda',
          weekStart: weekStart),
      JobAssignment(
          id: 'a2',
          jobTemplateId: 'j2',
          assignedProfileId: 'aku',
          weekStart: weekStart),
      JobAssignment(
          id: 'a3',
          jobTemplateId: 'j3',
          assignedProfileId: 'adek',
          weekStart: weekStart),
    ];
  }

  late List<Profile> _profiles;
  late List<CalendarEvent> _events;
  late List<Announcement> _announcements;
  late List<ErrandItem> _errands;
  late List<JobAssignment> _assignments;

  List<JobTemplate> _jobs = const [
    JobTemplate(id: 'j1', name: 'Sapu rumah', order: 0),
    JobTemplate(id: 'j2', name: 'Pel rumah', order: 1),
    JobTemplate(id: 'j3', name: 'Cuci piring', order: 2),
    JobTemplate(id: 'j4', name: 'Buang sampah', order: 3),
  ];

  final _profileStream = StreamController<List<Profile>>.broadcast();
  final _eventStream = StreamController<List<CalendarEvent>>.broadcast();
  final _announcementStream = StreamController<List<Announcement>>.broadcast();
  final _errandStream = StreamController<List<ErrandItem>>.broadcast();
  final _jobStream = StreamController<List<JobTemplate>>.broadcast();
  final _assignmentStream = StreamController<List<JobAssignment>>.broadcast();

  int _nextId = 100;
  String _newId() => 'demo${_nextId++}';

  Stream<T> _seeded<T>(StreamController<T> controller, T current) async* {
    yield current;
    yield* controller.stream;
  }

  // ---- Profiles ----

  @override
  Stream<List<Profile>> watchProfiles() => _seeded(_profileStream, _profiles);

  @override
  Future<void> updateStatus(
    String profileId,
    PresenceStatus status, {
    String? note,
    StatusSource source = StatusSource.manual,
    String? placeName,
    String? placeIcon,
  }) async {
    _profiles = [
      for (final p in _profiles)
        if (p.id == profileId)
          p.copyWith(
            status: status,
            statusNote: note,
            clearStatusNote: note == null,
            statusUpdatedAt: DateTime.now(),
            statusSource: source,
            statusPlace: placeName,
            statusIcon: placeIcon,
            clearStatusPlace: placeName == null,
          )
        else
          p,
    ];
    _profileStream.add(_profiles);
  }

  @override
  Future<Profile?> getProfile(String profileId) async {
    for (final p in _profiles) {
      if (p.id == profileId) return p;
    }
    return null;
  }

  @override
  Future<void> setLocationSharing(String profileId, bool enabled) async {
    _profiles = [
      for (final p in _profiles)
        if (p.id == profileId)
          p.copyWith(
            lastLatitude: p.lastLatitude ?? -6.2349,
            lastLongitude: p.lastLongitude ?? 106.9896,
            lastLocationAt: DateTime.now(),
            locationSharingEnabled: enabled,
          )
        else
          p,
    ];
    _profileStream.add(_profiles);
  }

  @override
  Future<void> updateLocation(String profileId, double lat, double lng) async {}

  @override
  Future<void> ensureSeedProfiles(
      Map<String, String> idToName, String adminId) async {}

  // ---- Calendar ----

  @override
  Stream<List<CalendarEvent>> watchEventsForDay(DateTime day) {
    List<CalendarEvent> forDay(List<CalendarEvent> all) => all
        .where((e) =>
            e.date.year == day.year &&
            e.date.month == day.month &&
            e.date.day == day.day)
        .toList();
    return _seeded(_eventStream, _events).map(forDay);
  }

  @override
  Stream<List<CalendarEvent>> watchAllUpcomingEvents() =>
      _seeded(_eventStream, _events);

  @override
  Future<void> addEvent(CalendarEvent event) async {
    _events = [
      ..._events,
      CalendarEvent(
        id: _newId(),
        ownerProfileId: event.ownerProfileId,
        date: event.date,
        title: event.title,
        note: event.note,
        createdAt: event.createdAt,
      ),
    ];
    _eventStream.add(_events);
  }

  @override
  Future<void> cancelEvent(String eventId, String cancelledByProfileId) async {
    _events = [
      for (final e in _events)
        if (e.id == eventId)
          CalendarEvent(
            id: e.id,
            ownerProfileId: e.ownerProfileId,
            date: e.date,
            title: e.title,
            note: e.note,
            cancelled: true,
            createdAt: e.createdAt,
            cancelledAt: DateTime.now(),
            cancelledByProfileId: cancelledByProfileId,
          )
        else
          e,
    ];
    _eventStream.add(_events);
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events = _events.where((e) => e.id != eventId).toList();
    _eventStream.add(_events);
  }

  // ---- Jobs ----

  @override
  Stream<List<JobTemplate>> watchJobTemplates() => _seeded(_jobStream, _jobs);

  @override
  Future<void> addJobTemplate(JobTemplate template) async {
    _jobs = [
      ..._jobs,
      JobTemplate(id: _newId(), name: template.name, order: _jobs.length),
    ];
    _jobStream.add(_jobs);
  }

  @override
  Future<void> updateJobTemplate(JobTemplate template) async {}

  @override
  Future<void> deleteJobTemplate(String templateId) async {
    _jobs = _jobs.where((j) => j.id != templateId).toList();
    _jobStream.add(_jobs);
  }

  @override
  Stream<List<JobAssignment>> watchAssignmentsForWeek(DateTime weekStart) =>
      _seeded(_assignmentStream, _assignments);

  @override
  Future<void> setAssignment(JobAssignment assignment) async {
    _assignments = [
      ..._assignments.where((a) => a.jobTemplateId != assignment.jobTemplateId),
      JobAssignment(
        id: _newId(),
        jobTemplateId: assignment.jobTemplateId,
        assignedProfileId: assignment.assignedProfileId,
        weekStart: assignment.weekStart,
      ),
    ];
    _assignmentStream.add(_assignments);
  }

  // ---- Announcements ----

  @override
  Stream<List<Announcement>> watchAnnouncements() =>
      _seeded(_announcementStream, _announcements);

  @override
  Future<void> addAnnouncement(Announcement announcement) async {
    _announcements = [
      Announcement(
        id: _newId(),
        authorProfileId: announcement.authorProfileId,
        message: announcement.message,
        createdAt: announcement.createdAt,
      ),
      ..._announcements,
    ];
    _announcementStream.add(_announcements);
  }

  @override
  Future<void> deleteAnnouncement(String announcementId) async {
    _announcements =
        _announcements.where((a) => a.id != announcementId).toList();
    _announcementStream.add(_announcements);
  }

  // ---- Errands ----

  @override
  Stream<List<ErrandItem>> watchErrandItems() =>
      _seeded(_errandStream, _errands);

  @override
  Future<void> addErrandItem(ErrandItem item) async {
    _errands = [
      ErrandItem(
        id: _newId(),
        name: item.name,
        requestedByProfileId: item.requestedByProfileId,
        createdAt: item.createdAt,
      ),
      ..._errands,
    ];
    _errandStream.add(_errands);
  }

  @override
  Future<void> setErrandDone(
      String itemId, bool done, String? doneByProfileId) async {
    _errands = [
      for (final e in _errands)
        if (e.id == itemId)
          ErrandItem(
            id: e.id,
            name: e.name,
            requestedByProfileId: e.requestedByProfileId,
            done: done,
            doneByProfileId: done ? doneByProfileId : null,
            createdAt: e.createdAt,
            doneAt: done ? DateTime.now() : null,
          )
        else
          e,
    ];
    _errandStream.add(_errands);
  }

  @override
  Future<void> deleteErrandItem(String itemId) async {
    _errands = _errands.where((e) => e.id != itemId).toList();
    _errandStream.add(_errands);
  }
}
