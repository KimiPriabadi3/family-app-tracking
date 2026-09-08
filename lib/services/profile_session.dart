import 'package:shared_preferences/shared_preferences.dart';

/// There is no real account login — each device just remembers which
/// family member is using it. The admin (developer) profile is the only
/// one allowed to cancel others' schedule entries or edit the job list.
class ProfileSession {
  static const String adminProfileId = 'aku';
  static const _prefsKey = 'selected_profile_id';

  static Future<String?> getSelectedProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  static Future<void> setSelectedProfileId(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, profileId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static bool isAdmin(String profileId) => profileId == adminProfileId;
}
