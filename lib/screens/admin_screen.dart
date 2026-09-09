import 'package:flutter/material.dart';

import '../models/job_assignment.dart';
import '../models/job_template.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/soft.dart';

/// Admin-only: edit the chore list and set who holds each turn this week.
class AdminScreen extends StatelessWidget {
  final String profileId;

  const AdminScreen({super.key, required this.profileId});

  Future<void> _addJob(BuildContext context) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah pekerjaan'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'misal: sapu rumah'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (saved != true || controller.text.trim().isEmpty) return;
    await FirestoreService.instance
        .addJobTemplate(JobTemplate(id: '', name: controller.text.trim()));
  }

  Future<void> _assign(
    BuildContext context,
    JobTemplate job,
    List<Profile> profiles,
    DateTime weekStart,
    String? currentId,
  ) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Text(
                  'Siapa yang ${job.name.toLowerCase()}?',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              for (final p in profiles)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: MemberAvatar(
                    profileId: p.id,
                    name: p.name,
                    size: 40,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  trailing: p.id == currentId
                      ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, p.id),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
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
    final scheme = Theme.of(context).colorScheme;
    final weekStart = JobAssignment.weekStartFor(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addJob(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Pekerjaan'),
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
                stream:
                    FirestoreService.instance.watchAssignmentsForWeek(weekStart),
                builder: (context, assignSnap) {
                  final assigned = {
                    for (final a in assignSnap.data ?? const <JobAssignment>[])
                      a.jobTemplateId: a.assignedProfileId,
                  };
                  if (templates.isEmpty) {
                    return const SoftEmpty(
                      icon: Icons.playlist_add_rounded,
                      message:
                          'Belum ada pekerjaan.\nTekan tombol di bawah untuk menambah.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      const SectionHeading(
                        icon: Icons.repeat_rounded,
                        title: 'Giliran minggu ini',
                      ),
                      for (final job in templates)
                        _AdminJobCard(
                          job: job,
                          assignedId: assigned[job.id],
                          profiles: profiles,
                          onAssign: () => _assign(
                            context,
                            job,
                            profiles,
                            weekStart,
                            assigned[job.id],
                          ),
                          onDelete: () => FirestoreService.instance
                              .deleteJobTemplate(job.id),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text(
                          'Jadwal orang lain dibatalkan langsung dari tab Kalender.',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
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

class _AdminJobCard extends StatelessWidget {
  final JobTemplate job;
  final String? assignedId;
  final List<Profile> profiles;
  final VoidCallback onAssign;
  final VoidCallback onDelete;

  const _AdminJobCard({
    required this.job,
    required this.assignedId,
    required this.profiles,
    required this.onAssign,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String? assignedName;
    for (final p in profiles) {
      if (p.id == assignedId) assignedName = p.name;
    }

    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onAssign,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (assignedName == null)
                      SoftPill(
                        text: 'Ketuk untuk atur',
                        color: scheme.error,
                        icon: Icons.touch_app_rounded,
                      )
                    else
                      Row(
                        children: [
                          MemberAvatar(
                            profileId: assignedId!,
                            name: assignedName,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            assignedName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forMember(context, assignedId!),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus pekerjaan',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded,
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
