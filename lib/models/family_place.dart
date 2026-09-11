import 'profile.dart';

/// Radius defaults to 120 m because phone GPS is routinely 20–50 m out; a 50 m
/// circle makes the status flicker in and out as the fix drifts.
const int kDefaultPlaceRadius = 120;
const int kMinPlaceRadius = 100;
const int kMaxPlaceRadius = 300;

/// Android allows 100 geofences per app; ten is already more places than one
/// person goes to routinely, and keeps the Tempatku list readable.
const int kMaxPlaces = 10;

/// The picture beside a place's name. Stored by name, so reordering is safe.
enum PlaceIcon { home, school, campus, work, study, mosque, sport, shop, family, other }

extension PlaceIconX on PlaceIcon {
  String get label {
    switch (this) {
      case PlaceIcon.home:
        return 'Rumah';
      case PlaceIcon.school:
        return 'Sekolah';
      case PlaceIcon.campus:
        return 'Kampus';
      case PlaceIcon.work:
        return 'Kantor';
      case PlaceIcon.study:
        return 'Les';
      case PlaceIcon.mosque:
        return 'Ibadah';
      case PlaceIcon.sport:
        return 'Olahraga';
      case PlaceIcon.shop:
        return 'Belanja';
      case PlaceIcon.family:
        return 'Keluarga';
      case PlaceIcon.other:
        return 'Lainnya';
    }
  }

  /// The fixed status that means the same thing, so a hand-set "Di rumah" is
  /// recognised as claiming the place called "Rumah" when the member leaves.
  PresenceStatus? get matchingStatus {
    switch (this) {
      case PlaceIcon.home:
        return PresenceStatus.home;
      case PlaceIcon.school:
      case PlaceIcon.campus:
        return PresenceStatus.campus;
      case PlaceIcon.work:
        return PresenceStatus.office;
      default:
        return null;
    }
  }

  static PlaceIcon fromName(String? name) => PlaceIcon.values
      .firstWhere((i) => i.name == name, orElse: () => PlaceIcon.other);
}

/// A spot the member marked, so arriving there can set their status.
///
/// The coordinates never leave the phone: the family only needs the resulting
/// status ("Adek di Bimbel Primagama"), not where the tutoring centre is. The
/// name does travel, because it is what the status says. See PRODUCT.md.
class FamilyPlace {
  final String id;
  final String name;
  final PlaceIcon icon;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final DateTime setAt;

  /// GPS accuracy at the moment it was marked. Null means it was picked on the
  /// map rather than stood in.
  final double? accuracyMeters;

  const FamilyPlace({
    required this.id,
    required this.name,
    required this.icon,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = kDefaultPlaceRadius,
    required this.setAt,
    this.accuracyMeters,
  });

  bool get pickedOnMap => accuracyMeters == null;

  FamilyPlace copyWith({
    String? name,
    PlaceIcon? icon,
    int? radiusMeters,
  }) =>
      FamilyPlace(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        setAt: setAt,
        accuracyMeters: accuracyMeters,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon.name,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'setAt': setAt.millisecondsSinceEpoch,
        'accuracyMeters': accuracyMeters,
      };

  factory FamilyPlace.fromJson(Map<String, dynamic> json) => FamilyPlace(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: PlaceIconX.fromName(json['icon'] as String?),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusMeters:
            (json['radiusMeters'] as num?)?.toInt() ?? kDefaultPlaceRadius,
        setAt: DateTime.fromMillisecondsSinceEpoch(
          (json['setAt'] as num?)?.toInt() ?? 0,
        ),
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      );
}

/// Whether [profile]'s current status is a claim to be at [place] — either
/// the place by name, or a hand-set fixed status meaning the same thing.
bool statusClaimsPlace(Profile profile, FamilyPlace place) {
  if (profile.status == PresenceStatus.place) {
    return profile.statusPlace == place.name;
  }
  return profile.status == place.icon.matchingStatus;
}
