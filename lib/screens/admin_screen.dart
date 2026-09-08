import 'package:flutter/material.dart';

import '../models/job_assignment.dart';
import '../models/job_template.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';

/// Only reachable by [ProfileSession.adminProfileId]. Lets the admin
/// manage the rolling job list and who's assigned to what this week.
/// Cancelling other members' calendar events is handled inline on the
/// Kalender tab (it already checks isAdmin there).
class AdminScreen extends StatelessWidget {
  final String profileId;

  const AdminScreen({super.key, required this.profileId});

  Future<void> _addTemplate(BuildContext context) async {
    final nameController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah job'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nama job (misal: Sapu rumah)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (saved != true || nameController.text.trim().isEmpty) return;
    await FirestoreService.instance.addJobTemplate(
      JobTemplate(id: '', name: nameController.text.trim()),
    );
  }

  Future<void> _assign(BuildContext context, JobTemplate job, List<Profile> profiles,
      DateTime weekStart, String? currentAssignee) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: profiles
              .map((p) => ListTile(
                    title: Text(p.name),
                    trailing: p.id == currentAssignee ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, p.id),
                  ))
              .toList(),
        ),
      ),
    );
    if (chosen == null) return;
    await FirestoreService.instance.setAssignment(JobAssignment(
      id: '',
      jobTemplateId: job.id,
      assignedProfileId: chosen,
      weekStart: weekStart,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = JobAssignment.weekStartFor(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTemplate(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, profileSnap) {
          final profiles = profileSnap.data ?? const <Profile>[];
          return StreamBuilder<List<JobTemplate>>(
            stream: FirestoreService.instance.watchJobTemplates(),
            builder: (context, templateSnap) {
              final templates = templateSnap.data ?? const <JobTemplate>[];
              return StreamBuilder<List<JobAssignment>>(
                stream: FirestoreService.instance.watchAssignmentsForWeek(weekStart),
                builder: (context, assignSnap) {
                  final assignments = {
                    for (final a in assignSnap.data ?? const <JobAssignment>[])
                      a.jobTemplateId: a.assignedProfileId,
                  };
                  if (templates.isEmpty) {
                    return const Center(child: Text('Belum ada job. Tekan + untuk menambah.'));
                  }
                  return ListView.builder(
                    itemCount: templates.length,
                    itemBuilder: (context, i) {
                      final job = templates[i];
                      final assignedId = assignments[job.id];
                      String? assignedName;
                      for (final p in profiles) {
                        if (p.id == assignedId) {
                          assignedName = p.name;
                          break;
                        }
                      }
                      return ListTile(
                        title: Text(job.name),
                        subtitle: Text(assignedName ?? 'Belum ditentukan'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _assign(context, job, profiles, weekStart, assignedId),
                              child: const Text('Atur'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => FirestoreService.instance.deleteJobTemplate(job.id),
                            ),
                          ],
                        ),
                      );
                    },
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
