import 'package:flutter/material.dart';

import '../screens/admin_screen.dart';
import '../services/profile_session.dart';

/// Sits in the AppBar of each top-level tab. Renders nothing for non-admins,
/// so the admin panel simply isn't reachable for them.
class AdminAction extends StatelessWidget {
  final String profileId;

  const AdminAction({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    if (!ProfileSession.isAdmin(profileId)) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.admin_panel_settings),
      tooltip: 'Admin',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdminScreen(profileId: profileId)),
      ),
    );
  }
}
