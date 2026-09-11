import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../models/job_assignment.dart';
import 'firestore_service.dart';
import 'notification_plan.dart';
import 'notification_service.dart';
import 'notification_state.dart';
import 'profile_session.dart';

const String kPollTask = 'familyPoll';
const String kPollUnique = 'family-poll-15m';

/// Entry point Android calls on its own schedule, in a fresh isolate.
@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kPollTask) return true;
    return runFamilyPoll();
  });
}

/// Checks what changed since last time and raises notifications for it.
///
/// Also callable from the foreground: the settings screen has a "Coba
/// sekarang" button, which is the only practical way to tell whether this
/// works on a particular phone without waiting a quarter of an hour.
Future<bool> runFamilyPoll() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    if (!await NotificationState.enabled()) return true;

    final profileId = await ProfileSession.getSelectedProfileId();
    if (profileId == null) return true;

    await NotificationService.instance.init();

    final firestore = FirestoreService.instance;
    final now = DateTime.now();

    final errandSeen = await NotificationState.seenAt(NotificationState.errandKey);
    final noticeSeen =
        await NotificationState.seenAt(NotificationState.announcementKey);
    final cancelSeen = await NotificationState.seenAt(NotificationState.cancelKey);

    final profiles = await firestore.profilesOnce();
    final names = {for (final p in profiles) p.id: p.name};

    final arrivals = await NotificationState.arrivalsEnabled()
        ? arrivalsBetween(
            previousStatuses: await NotificationState.lastStatuses(),
            current: profiles,
          )
        : const <Arrival>[];

    final choreDue = await NotificationState.choreDue(now);
    final weekStart = JobAssignment.weekStartFor(now);

    final plans = planNotifications(
      myProfileId: profileId,
      names: names,
      newErrands: await firestore.errandsCreatedAfter(errandSeen),
      newAnnouncements: await firestore.announcementsCreatedAfter(noticeSeen),
      newlyCancelled: await firestore.eventsCancelledAfter(cancelSeen),
      arrivals: arrivals,
      myChoresThisWeek:
          choreDue ? await firestore.assignmentsForWeekOnce(weekStart) : const [],
      templates: choreDue ? await firestore.jobTemplatesOnce() : const [],
      choreDue: choreDue,
    );

    for (final plan in plans) {
      await NotificationService.instance.show(plan);
    }

    // Watermarks only move after the notifications actually went out, so a
    // phone that dies mid-check announces the item on its next run rather than
    // silently swallowing it.
    await NotificationState.setSeenAt(NotificationState.errandKey, now);
    await NotificationState.setSeenAt(NotificationState.announcementKey, now);
    await NotificationState.setSeenAt(NotificationState.cancelKey, now);
    await NotificationState.setLastStatuses(profiles);
    if (choreDue && plans.any((p) => p.kind == NotifKind.chore)) {
      await NotificationState.setChoreWeekReminded(weekStart);
    }

    return true;
  } catch (_) {
    // Returning false asks Android to retry with backoff. A failed check is
    // never fatal: nothing has been marked seen, so the next run catches up.
    return false;
  }
}

Future<void> registerPolling() async {
  await Workmanager().registerPeriodicTask(
    kPollUnique,
    kPollTask,
    frequency: const Duration(minutes: 15),
    initialDelay: const Duration(minutes: 1),
    constraints: Constraints(networkType: NetworkType.connected),
    // `replace` would reset the 15-minute window every time the app opens, so
    // on a phone that gets opened often the check would never actually fire.
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

Future<void> cancelPolling() async {
  await Workmanager().cancelByUniqueName(kPollUnique);
}
