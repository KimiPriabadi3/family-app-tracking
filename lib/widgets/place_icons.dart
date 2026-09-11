import 'package:flutter/material.dart';

import '../models/family_place.dart';
import '../models/profile.dart';

IconData placeIconData(PlaceIcon icon) {
  switch (icon) {
    case PlaceIcon.home:
      return Icons.home_rounded;
    case PlaceIcon.school:
      return Icons.backpack_rounded;
    case PlaceIcon.campus:
      return Icons.school_rounded;
    case PlaceIcon.work:
      return Icons.work_rounded;
    case PlaceIcon.study:
      return Icons.menu_book_rounded;
    case PlaceIcon.mosque:
      return Icons.mosque_rounded;
    case PlaceIcon.sport:
      return Icons.sports_soccer_rounded;
    case PlaceIcon.shop:
      return Icons.shopping_bag_rounded;
    case PlaceIcon.family:
      return Icons.favorite_rounded;
    case PlaceIcon.other:
      return Icons.place_rounded;
  }
}

IconData iconForStatus(PresenceStatus status) {
  switch (status) {
    case PresenceStatus.home:
      return Icons.home_rounded;
    case PresenceStatus.campus:
      return Icons.school_rounded;
    case PresenceStatus.office:
      return Icons.work_rounded;
    case PresenceStatus.travelling:
      return Icons.directions_walk_rounded;
    case PresenceStatus.sleeping:
      return Icons.bedtime_rounded;
    case PresenceStatus.other:
      return Icons.explore_rounded;
    case PresenceStatus.place:
      return Icons.place_rounded;
  }
}

/// The icon beside someone's status: their own place's picture when the
/// status names one of their places.
IconData iconForProfileStatus(Profile profile) =>
    profile.status == PresenceStatus.place && profile.statusIcon != null
        ? placeIconData(PlaceIconX.fromName(profile.statusIcon))
        : iconForStatus(profile.status);
