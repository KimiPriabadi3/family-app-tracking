import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import '../theme/app_theme.dart';
import '../utils/relative_time.dart';
import '../widgets/admin_action.dart';
import '../widgets/soft.dart';

/// Short notes everyone should see, newest first.
class AnnouncementScreen extends StatelessWidget {
  final String profileId;

  const AnnouncementScreen({super.key, required this.profileId});

  Future<void> _post(BuildContext context) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tulis pengumuman'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
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
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tempel'),
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = ProfileSession.isAdmin(profileId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman'),
        actions: [AdminAction(profileId: profileId)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _post(context),
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('Tempel'),
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
                return const SoftEmpty(
                  icon: Icons.campaign_rounded,
                  message:
                      'Belum ada pengumuman.\nTempel sesuatu yang perlu diketahui semua orang.',
                );
              }
              return ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                children: [
                  for (final item in items)
                    _NoticeCard(
                      item: item,
                      authorName:
                          names[item.authorProfileId] ?? item.authorProfileId,
                      canRemove:
                          isAdmin || item.authorProfileId == profileId,
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

class _NoticeCard extends StatelessWidget {
  final Announcement item;
  final String authorName;
  final bool canRemove;

  const _NoticeCard({
    required this.item,
    required this.authorName,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppColors.forMember(context, item.authorProfileId);

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.message,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              MemberAvatar(
                profileId: item.authorProfileId,
                name: authorName,
                size: 30,
              ),
              const SizedBox(width: 9),
              Text(
                authorName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatRelativeTime(item.createdAt),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              if (canRemove)
                TextButton(
                  onPressed: () => FirestoreService.instance
                      .deleteAnnouncement(item.id),
                  child: const Text('Cabut'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
