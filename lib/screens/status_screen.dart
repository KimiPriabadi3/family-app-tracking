import 'package:flutter/material.dart';

import '../models/family_place.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/place_store.dart';
import '../theme/app_theme.dart';
import '../utils/freshness.dart';
import '../utils/relative_time.dart';
import '../widgets/admin_action.dart';
import '../widgets/place_icons.dart';
import '../widgets/settings_action.dart';
import '../widgets/soft.dart';
import '../widgets/theme_action.dart';

/// Who is where, right now. The first thing anyone sees when they open the app.
class StatusScreen extends StatelessWidget {
  final String profileId;

  const StatusScreen({super.key, required this.profileId});

  static const _order = ['bunda', 'aku', 'adek'];

  Future<void> _setStatus(BuildContext context, Profile me) async {
    final noteController = TextEditingController(text: me.statusNote ?? '');
    // The member's own places come first: "Di Bimbel Primagama" is a better
    // answer than "Lainnya" with a note.
    final places = await PlaceStore.places();
    if (!context.mounted) return;
    final chosen = await showModalBottomSheet<(PresenceStatus, FamilyPlace?)>(
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
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (final place in places)
                        _StatusOption(
                          icon: placeIconData(place.icon),
                          label: 'Di ${place.name}',
                          selected: me.status == PresenceStatus.place &&
                              me.statusPlace == place.name,
                          onTap: () => Navigator.pop(
                              sheetContext, (PresenceStatus.place, place)),
                        ),
                      if (places.isNotEmpty) const Divider(indent: 24, endIndent: 24),
                      for (final s in PresenceStatus.values)
                        if (s != PresenceStatus.place)
                          _StatusOption(
                            icon: iconForStatus(s),
                            label: s.label,
                            selected: s == me.status,
                            onTap: () => Navigator.pop(sheetContext, (s, null)),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosen == null) return;
    final (status, place) = chosen;
    final note = noteController.text.trim();
    await FirestoreService.instance.updateStatus(
      profileId,
      status,
      note: note.isEmpty ? null : note,
      placeName: place?.name,
      placeIcon: place?.icon.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keluarga'),
        actions: [
          const ThemeAction(),
          SettingsAction(profileId: profileId),
          AdminAction(profileId: profileId),
        ],
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
                    // Wraps rather than squeezes: a long place name keeps the
                    // whole pill, and the time drops to the next line.
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SoftPill(
                          text: profile.statusLabel,
                          color: color.withValues(alpha: fresh.inkOpacity),
                          icon: iconForProfileStatus(profile),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
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
                    // Says what moved it, so a status nobody typed doesn't
                    // read like a claim they made. Automatic writes always
                    // clear the note, so this never competes with one.
                    if (profile.statusSource == StatusSource.auto) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Berubah otomatis dari lokasi',
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _StatusOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Icon(icon, color: scheme.primary),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
