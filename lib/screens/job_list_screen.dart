import 'package:flutter/material.dart';

import '../models/job_assignment.dart';
import '../models/job_template.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/soft.dart';

/// This week's chores. Your own turns are highlighted in sunny yellow.
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
              return const SoftEmpty(
                icon: Icons.cleaning_services_rounded,
                message:
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
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    SectionHeading(
                      icon: Icons.date_range_rounded,
                      title: 'Minggu ${_weekLine(weekStart)}',
                      trailing: mine == 0 ? null : '$mine giliranmu',
                    ),
                    for (final job in templates)
                      _JobCard(
                        job: job,
                        assignedId: assigned[job.id],
                        assignedName: assigned[job.id] == null
                            ? null
                            : names[assigned[job.id]] ?? assigned[job.id],
                        isMine: assigned[job.id] == profileId,
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

class _JobCard extends StatelessWidget {
  final JobTemplate job;
  final String? assignedId;
  final String? assignedName;
  final bool isMine;

  const _JobCard({
    required this.job,
    required this.assignedId,
    required this.assignedName,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SoftCard(
      color: isMine ? scheme.secondaryContainer : null,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isMine
                        ? scheme.onSecondaryContainer
                        : scheme.onSurface,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(height: 8),
                  const SoftPill(
                    text: 'Giliranmu minggu ini',
                    color: AppColors.coralDeep,
                    icon: Icons.star_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (assignedName == null)
            SoftPill(
              text: 'Belum diatur',
              color: scheme.error,
              icon: Icons.help_outline_rounded,
            )
          else
            Column(
              children: [
                MemberAvatar(
                  profileId: assignedId!,
                  name: assignedName!,
                  size: 40,
                ),
                const SizedBox(height: 6),
                Text(
                  assignedName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forMember(context, assignedId!),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
