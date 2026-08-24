import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/theme/app_theme.dart';
import 'package:sudoku_app/theme/board_palette.dart';

void main() {
  test('切换强调色会改 primary 和 sameDigit', () {
    final blue = BoardPalette.fromAccent(Brightness.light, const Color(0xFF1565C0));
    final rose = BoardPalette.fromAccent(Brightness.light, const Color(0xFFC2185B));
    expect(blue.sameDigit, isNot(rose.sameDigit));
    expect(AppTheme.lightFor(const Color(0xFF1565C0)).colorScheme.primary,
        isNot(AppTheme.lightFor(const Color(0xFFC2185B)).colorScheme.primary));
  });
}
