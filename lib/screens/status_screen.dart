import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../theme/register_theme.dart';
import '../utils/freshness.dart';
import '../widgets/admin_action.dart';
import '../widgets/register.dart';

/// The register itself: three numbered rows, one ink each, every status a
/// stamped field carrying the time it was stamped and how much it has aged.
class StatusScreen extends StatelessWidget {
  final String profileId;

  const StatusScreen({super.key, required this.profileId});

  static const _order = ['bunda', 'aku', 'adek'];

  String _timeOf(BuildContext context, DateTime? at) {
    if (at == null) return '--:--';
    return TimeOfDay.fromDateTime(at).format(context);
  }

  Future<void> _stamp(BuildContext context, Profile me) async {
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: scheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: FieldLabel('Stempel keadaanmu', color: scheme.onPrimary),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: TextField(
                    controller: noteController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan (boleh dikosongkan)',
                      hintText: 'misal: OTW pulang, telat 30 menit',
                    ),
                  ),
                ),
                Container(height: 1, color: scheme.outline),
                for (final s in PresenceStatus.values)
                  InkWell(
                    onTap: () => Navigator.pop(sheetContext, s),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: scheme.outline)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.label,
                              style: RegisterType.value.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (s == me.status)
                            FieldLabel('sekarang', color: scheme.primary),
                        ],
                      ),
                    ),
                  ),
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KARTU KELUARGA'),
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
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              RegisterSheet(
                child: Column(
                  children: [
                    const RegisterHeaderStrip(
                      columns: ['No.', 'Nama', 'Keadaan · Pukul'],
                      flex: [1, 3, 5],
                    ),
                    for (var i = 0; i < profiles.length; i++)
                      _MemberRow(
                        number: i + 1,
                        profile: profiles[i],
                        isMe: profiles[i].id == profileId,
                        time: _timeOf(context, profiles[i].statusUpdatedAt),
                        last: i == profiles.length - 1,
                      ),
                  ],
                ),
              ),
              if (me != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: FilledButton(
                    onPressed: () => _stamp(context, me),
                    child: const Text('UBAH KEADAANMU'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                child: Text(
                  'Keadaan yang sudah lama dicoret sendiri, supaya tidak ada yang '
                  'mengira kabar kemarin masih berlaku.',
                  style: RegisterType.annotation.copyWith(
                    color: scheme.onSurfaceVariant,
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

class _MemberRow extends StatelessWidget {
  final int number;
  final Profile profile;
  final bool isMe;
  final String time;
  final bool last;

  const _MemberRow({
    required this.number,
    required this.profile,
    required this.isMe,
    required this.time,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = RegisterInk.forMember(context, profile.id);
    final fresh = freshnessOf(profile.statusUpdatedAt);
    final note = profile.statusNote;

    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SerialBand(number: number, ink: ink),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: RegisterType.valueStrong.copyWith(color: ink),
                ),
                if (isMe) ...[
                  const SizedBox(height: 2),
                  FieldLabel('barismu', color: scheme.onSurfaceVariant),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StampField(
                  value: profile.status.label,
                  ink: ink,
                  freshness: fresh,
                  trailing: time,
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note,
                    textAlign: TextAlign.right,
                    style: RegisterType.annotation.copyWith(
                      color: scheme.onSurface.withValues(alpha: fresh.inkOpacity),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  fresh.note,
                  style: RegisterType.label.copyWith(
                    fontSize: 10,
                    color: fresh.isStale ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
