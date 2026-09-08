import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import 'home_screen.dart';

/// No real accounts — just tap who you are. Picked once per device and
/// remembered locally via [ProfileSession].
class ProfileSelectScreen extends StatefulWidget {
  const ProfileSelectScreen({super.key});

  @override
  State<ProfileSelectScreen> createState() => _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends State<ProfileSelectScreen> {
  bool _selecting = false;

  Future<void> _select(String profileId) async {
    setState(() => _selecting = true);
    await ProfileSession.setSelectedProfileId(profileId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(profileId: profileId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.family_restroom, size: 64),
                const SizedBox(height: 16),
                Text('Kamu siapa?', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 32),
                if (_selecting)
                  const CircularProgressIndicator()
                else
                  ...kDefaultProfileNames.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _select(e.key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(e.value, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Call once at app start to route to the picker or straight to home if
/// this device already remembers a profile.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<String?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _prepare();
  }

  Future<String?> _prepare() async {
    await FirestoreService.instance.ensureSeedProfiles(
      kDefaultProfileNames,
      ProfileSession.adminProfileId,
    );
    return ProfileSession.getSelectedProfileId();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final profileId = snapshot.data;
        if (profileId == null) return const ProfileSelectScreen();
        return HomeScreen(profileId: profileId);
      },
    );
  }
}
