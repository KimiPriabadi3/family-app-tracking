import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import '../utils/relative_time.dart';
import '../widgets/admin_action.dart';

class AnnouncementScreen extends StatelessWidget {
  final String profileId;

  const AnnouncementScreen({super.key, required this.profileId});

  Future<void> _addAnnouncement(BuildContext context) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tulis pengumuman'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Pesan singkat',
            hintText: 'misal: ada tamu sore ini',
          ),
          autofocus: true,
          maxLength: 140,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kirim')),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addAnnouncement(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, profileSnap) {
          final profileNames = {
            for (final p in profileSnap.data ?? const <Profile>[]) p.id: p.name,
          };
          return StreamBuilder<List<Announcement>>(
            stream: FirestoreService.instance.watchAnnouncements(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final announcements = snapshot.data ?? const <Announcement>[];
              if (announcements.isEmpty) {
                return const Center(child: Text('Belum ada pengumuman'));
              }
              return ListView.builder(
                itemCount: announcements.length,
                itemBuilder: (context, i) {
                  final item = announcements[i];
                  final authorName =
                      profileNames[item.authorProfileId] ?? item.authorProfileId;
                  final canDelete = isAdmin || item.authorProfileId == profileId;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(authorName.isEmpty ? '?' : authorName[0]),
                    ),
                    title: Text(item.message),
                    subtitle: Text('$authorName · ${formatRelativeTime(item.createdAt)}'),
                    trailing: canDelete
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Hapus',
                            onPressed: () =>
                                FirestoreService.instance.deleteAnnouncement(item.id),
                          )
                        : null,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
