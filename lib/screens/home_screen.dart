import 'package:animations/animations.dart';
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
  int _previous = 0;

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
          NavigationDestination(icon: Icon(Icons.badge_outlined), label: 'Kartu'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Kalender'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Pengumuman'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.place_outlined), label: 'Peta'),
        ],
      ),
    );
  }
}
