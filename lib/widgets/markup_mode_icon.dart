import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/board_markup.dart';

/// 标记模式圆钮上的 SVG：格子 / 候选 / 强链 / 弱链 / AIC。
class MarkupModeIcon extends StatelessWidget {
  final MarkupMode mode;
  final Color color;
  final double size;

  const MarkupModeIcon({
    super.key,
    required this.mode,
    required this.color,
    this.size = 18,
  });

  static const _assets = {
    MarkupMode.cellColor: 'assets/icons/markup_cell.svg',
    MarkupMode.candidateColor: 'assets/icons/markup_candidate.svg',
    MarkupMode.strong: 'assets/icons/markup_strong.svg',
    MarkupMode.weak: 'assets/icons/markup_weak.svg',
    MarkupMode.autoStrong: 'assets/icons/markup_aic.svg',
  };

  static const _labels = {
    MarkupMode.cellColor: '格子',
    MarkupMode.candidateColor: '候选',
    MarkupMode.strong: '强链',
    MarkupMode.weak: '弱链',
    MarkupMode.autoStrong: 'AIC',
  };

  static const _keys = {
    MarkupMode.cellColor: 'markup-mode-cell',
    MarkupMode.candidateColor: 'markup-mode-candidate',
    MarkupMode.strong: 'markup-mode-strong',
    MarkupMode.weak: 'markup-mode-weak',
    MarkupMode.autoStrong: 'markup-mode-aic',
  };

  static String labelOf(MarkupMode mode) => _labels[mode] ?? mode.name;

  static String keyOf(MarkupMode mode) => _keys[mode] ?? 'markup-mode-${mode.name}';

  @override
  Widget build(BuildContext context) {
    final asset = _assets[mode];
    if (asset == null) return const SizedBox.shrink();
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
