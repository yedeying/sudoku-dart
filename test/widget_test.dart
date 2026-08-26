import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/main.dart';
import 'package:sudoku_app/theme/app_theme.dart';

void main() {
  testWidgets('底栏含对局与技巧说明', (WidgetTester tester) async {
    await tester.pumpWidget(const SudokuApp());

    expect(find.text('对局'), findsOneWidget);
    expect(find.text('技巧说明'), findsOneWidget);
    expect(find.text('数独游戏'), findsWidgets);
  });

  testWidgets('技巧说明列表可打开', (WidgetTester tester) async {
    await tester.pumpWidget(const SudokuApp());
    await tester.tap(find.text('技巧说明'));
    await tester.pumpAndSettle();

    expect(find.text('唯余法'), findsOneWidget);
    expect(find.text('摒除法'), findsOneWidget);
  });

  test('默认强调色是蓝色种子', () {
    expect(
      AppTheme.light().colorScheme.primary,
      const Color(0xFF42A5F5),
    );
    for (final scheme in [
      AppTheme.light().colorScheme,
      AppTheme.dark().colorScheme,
    ]) {
      final hsl = HSLColor.fromColor(scheme.primary);
      expect(hsl.hue, greaterThan(190), reason: '色相应落在蓝色区间');
      expect(hsl.hue, lessThan(250));
    }
  });

  test('底色与容器色保持灰度，只有强调色带色相', () {
    bool isNearGray(Color c) {
      final maxC = [c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
      final minC = [c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
      return maxC - minC < 0.02;
    }

    for (final scheme in [
      AppTheme.light().colorScheme,
      AppTheme.dark().colorScheme,
    ]) {
      expect(isNearGray(scheme.surface), isTrue);
      expect(isNearGray(scheme.surfaceContainerLow), isTrue);
      expect(isNearGray(scheme.surfaceContainerHighest), isTrue);
      expect(isNearGray(scheme.secondaryContainer), isTrue);
      expect(isNearGray(scheme.tertiaryContainer), isTrue);
      expect(scheme.surfaceTint, Colors.transparent);
    }
  });
}
