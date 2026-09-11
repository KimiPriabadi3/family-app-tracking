import 'package:cloud_firestore/cloud_firestore.dart';

/// The three fixed household members. Doc id in Firestore's `profiles`
/// collection matches these ids exactly.
enum ProfileId { bunda, aku, adek }

/// Display names for the three fixed household members, used to seed
/// Firestore on first run and to render the profile picker.
const Map<String, String> kDefaultProfileNames = {
  'bunda': 'Bunda',
  'aku': 'Mas',
  'adek': 'Adek',
};

extension ProfileIdX on ProfileId {
  String get id => name;

  static ProfileId fromId(String id) =>
      ProfileId.values.firstWhere((p) => p.id == id, orElse: () => ProfileId.aku);
}

/// `place` means "at one of the member's own named places"; the name travels
/// alongside in [Profile.statusPlace].
enum PresenceStatus { home, campus, office, travelling, sleeping, other, place }

extension PresenceStatusX on PresenceStatus {
  String get label {
    switch (this) {
      case PresenceStatus.home:
        return 'Di rumah';
      case PresenceStatus.campus:
        return 'Di kampus';
      case PresenceStatus.office:
        return 'Di kantor';
      case PresenceStatus.travelling:
        return 'Di jalan';
      case PresenceStatus.sleeping:
        return 'Tidur';
      case PresenceStatus.other:
        return 'Lainnya';
      case PresenceStatus.place:
        return 'Di tempatnya';
    }
  }

  /// Statuses that describe being at somewhere you can arrive at.
  bool get isSomewhere =>
      this == PresenceStatus.home ||
      this == PresenceStatus.campus ||
      this == PresenceStatus.office ||
      this == PresenceStatus.place;

  static PresenceStatus fromName(String? name) => PresenceStatus.values
      .firstWhere((s) => s.name == name, orElse: () => PresenceStatus.other);
}

/// Whether a status was typed by the member or worked out from their location.
/// The distinction is what lets a hand-set status survive a geofence event.
enum StatusSource { manual, auto }

extension StatusSourceX on StatusSource {
  static StatusSource fromName(String? name) => StatusSource.values
      .firstWhere((s) => s.name == name, orElse: () => StatusSource.manual);
}

class Profile {
  final String id;
  final String name;
  final bool isAdmin;
  final PresenceStatus status;
  final String? statusNote;
  final DateTime? statusUpdatedAt;
  final StatusSource statusSource;

  /// Name and icon of the member's own place when [status] is
  /// [PresenceStatus.place] — "Bimbel Primagama", not its coordinates.
  final String? statusPlace;
  final String? statusIcon;
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
    this.statusSource = StatusSource.manual,
    this.statusPlace,
    this.statusIcon,
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationAt,
    this.locationSharingEnabled = false,
  });

  bool get hasLocation => lastLatitude != null && lastLongitude != null;

  bool get _atNamedPlace =>
      status == PresenceStatus.place && (statusPlace?.isNotEmpty ?? false);

  /// What the family reads: "Di Bimbel Primagama", or the fixed label.
  String get statusLabel => _atNamedPlace ? 'Di $statusPlace' : status.label;

  /// Identity of the status for "did it change?" checks. Two different places
  /// are different statuses even though both are [PresenceStatus.place].
  String get statusKey =>
      _atNamedPlace ? 'place:$statusPlace' : status.name;

  /// Rebuilding a Profile by hand drops any field the caller forgot, which is
  /// how new fields quietly vanish. Everything that copies a Profile goes
  /// through here instead.
  Profile copyWith({
    String? name,
    bool? isAdmin,
    PresenceStatus? status,
    String? statusNote,
    bool clearStatusNote = false,
    DateTime? statusUpdatedAt,
    StatusSource? statusSource,
    String? statusPlace,
    String? statusIcon,
    bool clearStatusPlace = false,
    double? lastLatitude,
    double? lastLongitude,
    DateTime? lastLocationAt,
    bool? locationSharingEnabled,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      isAdmin: isAdmin ?? this.isAdmin,
      status: status ?? this.status,
      statusNote: clearStatusNote ? null : (statusNote ?? this.statusNote),
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      statusSource: statusSource ?? this.statusSource,
      statusPlace:
          clearStatusPlace ? null : (statusPlace ?? this.statusPlace),
      statusIcon: clearStatusPlace ? null : (statusIcon ?? this.statusIcon),
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastLocationAt: lastLocationAt ?? this.lastLocationAt,
      locationSharingEnabled:
          locationSharingEnabled ?? this.locationSharingEnabled,
    );
  }

  factory Profile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Profile(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      isAdmin: data['isAdmin'] as bool? ?? false,
      status: PresenceStatusX.fromName(data['status'] as String?),
      statusNote: data['statusNote'] as String?,
      statusUpdatedAt: (data['statusUpdatedAt'] as Timestamp?)?.toDate(),
      statusSource: StatusSourceX.fromName(data['statusSource'] as String?),
      statusPlace: data['statusPlace'] as String?,
      statusIcon: data['statusIcon'] as String?,
      lastLatitude: (data['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (data['lastLongitude'] as num?)?.toDouble(),
      lastLocationAt: (data['lastLocationAt'] as Timestamp?)?.toDate(),
      locationSharingEnabled: data['locationSharingEnabled'] as bool? ?? false,
    );
  }
}
