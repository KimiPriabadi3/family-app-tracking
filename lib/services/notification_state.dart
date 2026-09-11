import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/job_assignment.dart';
import '../models/profile.dart';

/// Remembers what this phone has already announced, so nothing is said twice.
///
/// Lives in SharedPreferences next to [ProfileSession]. The background poll
/// runs in its own isolate and writes these keys, so every read reloads first —
/// a long-lived foreground instance would otherwise serve a stale cache and
/// re-announce items the user has already seen.
class NotificationState {
  static const _errandKey = 'notif_seen_errand_at';
  static const _announcementKey = 'notif_seen_announcement_at';
  static const _cancelKey = 'notif_seen_cancel_at';
  static const _choreWeekKey = 'notif_chore_week_ms';
  static const _statusesKey = 'notif_last_statuses';
  static const _enabledKey = 'notif_enabled';
  static const _arrivalsKey = 'notif_arrivals_enabled';

  static Future<SharedPreferences> get _prefs async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  static Future<DateTime> seenAt(String key) async {
    final ms = (await _prefs).getInt(key);
    if (ms == null) return DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setSeenAt(String key, DateTime at) async =>
      (await _prefs).setInt(key, at.millisecondsSinceEpoch);

  static String get errandKey => _errandKey;
  static String get announcementKey => _announcementKey;
  static String get cancelKey => _cancelKey;

  static Future<bool> enabled() async =>
      (await _prefs).getBool(_enabledKey) ?? false;

  static Future<void> setEnabled(bool value) async =>
      (await _prefs).setBool(_enabledKey, value);

  static Future<bool> arrivalsEnabled() async =>
      (await _prefs).getBool(_arrivalsKey) ?? true;

  static Future<void> setArrivalsEnabled(bool value) async =>
      (await _prefs).setBool(_arrivalsKey, value);

  /// Status of every member as of the last check, used to spot arrivals.
  static Future<Map<String, String>> lastStatuses() async {
    final raw = (await _prefs).getString(_statusesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  static Future<void> setLastStatuses(List<Profile> profiles) async {
    final map = {for (final p in profiles) p.id: p.status.name};
    await (await _prefs).setString(_statusesKey, jsonEncode(map));
  }

  static Future<DateTime?> choreWeekReminded() async {
    final ms = (await _prefs).getInt(_choreWeekKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setChoreWeekReminded(DateTime weekStart) async =>
      (await _prefs).setInt(_choreWeekKey, weekStart.millisecondsSinceEpoch);

  /// True when this Monday's reminder is still owed.
  static Future<bool> choreDue(DateTime now) async {
    if (now.weekday != DateTime.monday || now.hour < 7) return false;
    final done = await choreWeekReminded();
    final thisWeek = JobAssignment.weekStartFor(now);
    return done == null || done.isBefore(thisWeek);
  }

  /// On first enable, move every watermark to now — otherwise turning
  /// notifications on would replay the entire backlog at the family at once.
  static Future<void> seedWatermarksToNow() async {
    final now = DateTime.now();
    await setSeenAt(_errandKey, now);
    await setSeenAt(_announcementKey, now);
    await setSeenAt(_cancelKey, now);
  }

  static Future<void> clear() async {
    final prefs = await _prefs;
    for (final key in [
      _errandKey,
      _announcementKey,
      _cancelKey,
      _choreWeekKey,
      _statusesKey,
      _enabledKey,
      _arrivalsKey,
    ]) {
      await prefs.remove(key);
    }
  }
}
