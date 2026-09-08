import 'package:cloud_firestore/cloud_firestore.dart';

/// A short broadcast note any family member can post so the rest of the
/// household sees it without anyone having to ask (e.g. "token listrik habis").
class Announcement {
  final String id;
  final String authorProfileId;
  final String message;
  final DateTime createdAt;

  const Announcement({
    required this.id,
    required this.authorProfileId,
    required this.message,
    required this.createdAt,
  });

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Announcement(
      id: doc.id,
      authorProfileId: data['authorProfileId'] as String,
      message: data['message'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorProfileId': authorProfileId,
        'message': message,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
