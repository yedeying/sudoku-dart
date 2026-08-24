import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

enum AccentId { blue, teal, amber, rose }

class ThemeController extends ChangeNotifier {
  static const _prefKey = 'accentId';

  AccentId accentId = AccentId.blue;

  static Color colorFor(AccentId id) {
    switch (id) {
      case AccentId.blue:
        return const Color(0xFF1565C0);
      case AccentId.teal:
        return const Color(0xFF00838F);
      case AccentId.amber:
        return const Color(0xFFEF6C00);
      case AccentId.rose:
        return const Color(0xFFC2185B);
    }
  }

  ThemeData get light => AppTheme.lightFor(colorFor(accentId));

  ThemeData get dark => AppTheme.darkFor(colorFor(accentId));

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return;
      final match = AccentId.values.where((id) => id.name == raw);
      if (match.isEmpty || match.first == accentId) return;
      accentId = match.first;
      notifyListeners();
    } catch (_) {
      // Preference read failed — stay on default blue.
    }
  }

  Future<void> setAccent(AccentId id) async {
    if (id == accentId) return;
    accentId = id;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, id.name);
    } catch (_) {
      // Persistence is best-effort; UI already reflects the new accent.
    }
  }
}
