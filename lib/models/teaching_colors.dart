import 'package:flutter/material.dart';

class TeachingColors {
  static const start = Color(0xFF2E7D32);
  static const end = Color(0xFFF9A825);
  static const node = Color(0xFF1565C0);
  static const elimCell = Color(0xFFFFF59D);
  static const elimCand = Color(0xFFC62828);
  static const pattern = Color(0xFFBBDEFB);
  static const cover = Color(0xFFC8E6C9);
  static const house = Color(0xFFD6E6F2);

  /// Nishio 等反证法里「假设推导后被排空候选的矛盾格」，
  /// 与真正的删除目标（elimCand，红）区分开，避免误读成「这就是答案」。
  static const contradiction = Color(0xFF6A1B9A);
}
