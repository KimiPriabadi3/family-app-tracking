import 'package:flutter/material.dart';

import 'demo/demo_firestore.dart';
import 'models/family_place.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/firestore_service.dart';
import 'services/geofence_service.dart';
import 'services/location_service.dart';
import 'services/notification_plan.dart';
import 'services/notification_service.dart';
import 'services/profile_session.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

/// Entry point for the public web demo.
///
/// It never initialises Firebase. Everything runs against invented household
/// data held in this tab, so opening the demo cannot read or change the real
/// family's record.
void main() {
  FirestoreService.instance = DemoFirestore();
  LocationService.instance = _NoLocationService();
  // native_geofence, workmanager and flutter_local_notifications have no web
  // implementation, so every one of them is stubbed out here. Never call
  // Workmanager().initialize() in this entry point.
  GeofenceService.instance = _NoGeofenceService();
  NotificationService.instance = _NoNotificationService();
  SettingsScreen.allowSignOut = false;
  // Places are kept per member, so the demo has to say who is "logged in".
  ProfileSession.setSelectedProfileId('aku');
  runApp(const FamilyAppDemo());
}

class _NoGeofenceService implements GeofenceService {
  @override
  Future<void> checkPlacesNow(String profileId) async {}

  @override
  Future<void> arrivedByMarking(String profileId, FamilyPlace place) async {}

  @override
  Future<void> init() async {}

  @override
  Future<LocationPermissionLevel> permissionLevel() async =>
      LocationPermissionLevel.always;

  @override
  Future<bool> requestWhileInUse() async => true;

  @override
  Future<bool> requestAlways() async => true;

  @override
  Future<bool> isBatteryOptimised() async => false;

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async => true;

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> syncGeofences(String profileId) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<List<String>> registeredIds() async => const [];

  @override
  Future<List<FamilyPlace>> places() async => const [];
}

class _NoNotificationService implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<bool> permissionGranted() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show(PlannedNotification notification) async {}

  @override
  Future<void> consumeLaunchPayload() async {}
}

/// The demo fakes coordinates itself, so there is no reason to make a visitor
/// answer their browser's location prompt.
class _NoLocationService implements LocationService {
  @override
  bool get isSharing => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> startSharing(String profileId) async {}

  @override
  Future<void> stopSharing() async {}

  @override
  Future<void> reArmIfEnabled(String profileId) async {}
}

class FamilyAppDemo extends StatefulWidget {
  const FamilyAppDemo({super.key});

  @override
  State<FamilyAppDemo> createState() => _FamilyAppDemoState();
}

class _FamilyAppDemoState extends State<FamilyAppDemo> {
  String _profileId = 'aku';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'My Family — demo',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: mode,
        home: _DemoShell(
          profileId: _profileId,
          onSwitch: (id) {
            ProfileSession.setSelectedProfileId(id);
            setState(() => _profileId = id);
          },
        ),
      ),
    );
  }
}

/// Wraps the real app with a strip explaining what this is, plus a switcher —
/// seeing the same record from Bunda's phone and from Adek's is the point of
/// the thing, and a visitor has only one screen to see it on.
class _DemoShell extends StatelessWidget {
  final String profileId;
  final ValueChanged<String> onSwitch;

  const _DemoShell({required this.profileId, required this.onSwitch});

  static const _members = {'bunda': 'Bunda', 'aku': 'Mas', 'adek': 'Adek'};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Material(
          color: AppColors.ink,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo · data contoh',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sun,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Isinya karangan dan hilang saat halaman ditutup. '
                          'Data keluarga yang asli tidak tersentuh.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Lihat sebagai',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final entry in _members.entries)
                            _MemberChip(
                              id: entry.key,
                              name: entry.value,
                              selected: entry.key == profileId,
                              onTap: () => onSwitch(entry.key),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: scheme.surfaceContainerLowest,
            child: HomeScreen(key: ValueKey(profileId), profileId: profileId),
          ),
        ),
      ],
    );
  }
}

class _MemberChip extends StatelessWidget {
  final String id;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _MemberChip({
    required this.id,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.members[id]!;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? color : Colors.white24),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
