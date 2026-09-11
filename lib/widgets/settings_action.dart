import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';

/// One entry point into per-member settings, on the Keluarga tab only — the
/// other four tabs stay uncluttered.
class SettingsAction extends StatelessWidget {
  final String profileId;

  const SettingsAction({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Pengaturan',
      onPressed: () => Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, animation, secondaryAnimation) => SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.scaled,
            fillColor: Theme.of(context).scaffoldBackgroundColor,
            child: SettingsScreen(profileId: profileId),
          ),
        ),
      ),
    );
  }
}
