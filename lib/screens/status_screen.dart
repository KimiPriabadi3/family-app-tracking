import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../widgets/admin_action.dart';

class StatusScreen extends StatelessWidget {
  final String profileId;

  const StatusScreen({super.key, required this.profileId});

  IconData _iconFor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.home:
        return Icons.home;
      case PresenceStatus.campus:
        return Icons.school;
      case PresenceStatus.office:
        return Icons.business_center;
      case PresenceStatus.sleeping:
        return Icons.bedtime;
      case PresenceStatus.other:
        return Icons.help_outline;
    }
  }

  Future<void> _changeStatus(BuildContext context, Profile me) async {
    final noteController = TextEditingController(text: me.statusNote ?? '');
    final chosen = await showModalBottomSheet<PresenceStatus>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (opsional)',
                    hintText: 'misal: OTW pulang, telat 30 menit',
                  ),
                ),
              ),
              ...PresenceStatus.values.map((s) => ListTile(
                    leading: Icon(_iconFor(s)),
                    title: Text(s.label),
                    trailing: s == me.status ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, s),
                  )),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      final note = noteController.text.trim();
      await FirestoreService.instance
          .updateStatus(profileId, chosen, note: note.isEmpty ? null : note);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Keluarga'),
        actions: [AdminAction(profileId: profileId)],
      ),
      body: StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, snapshot) {
          final profiles = snapshot.data ?? const <Profile>[];
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: profiles.length,
            itemBuilder: (context, i) {
              final p = profiles[i];
              final isMe = p.id == profileId;
              return ListTile(
                leading: CircleAvatar(child: Icon(_iconFor(p.status))),
                title: Text(p.name),
                subtitle: Text([
                  p.status.label,
                  if ((p.statusNote ?? '').isNotEmpty) p.statusNote!,
                  if (p.statusUpdatedAt != null)
                    'diperbarui ${TimeOfDay.fromDateTime(p.statusUpdatedAt!).format(context)}',
                ].join(' · ')),
                trailing: isMe
                    ? FilledButton.tonal(
                        onPressed: () => _changeStatus(context, p),
                        child: const Text('Ubah'),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
