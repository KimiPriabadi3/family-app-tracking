import 'profile.dart';

/// Radius defaults to 120 m because phone GPS is routinely 20–50 m out; a 50 m
/// circle makes the status flicker in and out as the fix drifts.
const int kDefaultPlaceRadius = 120;
const int kMinPlaceRadius = 100;
const int kMaxPlaceRadius = 300;

/// Only these three statuses describe a fixed place you can arrive at.
const List<PresenceStatus> kPlaceableStatuses = [
  PresenceStatus.home,
  PresenceStatus.campus,
  PresenceStatus.office,
];

/// A spot the member marked, so arriving there can set their status.
///
/// These never leave the phone: the family only needs the resulting status
/// ("Bunda di kantor"), not the coordinates of the office. See PRODUCT.md.
class FamilyPlace {
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final DateTime setAt;

  /// GPS accuracy at the moment it was marked, kept so the UI can warn that a
  /// place was pinned on a poor fix.
  final double? accuracyMeters;

  const FamilyPlace({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = kDefaultPlaceRadius,
    required this.setAt,
    this.accuracyMeters,
  });

  FamilyPlace copyWith({int? radiusMeters}) => FamilyPlace(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        setAt: setAt,
        accuracyMeters: accuracyMeters,
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'setAt': setAt.millisecondsSinceEpoch,
        'accuracyMeters': accuracyMeters,
      };

  factory FamilyPlace.fromJson(Map<String, dynamic> json) => FamilyPlace(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusMeters: (json['radiusMeters'] as num?)?.toInt() ?? kDefaultPlaceRadius,
        setAt: DateTime.fromMillisecondsSinceEpoch(
          (json['setAt'] as num?)?.toInt() ?? 0,
        ),
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      );
}
