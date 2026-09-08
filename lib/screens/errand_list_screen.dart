import 'package:flutter/material.dart';

import '../models/errand_item.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';

/// Sub-tab of TasksScreen. Uses its own transparent Scaffold purely so the
/// add button only shows while this tab is the visible one.
class ErrandListScreen extends StatelessWidget {
  final String profileId;

  const ErrandListScreen({super.key, required this.profileId});

  Future<void> _addItem(BuildContext context) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Titip beli'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nama barang',
            hintText: 'misal: Susu UHT',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );

    if (saved != true || controller.text.trim().isEmpty) return;

    await FirestoreService.instance.addErrandItem(ErrandItem(
      id: '',
      name: controller.text.trim(),
      requestedByProfileId: profileId,
      createdAt: DateTime.now(),
    ));
  }

  Widget _buildTile(ErrandItem item, Map<String, String> names, bool isAdmin) {
    final canDelete = isAdmin || item.requestedByProfileId == profileId;
    final buyer = item.doneByProfileId == null
        ? null
        : names[item.doneByProfileId] ?? item.doneByProfileId;
    return CheckboxListTile(
      value: item.done,
      onChanged: (checked) => FirestoreService.instance
          .setErrandDone(item.id, checked ?? false, profileId),
      title: Text(
        item.name,
        style: item.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: Text(item.done
          ? 'Dibeli oleh ${buyer ?? '-'}'
          : 'Dititip ${names[item.requestedByProfileId] ?? item.requestedByProfileId}'),
      secondary: canDelete
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus',
              onPressed: () => FirestoreService.instance.deleteErrandItem(item.id),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ProfileSession.isAdmin(profileId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addItem(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, profileSnap) {
          final names = {
            for (final p in profileSnap.data ?? const <Profile>[]) p.id: p.name,
          };
          return StreamBuilder<List<ErrandItem>>(
            stream: FirestoreService.instance.watchErrandItems(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? const <ErrandItem>[];
              if (items.isEmpty) {
                return const Center(child: Text('Belum ada titipan belanja'));
              }
              final pending = items.where((e) => !e.done).toList();
              final done = items.where((e) => e.done).toList();
              return ListView(
                children: [
                  ...pending.map((e) => _buildTile(e, names, isAdmin)),
                  if (done.isNotEmpty) const Divider(),
                  ...done.map((e) => _buildTile(e, names, isAdmin)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
