import 'package:flutter/material.dart';

/// PC 和手机共用的竖屏栏：内容不超过手机宽，两侧留空。
class PhoneFrame extends StatelessWidget {
  static const maxWidth = 430.0;

  final Widget child;
  final VoidCallback? onBackgroundTap;

  const PhoneFrame({
    super.key,
    required this.child,
    this.onBackgroundTap,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          if (onBackgroundTap != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onBackgroundTap,
              ),
            ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
