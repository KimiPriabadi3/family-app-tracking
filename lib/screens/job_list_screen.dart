import 'package:flutter/material.dart';

import '../models/job_assignment.dart';
import '../models/job_template.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';

/// Read-only view of who does what this week, shown as a sub-tab of
/// TasksScreen. Editing the job list and rotation happens in the admin panel.
class JobListScreen extends StatelessWidget {
  final String profileId;

  const JobListScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    final weekStart = JobAssignment.weekStartFor(DateTime.now());

    return StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, profileSnap) {
          final profileNames = {
            for (final p in profileSnap.data ?? const <Profile>[]) p.id: p.name,
          };
          return StreamBuilder<List<JobTemplate>>(
            stream: FirestoreService.instance.watchJobTemplates(),
            builder: (context, templateSnap) {
              final templates = templateSnap.data ?? const <JobTemplate>[];
              if (templateSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (templates.isEmpty) {
                return const Center(child: Text('Belum ada job list. Minta admin menambahkan.'));
              }
              return StreamBuilder<List<JobAssignment>>(
                stream: FirestoreService.instance.watchAssignmentsForWeek(weekStart),
                builder: (context, assignSnap) {
                  final assignments = {
                    for (final a in assignSnap.data ?? const <JobAssignment>[])
                      a.jobTemplateId: a.assignedProfileId,
                  };
                  return ListView.builder(
                    itemCount: templates.length,
                    itemBuilder: (context, i) {
                      final job = templates[i];
                      final assignedId = assignments[job.id];
                      final assignedName =
                          assignedId != null ? (profileNames[assignedId] ?? assignedId) : null;
                      final isMine = assignedId == profileId;
                      return ListTile(
                        leading: Icon(
                          Icons.cleaning_services,
                          color: isMine ? Theme.of(context).colorScheme.primary : null,
                        ),
                        title: Text(job.name),
                        subtitle: Text(job.description ?? ''),
                        trailing: Text(
                          assignedName ?? 'Belum ditentukan',
                          style: isMine ? const TextStyle(fontWeight: FontWeight.bold) : null,
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
    );
  }
}
