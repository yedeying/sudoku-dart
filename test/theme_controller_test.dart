import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/theme/app_theme.dart';
import 'package:sudoku_app/theme/board_palette.dart';
import 'package:sudoku_app/theme/theme_controller.dart';

void main() {
  test('切换强调色会改 primary 和 sameDigit', () {
    final blue = ThemeController.colorFor(AccentId.blue);
    final rose = ThemeController.colorFor(AccentId.rose);
    expect(BoardPalette.fromAccent(Brightness.light, blue).sameDigit,
        isNot(BoardPalette.fromAccent(Brightness.light, rose).sameDigit));
    expect(AppTheme.lightFor(blue).colorScheme.primary,
        isNot(AppTheme.lightFor(rose).colorScheme.primary));
  });

  test('tooltip 优先出现在控件上方，避免挡住棋盘和数字区', () {
    expect(AppTheme.light().tooltipTheme.preferBelow, isFalse);
    expect(AppTheme.dark().tooltipTheme.preferBelow, isFalse);
  });

  test('强调色与标记色是同一套色相', () {
    expect(ThemeController.swatchFor(AccentId.blue), MarkupPalette.blue);
    expect(ThemeController.swatchFor(AccentId.gold), MarkupPalette.gold);
    expect(AccentId.values.length, MarkupPalette.colors.length);
    expect(
      AccentId.values.map(ThemeController.swatchFor).toSet(),
      MarkupPalette.colors.toSet(),
    );
  });
}
