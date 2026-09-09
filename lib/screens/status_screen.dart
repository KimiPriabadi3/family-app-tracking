import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/freshness.dart';
import '../utils/relative_time.dart';
import '../widgets/admin_action.dart';
import '../widgets/soft.dart';

IconData iconForStatus(PresenceStatus status) {
  switch (status) {
    case PresenceStatus.home:
      return Icons.home_rounded;
    case PresenceStatus.campus:
      return Icons.school_rounded;
    case PresenceStatus.office:
      return Icons.work_rounded;
    case PresenceStatus.sleeping:
      return Icons.bedtime_rounded;
    case PresenceStatus.other:
      return Icons.explore_rounded;
  }
}

/// Who is where, right now. The first thing anyone sees when they open the app.
class StatusScreen extends StatelessWidget {
  final String profileId;

  const StatusScreen({super.key, required this.profileId});

  static const _order = ['bunda', 'aku', 'adek'];

  Future<void> _setStatus(BuildContext context, Profile me) async {
    final noteController = TextEditingController(text: me.statusNote ?? '');
    final chosen = await showModalBottomSheet<PresenceStatus>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                  child: Text(
                    'Kamu lagi di mana?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: TextField(
                    controller: noteController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan (boleh dilewati)',
                      hintText: 'misal: otw pulang, telat 30 menit',
                    ),
                  ),
                ),
                for (final s in PresenceStatus.values)
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                    leading: Icon(iconForStatus(s), color: scheme.primary),
                    title: Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    trailing: s == me.status
                        ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, s),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (chosen == null) return;
    final note = noteController.text.trim();
    await FirestoreService.instance
        .updateStatus(profileId, chosen, note: note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keluarga'),
        actions: [AdminAction(profileId: profileId)],
      ),
      body: StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final byId = {for (final p in snapshot.data!) p.id: p};
          final profiles = [
            for (final id in _order)
              if (byId[id] != null) byId[id]!,
          ];
          final me = byId[profileId];

          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              for (final p in profiles)
                _MemberCard(
                  profile: p,
                  isMe: p.id == profileId,
                  onTap: p.id == profileId && me != null
                      ? () => _setStatus(context, me)
                      : null,
                ),
              if (me != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _setStatus(context, me),
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      label: const Text('Ubah keadaanku'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Profile profile;
  final bool isMe;
  final VoidCallback? onTap;

  const _MemberCard({required this.profile, required this.isMe, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppColors.forMember(context, profile.id);
    final fresh = freshnessOf(profile.statusUpdatedAt);
    final note = profile.statusNote;

    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemberAvatar(profileId: profile.id, name: profile.name, size: 50),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.name,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          Text(
                            'kamu',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: SoftPill(
                            text: profile.status.label,
                            color: color.withValues(alpha: fresh.inkOpacity),
                            icon: iconForStatus(profile.status),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            profile.statusUpdatedAt == null
                                ? 'belum diisi'
                                : formatRelativeTime(profile.statusUpdatedAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: fresh.isStale
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: scheme.onSurface.withValues(
                            alpha: fresh.inkOpacity,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
