import 'package:flutter/material.dart';

import '../models/job_assignment.dart';
import '../models/job_template.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../theme/register_theme.dart';
import '../widgets/register.dart';

/// This week's duty roster. Gold marks one thing only: whose turn it is right
/// now, and it is reserved for the row belonging to whoever is reading.
class JobListScreen extends StatelessWidget {
  final String profileId;

  const JobListScreen({super.key, required this.profileId});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  String _weekLine(DateTime start) {
    final end = start.add(const Duration(days: 6));
    return '${start.day} ${_months[start.month - 1]} – ${end.day} ${_months[end.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weekStart = JobAssignment.weekStartFor(DateTime.now());

    return StreamBuilder<List<Profile>>(
      stream: FirestoreService.instance.watchProfiles(),
      builder: (context, profileSnap) {
        final names = {
          for (final p in profileSnap.data ?? const <Profile>[]) p.id: p.name,
        };
        return StreamBuilder<List<JobTemplate>>(
          stream: FirestoreService.instance.watchJobTemplates(),
          builder: (context, templateSnap) {
            if (templateSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final templates = templateSnap.data ?? const <JobTemplate>[];
            if (templates.isEmpty) {
              return const RegisterEmpty(
                'Daftar piket belum diisi.\nMinta admin menambahkannya lewat menu Admin.',
              );
            }
            return StreamBuilder<List<JobAssignment>>(
              stream: FirestoreService.instance.watchAssignmentsForWeek(weekStart),
              builder: (context, assignSnap) {
                final assigned = {
                  for (final a in assignSnap.data ?? const <JobAssignment>[])
                    a.jobTemplateId: a.assignedProfileId,
                };
                final mine =
                    templates.where((j) => assigned[j.id] == profileId).length;

                return ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                      child: Row(
                        children: [
                          FieldLabel('Minggu ${_weekLine(weekStart)}'),
                          const Spacer(),
                          FieldLabel(
                            mine == 0 ? 'tidak ada giliranmu' : '$mine giliranmu',
                            color: mine == 0 ? scheme.onSurfaceVariant : scheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                    RegisterSheet(
                      child: Column(
                        children: [
                          const RegisterHeaderStrip(
                            columns: ['Pekerjaan', 'Giliran'],
                            flex: [5, 3],
                          ),
                          for (var i = 0; i < templates.length; i++)
                            _JobRow(
                              job: templates[i],
                              assignedId: assigned[templates[i].id],
                              assignedName: assigned[templates[i].id] == null
                                  ? null
                                  : names[assigned[templates[i].id]] ??
                                      assigned[templates[i].id],
                              isMine: assigned[templates[i].id] == profileId,
                              last: i == templates.length - 1,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                      child: Text(
                        'Giliran berganti tiap minggu dan diatur admin, jadi minggu '
                        'depan baris ini berubah.',
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
    );
  }
}

class _JobRow extends StatelessWidget {
  final JobTemplate job;
  final String? assignedId;
  final String? assignedName;
  final bool isMine;
  final bool last;

  const _JobRow({
    required this.job,
    required this.assignedId,
    required this.assignedName,
    required this.isMine,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = assignedId == null
        ? scheme.onSurfaceVariant
        : RegisterInk.forMember(context, assignedId!);

    return Container(
      decoration: BoxDecoration(
        color: isMine ? RegisterInk.gold.withValues(alpha: 0.22) : null,
        border: last ? null : Border(bottom: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.name,
                  style: RegisterType.value.copyWith(color: scheme.onSurface),
                ),
                if (job.description != null && job.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    job.description!,
                    style: RegisterType.annotation
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (isMine) ...[
                  const SizedBox(height: 6),
                  FieldLabel('giliranmu minggu ini', color: RegisterInk.ink),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: assignedName == null
                  ? FieldLabel('belum diatur', color: scheme.error)
                  : Text(
                      assignedName!,
                      style: RegisterType.valueStrong.copyWith(color: ink, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
