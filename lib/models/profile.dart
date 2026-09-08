import 'package:cloud_firestore/cloud_firestore.dart';

/// The three fixed household members. Doc id in Firestore's `profiles`
/// collection matches these ids exactly.
enum ProfileId { bunda, aku, adek }

/// Display names for the three fixed household members, used to seed
/// Firestore on first run and to render the profile picker.
const Map<String, String> kDefaultProfileNames = {
  'bunda': 'Bunda',
  'aku': 'Aku',
  'adek': 'Adek',
};

extension ProfileIdX on ProfileId {
  String get id => name;

  static ProfileId fromId(String id) =>
      ProfileId.values.firstWhere((p) => p.id == id, orElse: () => ProfileId.aku);
}

enum PresenceStatus { home, campus, office, sleeping, other }

extension PresenceStatusX on PresenceStatus {
  String get label {
    switch (this) {
      case PresenceStatus.home:
        return 'Di rumah';
      case PresenceStatus.campus:
        return 'Di kampus';
      case PresenceStatus.office:
        return 'Di kantor';
      case PresenceStatus.sleeping:
        return 'Tidur';
      case PresenceStatus.other:
        return 'Lainnya';
    }
  }

  static PresenceStatus fromName(String? name) => PresenceStatus.values
      .firstWhere((s) => s.name == name, orElse: () => PresenceStatus.other);
}

class Profile {
  final String id;
  final String name;
  final bool isAdmin;
  final PresenceStatus status;
  final String? statusNote;
  final DateTime? statusUpdatedAt;
  final double? lastLatitude;
  final double? lastLongitude;
  final DateTime? lastLocationAt;
  final bool locationSharingEnabled;

  const Profile({
    required this.id,
    required this.name,
    required this.isAdmin,
    this.status = PresenceStatus.other,
    this.statusNote,
    this.statusUpdatedAt,
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationAt,
    this.locationSharingEnabled = false,
  });

  bool get hasLocation => lastLatitude != null && lastLongitude != null;

  factory Profile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Profile(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      isAdmin: data['isAdmin'] as bool? ?? false,
      status: PresenceStatusX.fromName(data['status'] as String?),
      statusNote: data['statusNote'] as String?,
      statusUpdatedAt: (data['statusUpdatedAt'] as Timestamp?)?.toDate(),
      lastLatitude: (data['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (data['lastLongitude'] as num?)?.toDouble(),
      lastLocationAt: (data['lastLocationAt'] as Timestamp?)?.toDate(),
      locationSharingEnabled: data['locationSharingEnabled'] as bool? ?? false,
    );
  }
}
