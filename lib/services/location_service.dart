import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'firestore_service.dart';

/// Pushes this device's position to Firestore while sharing is on.
///
/// The live stream only runs while the app is in the foreground. Background
/// refreshes come from the geofence callback instead, which the OS wakes on a
/// boundary crossing — far cheaper than holding a location stream open.
class LocationService {
  /// Swappable so the public demo can leave the browser's location prompt
  /// alone.
  static LocationService instance = LocationService();

  StreamSubscription<Position>? _positionSub;
  String? _sharingProfileId;

  bool get isSharing => _positionSub != null;

  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> startSharing(String profileId) async {
    final granted = await requestPermission();
    if (!granted) {
      // Leaving the flag on with no stream is what made the map show a stale
      // position under a toggle that claimed to be live.
      await FirestoreService.instance.setLocationSharing(profileId, false);
      return;
    }

    await _positionSub?.cancel();
    _sharingProfileId = profileId;
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((position) {
      FirestoreService.instance.updateLocation(
        profileId,
        position.latitude,
        position.longitude,
      );
    });
  }

  Future<void> stopSharing() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _sharingProfileId = null;
  }

  /// Called on launch and whenever the app returns to the foreground.
  ///
  /// `locationSharingEnabled` records an intention, not a running stream, so
  /// something has to re-arm it — otherwise the toggle stays on across a
  /// restart while nothing is actually being sent.
  Future<void> reArmIfEnabled(String profileId) async {
    if (isSharing && _sharingProfileId == profileId) return;

    final profile = await FirestoreService.instance.getProfile(profileId);
    if (profile == null || !profile.locationSharingEnabled) return;

    await startSharing(profileId);
  }
}
