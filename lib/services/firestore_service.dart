import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/announcement.dart';
import '../models/calendar_event.dart';
import '../models/errand_item.dart';
import '../models/job_assignment.dart';
import '../models/job_template.dart';
import '../models/profile.dart';

/// Single place that talks to Firestore. Screens read through the
/// stream getters and write through the mutation methods below rather
/// than touching `FirebaseFirestore` directly.
class FirestoreService {
  /// Swappable so screens can be rendered against canned data without a
  /// live Firebase connection.
  static FirestoreService instance = FirestoreService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _profiles => _db.collection('profiles');
  CollectionReference<Map<String, dynamic>> get _events => _db.collection('calendar_events');
  CollectionReference<Map<String, dynamic>> get _jobTemplates => _db.collection('job_templates');
  CollectionReference<Map<String, dynamic>> get _jobAssignments => _db.collection('job_assignments');
  CollectionReference<Map<String, dynamic>> get _announcements => _db.collection('announcements');
  CollectionReference<Map<String, dynamic>> get _errandItems => _db.collection('errand_items');

  // ---- Profiles ----

  Stream<List<Profile>> watchProfiles() {
    return _profiles.orderBy(FieldPath.documentId).snapshots().map(
        (snap) => snap.docs.map(Profile.fromDoc).toList());
  }

  Future<void> updateStatus(
    String profileId,
    PresenceStatus status, {
    String? note,
    StatusSource source = StatusSource.manual,
    String? placeName,
    String? placeIcon,
  }) {
    // Always written, null included: a merge would otherwise leave an old
    // place name behind under a status that no longer names a place.
    return _profiles.doc(profileId).set({
      'status': status.name,
      'statusNote': note,
      'statusUpdatedAt': Timestamp.now(),
      'statusSource': source.name,
      'statusPlace': placeName,
      'statusIcon': placeIcon,
    }, SetOptions(merge: true));
  }

  /// One-shot read, for the geofence and polling isolates where a live stream
  /// would be the wrong shape.
  Future<Profile?> getProfile(String profileId) async {
    final snap = await _profiles.doc(profileId).get();
    if (!snap.exists) return null;
    return Profile.fromDoc(snap);
  }

  Future<void> setLocationSharing(String profileId, bool enabled) {
    return _profiles.doc(profileId).set({
      'locationSharingEnabled': enabled,
    }, SetOptions(merge: true));
  }

