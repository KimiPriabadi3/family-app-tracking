import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/family_place.dart';
import '../models/profile.dart';

/// Where each member's marked places live — on their own phone, never in
/// Firestore.
///
/// Only this phone needs to know where its owner's office is; the rest of the
/// family only needs the resulting status. Keeping coordinates off the shared
/// database means a leaked Firebase config still exposes nothing about where
/// anyone lives, works, or goes to school.
class PlaceStore {
  static const _placesKey = 'places_json';
  static const _autoKey = 'auto_status_enabled';

  static Future<SharedPreferences> get _prefs async {
    final prefs = await SharedPreferences.getInstance();
    // The geofence callback runs in its own isolate and writes these keys, so
    // a long-lived foreground instance would otherwise read a stale cache.
    await prefs.reload();
    return prefs;
  }

  static Future<Map<PresenceStatus, FamilyPlace>> places() async {
    final raw = (await _prefs).getString(_placesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <PresenceStatus, FamilyPlace>{};
      for (final entry in decoded.entries) {
        final status = PresenceStatusX.fromName(entry.key);
        if (!kPlaceableStatuses.contains(status)) continue;
        result[status] =
            FamilyPlace.fromJson(entry.value as Map<String, dynamic>);
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<FamilyPlace?> placeFor(PresenceStatus status) async =>
      (await places())[status];

  static Future<void> setPlace(PresenceStatus status, FamilyPlace place) async {
    final current = await places();
    current[status] = place;
    await _write(current);
  }

  static Future<void> removePlace(PresenceStatus status) async {
    final current = await places();
    current.remove(status);
    await _write(current);
  }

  static Future<void> _write(Map<PresenceStatus, FamilyPlace> places) async {
    final encoded = jsonEncode({
      for (final entry in places.entries) entry.key.name: entry.value.toJson(),
    });
    await (await _prefs).setString(_placesKey, encoded);
  }

  static Future<bool> autoStatusEnabled() async =>
      (await _prefs).getBool(_autoKey) ?? false;

  static Future<void> setAutoStatusEnabled(bool enabled) async =>
      (await _prefs).setBool(_autoKey, enabled);

  /// Switching profiles on a shared phone must not leave the previous member's
  /// places behind.
  static Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_placesKey);
    await prefs.remove(_autoKey);
  }
}
