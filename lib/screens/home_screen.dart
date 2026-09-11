import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../services/geofence_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'announcement_screen.dart';
import 'calendar_screen.dart';
import 'map_screen.dart';
import 'status_screen.dart';
import 'tasks_screen.dart';

class HomeScreen extends StatefulWidget {
  final String profileId;

  const HomeScreen({super.key, required this.profileId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;
  int _previous = 0;

  static const _payloadTabs = {
    'status': 0,
    'calendar': 1,
    'announcements': 2,
    'jobs': 3,
    'errands': 3,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resume();
    NotificationService.pendingPayload.addListener(_openTabFromNotification);
    _openTabFromNotification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.pendingPayload.removeListener(_openTabFromNotification);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else if (state == AppLifecycleState.paused) {
      LocationService.instance.stopSharing();
    }
  }

  /// Location sharing records an intention, not a running stream, so something
  /// has to re-arm it. Geofences need the same treatment for a different
  /// reason: Android drops them whenever Location is switched off and never
  /// puts them back.
  Future<void> _resume() async {
    await LocationService.instance.reArmIfEnabled(widget.profileId);
    await GeofenceService.instance.syncGeofences(widget.profileId);
  }

  void _openTabFromNotification() {
    final payload = NotificationService.pendingPayload.value;
    if (payload == null) return;
    final tab = _payloadTabs[payload];
    NotificationService.pendingPayload.value = null;
    if (tab == null || !mounted) return;
    setState(() {
      _previous = _index;
      _index = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      StatusScreen(profileId: widget.profileId),
      CalendarScreen(profileId: widget.profileId),
      AnnouncementScreen(profileId: widget.profileId),
      TasksScreen(profileId: widget.profileId),
      MapScreen(profileId: widget.profileId),
    ];

    return Scaffold(
      body: PageTransitionSwitcher(
        reverse: _index < _previous,
        transitionBuilder: (child, animation, secondaryAnimation) =>
            SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: pages[_index],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _previous = _index;
          _index = i;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Keluarga',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'Pengumuman',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Tugas',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place_rounded),
            label: 'Peta',
          ),
        ],
      ),
    );
  }
}
