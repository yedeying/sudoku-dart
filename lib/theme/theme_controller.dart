import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/board_markup.dart';
import 'app_theme.dart';

enum AccentId {
  blue,
  red,
  green,
  purple,
  teal,
  orange,
  rose,
  indigo,
  sky,
  gold,
}

class ThemeController extends ChangeNotifier {
  static const _prefKey = 'accentId';

  AccentId accentId = AccentId.blue;

  /// 与标记色同一套色相，给选择器和棋盘标记看。
  static Color swatchFor(AccentId id) {
    switch (id) {
      case AccentId.blue:
        return MarkupPalette.blue;
      case AccentId.red:
        return MarkupPalette.red;
      case AccentId.green:
        return MarkupPalette.green;
      case AccentId.purple:
        return MarkupPalette.purple;
      case AccentId.teal:
        return MarkupPalette.teal;
      case AccentId.orange:
        return MarkupPalette.orange;
      case AccentId.rose:
        return MarkupPalette.rose;
      case AccentId.indigo:
        return MarkupPalette.indigo;
      case AccentId.sky:
        return MarkupPalette.skyBlue;
      case AccentId.gold:
        return MarkupPalette.gold;
    }
  }

  /// 主题强调色：同色相，过浅的金/天蓝会略加深，避免按钮贴在白底上。
  static Color colorFor(AccentId id) => _chrome(swatchFor(id));

  static Color _chrome(Color ink) {
    const surface = Color(0xFFFAFAFA);
    var hsl = HSLColor.fromColor(ink);
    var color = ink;
    while (hsl.lightness > 0.22 && _contrast(color, surface) < 2.05) {
      hsl = hsl.withLightness((hsl.lightness - 0.03).clamp(0.0, 1.0));
      color = hsl.toColor();
    }
    return color;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  ThemeData get light => AppTheme.lightFor(colorFor(accentId));

  ThemeData get dark => AppTheme.darkFor(colorFor(accentId));

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_prefKey);
      if (raw == null) return;
      if (raw == 'amber') raw = 'orange';
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
