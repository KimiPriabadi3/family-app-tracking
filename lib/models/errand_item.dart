import 'package:cloud_firestore/cloud_firestore.dart';

/// An item on the shared shopping list — anyone can add one, and whoever
/// happens to be out can check it off.
class ErrandItem {
  final String id;
  final String name;
  final String requestedByProfileId;
  final bool done;
  final String? doneByProfileId;
  final DateTime createdAt;
  final DateTime? doneAt;

  const ErrandItem({
    required this.id,
    required this.name,
    required this.requestedByProfileId,
    this.done = false,
    this.doneByProfileId,
    required this.createdAt,
    this.doneAt,
  });

  factory ErrandItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ErrandItem(
      id: doc.id,
      name: data['name'] as String,
      requestedByProfileId: data['requestedByProfileId'] as String,
      done: data['done'] as bool? ?? false,
      doneByProfileId: data['doneByProfileId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      doneAt: (data['doneAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'requestedByProfileId': requestedByProfileId,
        'done': done,
        'doneByProfileId': doneByProfileId,
        'createdAt': Timestamp.fromDate(createdAt),
        'doneAt': doneAt == null ? null : Timestamp.fromDate(doneAt!),
      };
}
