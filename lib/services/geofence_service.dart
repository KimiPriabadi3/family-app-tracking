import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/family_place.dart';
import '../models/profile.dart';
import 'auto_status.dart';
import 'auto_status_apply.dart';
import 'firestore_service.dart';
import 'geofence_callback.dart';
import 'place_store.dart';

enum LocationPermissionLevel { none, whileInUse, always }

/// Registers the member's marked places with Android, which then wakes the app
/// only when a boundary is crossed.
///
/// Deliberately not a location stream: the OS geofencing API costs far less
/// battery, needs no foreground service, and therefore leaves no permanent
/// "this app is tracking you" notification in the shade.
///
/// Swappable so the web demo and golden renders substitute a no-op.
class GeofenceService {
  static GeofenceService instance = GeofenceService();

  Future<void> init() async {
    await NativeGeofenceManager.instance.initialize();
  }

  Future<LocationPermissionLevel> permissionLevel() async {
    if (await Permission.locationAlways.isGranted) {
      return LocationPermissionLevel.always;
    }
    if (await Permission.locationWhenInUse.isGranted) {
      return LocationPermissionLevel.whileInUse;
    }
    return LocationPermissionLevel.none;
  }

  Future<bool> requestWhileInUse() async =>
      (await Permission.locationWhenInUse.request()).isGranted;

  /// Android insists this is asked separately, and only once "while in use" is
  /// already granted. On Android 11+ it does not even show a dialog — it drops
  /// the user on the app's location settings page.
  Future<bool> requestAlways() async =>
      (await Permission.locationAlways.request()).isGranted;

  Future<bool> isBatteryOptimised() async =>
      !(await Permission.ignoreBatteryOptimizations.isGranted);

  Future<bool> requestIgnoreBatteryOptimizations() async =>
      (await Permission.ignoreBatteryOptimizations.request()).isGranted;

  Future<void> openSettings() => openAppSettings();

  /// Re-registers every marked place.
  ///
  /// Called on launch and on resume, not just when places change: Android
  /// silently drops all geofences when the user turns Location off, and does
  /// not restore them when it comes back on.
  Future<void> syncGeofences(String profileId) async {
    await clearAll();

    if (!await PlaceStore.autoStatusEnabled()) return;
    if (await permissionLevel() != LocationPermissionLevel.always) return;

    final places = await PlaceStore.places();
    for (final entry in places.entries) {
      await NativeGeofenceManager.instance.createGeofence(
        Geofence(
          id: '${profileId}_${entry.key.name}',
          location: Location(
            latitude: entry.value.latitude,
            longitude: entry.value.longitude,
          ),
          radiusMeters: entry.value.radiusMeters.toDouble(),
          triggers: const {
            GeofenceEvent.enter,
            GeofenceEvent.exit,
            GeofenceEvent.dwell,
          },
          androidSettings: const AndroidGeofenceSettings(
            // Fires straight away if the member is already inside when they
            // switch the feature on.
            initialTriggers: {GeofenceEvent.enter},
            expiration: null,
            // Arrival is taken from dwell rather than enter: you have to stay
            // put for three minutes, so merely driving past does not count.
            loiteringDelay: Duration(minutes: 3),
            notificationResponsiveness: Duration(minutes: 2),
          ),
          // Required by the package even though this app ships Android only.
          iosSettings: const IosGeofenceSettings(initialTrigger: true),
        ),
        geofenceTriggered,
      );
    }
  }

  /// One look at where the phone is right now, applied like a crossing.
  ///
  /// Android only reports crossings, and some phones' battery savers swallow
  /// them. Checking every time the app is opened means the status is right at
  /// least whenever someone is looking at it.
  Future<void> checkPlacesNow(String profileId) async {
    if (!await PlaceStore.autoStatusEnabled()) return;
    if (await permissionLevel() == LocationPermissionLevel.none) return;
    final places = await PlaceStore.places();
    if (places.isEmpty) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final me = await FirestoreService.instance.getProfile(profileId);
      if (me == null) return;
      final reading = readPlaces(
        places: places,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        currentStatus: me.status,
      );
      if (reading == null) return;
      await applyPlaceEdge(
        profileId: profileId,
        placeStatus: reading.place,
        edge: reading.edge,
        origin: AutoStatusOrigin.appOpened,
        current: me,
      );
    } catch (e) {
      await PlaceStore.recordEvent('Gagal memeriksa lokasi: $e');
    }
  }

  /// Marking a place while standing in it is the clearest arrival there is.
  Future<void> arrivedByMarking(String profileId, PresenceStatus place) async {
    if (!await PlaceStore.autoStatusEnabled()) return;
    try {
      await applyPlaceEdge(
        profileId: profileId,
        placeStatus: place,
        edge: GeofenceEdge.entered,
        origin: AutoStatusOrigin.marked,
      );
    } catch (e) {
      await PlaceStore.recordEvent('Gagal mengubah status: $e');
    }
  }

  Future<void> clearAll() async {
    await NativeGeofenceManager.instance.removeAllGeofences();
  }

  Future<List<String>> registeredIds() async {
    final regions = await NativeGeofenceManager.instance.getRegisteredGeofences();
    return regions.map((g) => g.id).toList();
  }

  /// Convenience for the settings screen.
  Future<Map<PresenceStatus, FamilyPlace>> places() => PlaceStore.places();
}
