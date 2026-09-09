import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import '../theme/app_theme.dart';
import '../widgets/soft.dart';
import 'home_screen.dart';

/// No login — this phone just says who is holding it, once.
class ProfileSelectScreen extends StatefulWidget {
  const ProfileSelectScreen({super.key});

  @override
  State<ProfileSelectScreen> createState() => _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends State<ProfileSelectScreen> {
  String? _claiming;

  Future<void> _select(String profileId) async {
    setState(() => _claiming = profileId);
    await ProfileSession.setSelectedProfileId(profileId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(profileId: profileId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = kDefaultProfileNames.entries.toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.favorite_rounded,
                    size: 34, color: scheme.primary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 6),
              child: Text(
                'Halo! Kamu siapa?',
                style: TextStyle(
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
              child: Text(
                'HP ini akan mengingat pilihanmu. Tidak perlu kata sandi.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final e in entries)
              _ClaimCard(
                profileId: e.key,
                name: e.value,
                busy: _claiming != null,
                claiming: _claiming == e.key,
                onTap: () => _select(e.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final String profileId;
  final String name;
  final bool busy;
  final bool claiming;
  final VoidCallback onTap;

  const _ClaimCard({
    required this.profileId,
    required this.name,
    required this.busy,
    required this.claiming,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppColors.forMember(context, profileId);

    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              MemberAvatar(profileId: profileId, name: name, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (claiming)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.arrow_forward_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Routes to the picker, or straight in if this phone already chose.
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
