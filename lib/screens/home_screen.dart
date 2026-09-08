import 'package:flutter/material.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CalendarScreen(profileId: widget.profileId),
      StatusScreen(profileId: widget.profileId),
      AnnouncementScreen(profileId: widget.profileId),
      TasksScreen(profileId: widget.profileId),
      MapScreen(profileId: widget.profileId),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Kalender'),
          NavigationDestination(icon: Icon(Icons.person_pin_circle), label: 'Status'),
          NavigationDestination(icon: Icon(Icons.campaign), label: 'Pengumuman'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Peta'),
        ],
      ),
    );
  }
}
