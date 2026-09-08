import 'package:flutter/material.dart';

import '../models/job_assignment.dart';
import '../models/job_template.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../theme/register_theme.dart';
import '../widgets/register.dart';

/// The amendment page: only the admin reaches it, and only to edit the duty
/// list and set who holds each turn this week.
class AdminScreen extends StatelessWidget {
  final String profileId;

  const AdminScreen({super.key, required this.profileId});

  Future<void> _addJob(BuildContext context) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('TAMBAH PEKERJAAN'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nama pekerjaan',
            hintText: 'misal: sapu rumah',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('TAMBAH'),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: scheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: FieldLabel('Giliran ${job.name}', color: scheme.onPrimary),
              ),
              for (final p in profiles)
                InkWell(
                  onTap: () => Navigator.pop(sheetContext, p.id),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: scheme.outline)),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: RegisterType.value.copyWith(
                              color: RegisterInk.forMember(context, p.id),
                            ),
                          ),
                        ),
                        if (p.id == currentId)
                          FieldLabel('sekarang', color: scheme.primary),
                      ],
                    ),
                  ),
                ),
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
      appBar: AppBar(title: const Text('ADMIN')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addJob(context),
        icon: const Icon(Icons.add),
        label: const Text('PEKERJAAN'),
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
                    return const RegisterEmpty(
                      'Belum ada pekerjaan.\nTekan tombol di bawah untuk menambah.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                        child: FieldLabel('Daftar piket dan giliran minggu ini'),
                      ),
                      RegisterSheet(
                        child: Column(
                          children: [
                            const RegisterHeaderStrip(
                              columns: ['Pekerjaan', 'Giliran', ''],
                              flex: [4, 3, 2],
                            ),
                            for (var i = 0; i < templates.length; i++)
                              _AdminJobRow(
                                job: templates[i],
                                assignedId: assigned[templates[i].id],
                                profiles: profiles,
                                last: i == templates.length - 1,
                                onAssign: () => _assign(
                                  context,
                                  templates[i],
                                  profiles,
                                  weekStart,
                                  assigned[templates[i].id],
                                ),
                                onDelete: () => FirestoreService.instance
                                    .deleteJobTemplate(templates[i].id),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                        child: Text(
                          'Jadwal orang lain dibatalkan langsung dari tab Kalender.',
                          style: RegisterType.annotation
                              .copyWith(color: scheme.onSurfaceVariant),
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

class _AdminJobRow extends StatelessWidget {
  final JobTemplate job;
  final String? assignedId;
  final List<Profile> profiles;
  final bool last;
  final VoidCallback onAssign;
  final VoidCallback onDelete;

  const _AdminJobRow({
    required this.job,
    required this.assignedId,
    required this.profiles,
    required this.last,
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

    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 8, 16),
              child: Text(
                job.name,
                style: RegisterType.value.copyWith(color: scheme.onSurface),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: onAssign,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: assignedName == null
                    ? FieldLabel('atur giliran', color: scheme.error)
                    : Text(
                        assignedName,
                        style: RegisterType.valueStrong.copyWith(
                          fontSize: 15,
                          color: RegisterInk.forMember(context, assignedId!),
                        ),
                      ),
              ),
            ),
          ),
          InkWell(
            onTap: onDelete,
            child: Container(
              width: 72,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: scheme.outline)),
              ),
              child: FieldLabel('Hapus', color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
