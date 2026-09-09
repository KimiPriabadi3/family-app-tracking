import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../screens/admin_screen.dart';
import '../services/profile_session.dart';

/// Sits in the AppBar of each top-level tab. Renders nothing for non-admins,
/// so the amendment page is simply unreachable for them.
class AdminAction extends StatelessWidget {
  final String profileId;

  const AdminAction({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    if (!ProfileSession.isAdmin(profileId)) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.tune_rounded),
      tooltip: 'Admin',
      onPressed: () => Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, animation, secondaryAnimation) => SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.scaled,
            fillColor: Theme.of(context).scaffoldBackgroundColor,
            child: AdminScreen(profileId: profileId),
          ),
        ),
      ),
    );
  }
}
