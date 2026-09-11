import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import 'auto_status.dart';
import 'auto_status_apply.dart';
import 'firestore_service.dart';
import 'place_store.dart';
import 'profile_session.dart';

/// Ignore a repeat event for the same place within this window.
///
/// A phone sitting near a boundary can bounce in and out; without this the
/// status would flicker and each flicker would be a write.
const Duration _debounce = Duration(seconds: 90);

/// Runs in its own isolate when Android reports a boundary crossing.
///
/// Kept in a file of its own so the background isolate pulls in as little as
/// possible — no widgets, no theme, no screens.
@pragma('vm:entry-point')
Future<void> geofenceTriggered(GeofenceCallbackParams params) async {
  WidgetsFlutterBinding.ensureInitialized();
  // native_geofence's dispatcher does not do this, and without it every
  // plugin with a Dart-side implementation — SharedPreferences first among
  // them — throws MissingPluginException in this isolate. That silently
  // killed every crossing in 1.1.0.
  DartPluginRegistrant.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    final profileId = await ProfileSession.getSelectedProfileId();
    if (profileId == null) return;

    final region = params.geofences.firstOrNull;
    if (region == null) return;

    // Ids are "<profileId>_<statusName>"; anything else is a leftover from a
    // profile switch and must not move this member's status.
    final parts = region.id.split('_');
    if (parts.length != 2 || parts.first != profileId) return;
    final placeStatus = PresenceStatusX.fromName(parts[1]);

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final debounceKey = 'geo_last_event_${region.id}';
    final lastMs = prefs.getInt(debounceKey);
    final now = DateTime.now();
    if (lastMs != null) {
      final since = now.difference(DateTime.fromMillisecondsSinceEpoch(lastMs));
      if (since < _debounce) return;
    }
    await prefs.setInt(debounceKey, now.millisecondsSinceEpoch);

    final GeofenceEdge edge;
    switch (params.event) {
      case GeofenceEvent.enter:
      case GeofenceEvent.dwell:
        edge = GeofenceEdge.entered;
      case GeofenceEvent.exit:
        edge = GeofenceEdge.exited;
    }

    final me = await FirestoreService.instance.getProfile(profileId);
    await applyPlaceEdge(
      profileId: profileId,
      placeStatus: placeStatus,
      edge: edge,
      origin: AutoStatusOrigin.background,
      current: me,
    );

    // Free of charge, since the OS already woke us with a fix: refresh the map
    // position. This is the only time the map gets anything while the app is
    // closed.
    if (me != null && me.locationSharingEnabled) {
      final location = params.location;
      if (location != null) {
        await FirestoreService.instance
            .updateLocation(profileId, location.latitude, location.longitude)
            .timeout(const Duration(seconds: 10));
      }
    }
  } catch (e) {
    // Never crash a background isolate over a missed crossing, but leave a
    // trace the member can read on the Tempatku screen.
    try {
      await PlaceStore.recordEvent('Gagal di latar belakang: $e');
    } catch (_) {}
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
