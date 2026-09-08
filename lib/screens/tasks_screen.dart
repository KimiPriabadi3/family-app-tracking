import 'package:flutter/material.dart';

import '../widgets/admin_action.dart';
import 'errand_list_screen.dart';
import 'job_list_screen.dart';

class TasksScreen extends StatelessWidget {
  final String profileId;

  const TasksScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TUGAS'),
          actions: [AdminAction(profileId: profileId)],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'PIKET RUMAH'),
              Tab(text: 'TITIP BELI'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            JobListScreen(profileId: profileId),
            ErrandListScreen(profileId: profileId),
          ],
        ),
      ),
    );
  }
}
