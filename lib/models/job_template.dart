import 'package:cloud_firestore/cloud_firestore.dart';

/// A recurring household chore (e.g. "Sapu rumah", "Pel rumah") that
/// rotates between family members week to week. Managed by the admin.
class JobTemplate {
  final String id;
  final String name;
  final String? description;
  final int order;

  const JobTemplate({
    required this.id,
    required this.name,
    this.description,
    this.order = 0,
  });

  factory JobTemplate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return JobTemplate(
      id: doc.id,
      name: data['name'] as String,
      description: data['description'] as String?,
      order: data['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'order': order,
      };
}
