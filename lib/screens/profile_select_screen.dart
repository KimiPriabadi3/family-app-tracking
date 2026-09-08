import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import '../theme/register_theme.dart';
import '../widgets/register.dart';
import 'home_screen.dart';

/// There is no login. This phone simply claims one row of the family card,
/// and remembers it.
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: scheme.primary,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel('Kartu keluarga', color: scheme.onPrimary),
                  const SizedBox(height: 10),
                  Text(
                    'Kamu yang mana?',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'HP ini akan mengingat barismu. Tidak ada kata sandi.',
                    style: RegisterType.annotation.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  RegisterSheet(
                    child: Column(
                      children: [
                        const RegisterHeaderStrip(
                          columns: ['No.', 'Nama'],
                          flex: [1, 6],
                        ),
                        for (var i = 0; i < entries.length; i++)
                          _ClaimRow(
                            number: i + 1,
                            profileId: entries[i].key,
                            name: entries[i].value,
                            busy: _claiming != null,
                            claiming: _claiming == entries[i].key,
                            last: i == entries.length - 1,
                            onTap: () => _select(entries[i].key),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  final int number;
  final String profileId;
  final String name;
  final bool busy;
  final bool claiming;
  final bool last;
  final VoidCallback onTap;

  const _ClaimRow({
    required this.number,
    required this.profileId,
    required this.name,
    required this.busy,
    required this.claiming,
    required this.last,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = RegisterInk.forMember(context, profileId);

    return InkWell(
      onTap: busy ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: scheme.outline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Row(
          children: [
            SerialBand(number: number, ink: ink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: RegisterType.valueStrong.copyWith(color: ink, fontSize: 22),
              ),
            ),
            if (claiming)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              FieldLabel('pilih baris ini', color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Routes to the picker or straight to the card if this phone already claimed
/// a row.
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
