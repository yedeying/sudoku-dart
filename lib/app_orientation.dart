import 'package:flutter/services.dart';

/// 移动端只允许竖屏。桌面/Web 窗口仍可拉伸，界面走同一套手机栏。
class AppOrientation {
  static const portraits = [DeviceOrientation.portraitUp];

  static Future<void> lockPortrait() {
    return SystemChrome.setPreferredOrientations(portraits);
  }
}
