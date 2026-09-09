import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'firestore_service.dart';

/// Requests location permission and periodically pushes this device's
/// position to Firestore while sharing is enabled. Only runs while the
/// app is in the foreground — there is no background service yet, so a
/// member's location only updates while they have the app open.
class LocationService {
  /// Swappable so the public demo can leave the browser's location prompt
  /// alone.
  static LocationService instance = LocationService();

  StreamSubscription<Position>? _positionSub;

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
    if (!granted) return;

    await _positionSub?.cancel();
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
  }
}
