import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  final String id;
  final String ownerProfileId;
  final DateTime date;
  final String title;
  final String? note;
  final bool cancelled;
  final DateTime createdAt;

  const CalendarEvent({
    required this.id,
    required this.ownerProfileId,
    required this.date,
    required this.title,
    this.note,
    this.cancelled = false,
    required this.createdAt,
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
