import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import '../theme/register_theme.dart';
import '../utils/relative_time.dart';
import '../widgets/admin_action.dart';
import '../widgets/register.dart';

/// Notices posted to the household record. Newest sits at the top of the
/// sheet, each one signed by the member's own ink.
class AnnouncementScreen extends StatelessWidget {
  final String profileId;

  const AnnouncementScreen({super.key, required this.profileId});

  Future<void> _post(BuildContext context) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('TULIS PENGUMUMAN'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Isi pengumuman',
            hintText: 'misal: token listrik habis',
          ),
          autofocus: true,
          maxLength: 140,
          maxLines: 3,
          minLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('TEMPEL'),
          ),
        ],
      ),
    );

    if (saved != true || controller.text.trim().isEmpty) return;

    await FirestoreService.instance.addAnnouncement(Announcement(
      id: '',
      authorProfileId: profileId,
      message: controller.text.trim(),
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _confirmRemove(BuildContext context, Announcement item) async {
    final messenger = ScaffoldMessenger.of(context);
    await FirestoreService.instance.deleteAnnouncement(item.id);
    messenger.showSnackBar(
      const SnackBar(content: Text('Pengumuman dicabut dari papan.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ProfileSession.isAdmin(profileId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PAPAN PENGUMUMAN'),
        actions: [AdminAction(profileId: profileId)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _post(context),
        icon: const Icon(Icons.push_pin_outlined),
        label: const Text('TEMPEL'),
      ),
      body: StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, profileSnap) {
          final names = {
            for (final p in profileSnap.data ?? const <Profile>[]) p.id: p.name,
          };
          return StreamBuilder<List<Announcement>>(
            stream: FirestoreService.instance.watchAnnouncements(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? const <Announcement>[];
              if (items.isEmpty) {
                return const RegisterEmpty(
                  'Papan masih kosong.\nTempel sesuatu yang perlu diketahui semua orang.',
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  RegisterSheet(
                    child: Column(
                      children: [
                        const RegisterHeaderStrip(
                          columns: ['Isi pengumuman'],
                          flex: [1],
                        ),
                        for (var i = 0; i < items.length; i++)
                          _NoticeRow(
                            item: items[i],
                            authorName: names[items[i].authorProfileId] ??
                                items[i].authorProfileId,
                            canRemove:
                                isAdmin || items[i].authorProfileId == profileId,
                            onRemove: () => _confirmRemove(context, items[i]),
                            last: i == items.length - 1,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                    child: Text(
                      'Yang menempel boleh mencabut pengumumannya sendiri.',
                      style: RegisterType.annotation.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  final Announcement item;
  final String authorName;
  final bool canRemove;
  final VoidCallback onRemove;
  final bool last;

  const _NoticeRow({
    required this.item,
    required this.authorName,
    required this.canRemove,
    required this.onRemove,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = RegisterInk.forMember(context, item.authorProfileId);

    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: ink),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.message,
                      style: RegisterType.value.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FieldLabel(authorName, color: ink),
                        const SizedBox(width: 8),
                        Text(
                          formatRelativeTime(item.createdAt),
                          style: RegisterType.annotation.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (canRemove)
              InkWell(
                onTap: onRemove,
                child: Container(
                  width: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: scheme.outline)),
                  ),
                  child: FieldLabel('Cabut', color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
