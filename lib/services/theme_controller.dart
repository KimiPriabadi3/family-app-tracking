import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light or dark, chosen per phone.
///
/// Follows the phone's own setting until someone taps the switch, which is
/// how a phone in dark mode ended up showing the app dark brown while every
/// screenshot on GitHub was light.
class ThemeController {
  static const _key = 'theme_mode';
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_key),
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Storage unavailable: follow the phone.
    }
  }

  static Future<void> set(ThemeMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.name);
    } catch (_) {}
  }
}
