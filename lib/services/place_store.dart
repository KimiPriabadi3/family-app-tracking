import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/family_place.dart';
import 'profile_session.dart';

/// Where each member's marked places live — on their own phone, never in
/// Firestore.
///
/// Only this phone needs to know where its owner's tutoring centre is; the rest
/// of the family only needs the resulting status. Keeping coordinates off the
/// shared database means a leaked Firebase config still exposes nothing about
/// where anyone lives, works, or goes to school.
///
/// Everything is kept per profile: logging out and back in keeps your places,
/// and a sibling who borrows the phone never inherits them.
class PlaceStore {
  static const _placesPrefix = 'places_v2_';
  static const _autoPrefix = 'auto_status_enabled_';
  static const _lastEventPrefix = 'auto_status_last_event_';
  static const _lastInsidePrefix = 'last_inside_';

  // 1.1.x kept one unnamed set of three fixed places per phone.
  static const _legacyPlacesKey = 'places_json';
  static const _legacyAutoKey = 'auto_status_enabled';
  static const _legacyLastEventKey = 'auto_status_last_event';
  static const _legacyNames = {
    'home': ('Rumah', PlaceIcon.home),
    'campus': ('Kampus', PlaceIcon.campus),
    'office': ('Kantor', PlaceIcon.work),
  };

  static Future<SharedPreferences> get _prefs async {
    final prefs = await SharedPreferences.getInstance();
    // The geofence callback runs in its own isolate and writes these keys, so
    // a long-lived foreground instance would otherwise read a stale cache.
    await prefs.reload();
    return prefs;
  }

  /// The member these places belong to, or null when nobody is logged in.
  static Future<String?> _owner() => ProfileSession.getSelectedProfileId();

  static Future<List<FamilyPlace>> places() async {
    final owner = await _owner();
    if (owner == null) return [];
    final prefs = await _prefs;
    await _migrateLegacy(prefs, owner);
    final raw = prefs.getString('$_placesPrefix$owner');
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          FamilyPlace.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<FamilyPlace?> placeById(String id) async {
    for (final place in await places()) {
      if (place.id == id) return place;
    }
    return null;
  }

  /// Adds the place, or replaces the one with the same id.
  static Future<void> savePlace(FamilyPlace place) async {
    final current = await places();
    final index = current.indexWhere((p) => p.id == place.id);
    if (index == -1) {
      current.add(place);
    } else {
      current[index] = place;
    }
    await _write(current);
  }

  static Future<void> removePlace(String id) async {
    final current = await places()..removeWhere((p) => p.id == id);
    await _write(current);
  }

  static Future<void> _write(List<FamilyPlace> places) async {
    final owner = await _owner();
    if (owner == null) return;
    await (await _prefs).setString(
      '$_placesPrefix$owner',
      jsonEncode([for (final p in places) p.toJson()]),
    );
  }

  /// A fresh id for a new place. Never contains "_", which separates the
  /// profile from the place in geofence ids.
  static String newId() => 'p${DateTime.now().microsecondsSinceEpoch}';

  static Future<bool> autoStatusEnabled() async {
    final owner = await _owner();
    if (owner == null) return false;
    final prefs = await _prefs;
    await _migrateLegacy(prefs, owner);
    return prefs.getBool('$_autoPrefix$owner') ?? false;
  }

  static Future<void> setAutoStatusEnabled(bool enabled) async {
    final owner = await _owner();
    if (owner == null) return;
    await (await _prefs).setBool('$_autoPrefix$owner', enabled);
  }

  /// The last thing automatic status did, or failed to do, in plain words.
  ///
  /// Background work fails silently by nature, and nobody can attach a
  /// debugger to Bunda's phone. Showing this on the Tempatku screen turns
  /// "it doesn't work" into something that can actually be diagnosed.
  static Future<void> recordEvent(String text, {DateTime? at}) async {
    final owner = await _owner();
    if (owner == null) return;
    await (await _prefs).setString(
      '$_lastEventPrefix$owner',
      jsonEncode({
        'at': (at ?? DateTime.now()).millisecondsSinceEpoch,
        'text': text,
      }),
    );
  }

  static Future<({DateTime at, String text})?> lastEvent() async {
    final owner = await _owner();
    if (owner == null) return null;
    final raw = (await _prefs).getString('$_lastEventPrefix$owner');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return (
        at: DateTime.fromMillisecondsSinceEpoch(decoded['at'] as int),
        text: decoded['text'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// The place this phone last saw its owner inside: an id, '' for "outside
  /// all of them", or null before the first reading.
  static Future<String?> lastInside() async {
    final owner = await _owner();
    if (owner == null) return null;
    return (await _prefs).getString('$_lastInsidePrefix$owner');
  }

  static Future<void> setLastInside(String placeIdOrEmpty) async {
    final owner = await _owner();
    if (owner == null) return;
    await (await _prefs).setString('$_lastInsidePrefix$owner', placeIdOrEmpty);
  }

  /// Hands 1.1.x's three fixed places to whoever is logged in now — on every
  /// phone that ran 1.1.x, that is the person who marked them.
  static Future<void> _migrateLegacy(SharedPreferences prefs, String owner) async {
    final raw = prefs.getString(_legacyPlacesKey);
    final legacyAuto = prefs.getBool(_legacyAutoKey);
    if (raw == null && legacyAuto == null) return;

    if (raw != null && !prefs.containsKey('$_placesPrefix$owner')) {
      final migrated = <FamilyPlace>[];
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final naming = _legacyNames[entry.key];
          if (naming == null) continue;
          final json = entry.value as Map<String, dynamic>;
          migrated.add(FamilyPlace.fromJson({
            ...json,
            'id': entry.key,
            'name': naming.$1,
            'icon': naming.$2.name,
          }));
        }
      } catch (_) {}
      await prefs.setString(
        '$_placesPrefix$owner',
        jsonEncode([for (final p in migrated) p.toJson()]),
      );
    }
    if (legacyAuto != null && !prefs.containsKey('$_autoPrefix$owner')) {
      await prefs.setBool('$_autoPrefix$owner', legacyAuto);
    }
    await prefs.remove(_legacyPlacesKey);
    await prefs.remove(_legacyAutoKey);
    await prefs.remove(_legacyLastEventKey);
  }
}
