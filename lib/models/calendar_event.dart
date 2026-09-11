import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  final String id;
  final String ownerProfileId;
  final DateTime date;
  final String title;
  final String? note;
  final bool cancelled;
  final DateTime createdAt;

  /// Recorded so a background check can tell a fresh cancellation from an old
  /// one, and say who called it off.
  final DateTime? cancelledAt;
  final String? cancelledByProfileId;

  const CalendarEvent({
    required this.id,
    required this.ownerProfileId,
    required this.date,
    required this.title,
    this.note,
    this.cancelled = false,
    required this.createdAt,
    this.cancelledAt,
    this.cancelledByProfileId,
  });

  factory CalendarEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CalendarEvent(
      id: doc.id,
      ownerProfileId: data['ownerProfileId'] as String,
      date: (data['date'] as Timestamp).toDate(),
      title: data['title'] as String,
      note: data['note'] as String?,
      cancelled: data['cancelled'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      cancelledByProfileId: data['cancelledByProfileId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerProfileId': ownerProfileId,
        'date': Timestamp.fromDate(date),
        'title': title,
        'note': note,
        'cancelled': cancelled,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
