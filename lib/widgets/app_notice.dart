import 'package:flutter/material.dart';

/// 短提示贴在 AppBar 下方，避免盖住底部提示框按钮。
void showAppNotice(BuildContext context, String message) {
  final media = MediaQuery.of(context);
  final top = media.padding.top + kToolbarHeight + 8;
  final bottom = (media.size.height - top - 64).clamp(16.0, media.size.height);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
      ),
    );
}
