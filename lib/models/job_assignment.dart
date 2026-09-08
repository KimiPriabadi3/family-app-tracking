import 'package:cloud_firestore/cloud_firestore.dart';

/// Who is assigned to a given [JobTemplate] for one rolling week.
/// [weekStart] is always normalized to the Monday of that week, midnight.
class JobAssignment {
  final String id;
  final String jobTemplateId;
  final String assignedProfileId;
  final DateTime weekStart;

  const JobAssignment({
    required this.id,
    required this.jobTemplateId,
    required this.assignedProfileId,
    required this.weekStart,
  });

  static DateTime weekStartFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  factory JobAssignment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return JobAssignment(
      id: doc.id,
      jobTemplateId: data['jobTemplateId'] as String,
      assignedProfileId: data['assignedProfileId'] as String,
      weekStart: (data['weekStart'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'jobTemplateId': jobTemplateId,
        'assignedProfileId': assignedProfileId,
        'weekStart': Timestamp.fromDate(weekStart),
      };
}