  Future<void> updateLocation(String profileId, double lat, double lng) {
    return _profiles.doc(profileId).set({
      'lastLatitude': lat,
      'lastLongitude': lng,
      'lastLocationAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  /// Creates the three fixed family profiles if they don't exist yet.
  /// Safe to call every app start.
  Future<void> ensureSeedProfiles(Map<String, String> idToName, String adminId) async {
    for (final entry in idToName.entries) {
      final doc = _profiles.doc(entry.key);
      final snap = await doc.get();
      if (!snap.exists) {
        await doc.set({
          'name': entry.value,
          'isAdmin': entry.key == adminId,
          'status': PresenceStatus.other.name,
          'locationSharingEnabled': false,
        });
      }
    }
  }

  // ---- Calendar events ----

  Stream<List<CalendarEvent>> watchEventsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _events
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map(CalendarEvent.fromDoc).toList());
  }

  Stream<List<CalendarEvent>> watchAllUpcomingEvents() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return _events
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map(CalendarEvent.fromDoc).toList());
  }

  Future<void> addEvent(CalendarEvent event) {
    return _events.add(event.toMap());
  }

  /// Only the admin should be allowed to call this for events they don't own.
  Future<void> cancelEvent(String eventId, String cancelledByProfileId) {
    return _events.doc(eventId).update({
      'cancelled': true,
      'cancelledAt': Timestamp.now(),
      'cancelledByProfileId': cancelledByProfileId,
    });
  }

  Future<void> deleteEvent(String eventId) {
    return _events.doc(eventId).delete();
  }

  // ---- Job templates & rolling assignments ----

  Stream<List<JobTemplate>> watchJobTemplates() {
    return _jobTemplates
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(JobTemplate.fromDoc).toList());
  }

  Future<void> addJobTemplate(JobTemplate template) {
    return _jobTemplates.add(template.toMap());
  }

  Future<void> updateJobTemplate(JobTemplate template) {
    return _jobTemplates.doc(template.id).set(template.toMap());
  }

  Future<void> deleteJobTemplate(String templateId) {
    return _jobTemplates.doc(templateId).delete();
  }

  Stream<List<JobAssignment>> watchAssignmentsForWeek(DateTime weekStart) {
    return _jobAssignments
        .where('weekStart', isEqualTo: Timestamp.fromDate(weekStart))
        .snapshots()
        .map((snap) => snap.docs.map(JobAssignment.fromDoc).toList());
  }

  /// Admin-only: assign (or reassign) who does a job for a given week.
  /// Uses a deterministic doc id so re-assigning overwrites cleanly.
  Future<void> setAssignment(JobAssignment assignment) {
    final docId = '${assignment.jobTemplateId}_${assignment.weekStart.millisecondsSinceEpoch}';
    return _jobAssignments.doc(docId).set(assignment.toMap());
  }

  // ---- Announcements ----

  Stream<List<Announcement>> watchAnnouncements() {
    return _announcements
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Announcement.fromDoc).toList());
  }

  Future<void> addAnnouncement(Announcement announcement) {
    return _announcements.add(announcement.toMap());
  }

  Future<void> deleteAnnouncement(String announcementId) {
    return _announcements.doc(announcementId).delete();
  }

  // ---- Shared shopping list ----

  Stream<List<ErrandItem>> watchErrandItems() {
    return _errandItems
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ErrandItem.fromDoc).toList());
  }

  Future<void> addErrandItem(ErrandItem item) {
    return _errandItems.add(item.toMap());
  }

  Future<void> setErrandDone(String itemId, bool done, String? doneByProfileId) {
    return _errandItems.doc(itemId).update({
      'done': done,
      'doneByProfileId': done ? doneByProfileId : null,
      'doneAt': done ? Timestamp.now() : null,
    });
  }

  Future<void> deleteErrandItem(String itemId) {
    return _errandItems.doc(itemId).delete();
  }

  // ---- One-shot reads for the background check ----
  //
  // The periodic poll runs in its own isolate where a live listener would be
  // the wrong shape: it wakes, asks what changed since last time, and dies.

  Future<List<ErrandItem>> errandsCreatedAfter(DateTime after) async {
    final snap = await _errandItems
        .where('createdAt', isGreaterThan: Timestamp.fromDate(after))
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return snap.docs.map(ErrandItem.fromDoc).toList();
  }

  Future<List<Announcement>> announcementsCreatedAfter(DateTime after) async {
    final snap = await _announcements
        .where('createdAt', isGreaterThan: Timestamp.fromDate(after))
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return snap.docs.map(Announcement.fromDoc).toList();
  }

  Future<List<CalendarEvent>> eventsCancelledAfter(DateTime after) async {
    final snap = await _events
        .where('cancelledAt', isGreaterThan: Timestamp.fromDate(after))
        .orderBy('cancelledAt', descending: true)
        .limit(20)
        .get();
    return snap.docs.map(CalendarEvent.fromDoc).toList();
  }

  Future<List<Profile>> profilesOnce() async {
    final snap = await _profiles.orderBy(FieldPath.documentId).get();
    return snap.docs.map(Profile.fromDoc).toList();
  }

  Future<List<JobAssignment>> assignmentsForWeekOnce(DateTime weekStart) async {
    final snap = await _jobAssignments
        .where('weekStart', isEqualTo: Timestamp.fromDate(weekStart))
        .get();
    return snap.docs.map(JobAssignment.fromDoc).toList();
  }

  Future<List<JobTemplate>> jobTemplatesOnce() async {
    final snap = await _jobTemplates.orderBy('order').get();
    return snap.docs.map(JobTemplate.fromDoc).toList();
  }
}
