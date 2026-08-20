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

    expect(find.text('唯一候选数'), findsOneWidget);
    expect(find.text('隐藏单元'), findsOneWidget);
  });

  testWidgets('应用使用近黑种子色', (tester) async {
    await tester.pumpWidget(const SudokuApp());
    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(theme.colorScheme.brightness, Brightness.light);
    // Seed itself must be near-black (M3 fromSeed can remap primary).
    expect(AppTheme.seed.computeLuminance() < 0.05, isTrue);
    expect(theme.colorScheme.primary.computeLuminance() < 0.2, isTrue);
  });

  testWidgets('chrome 容器色为灰度无青绿色彩', (tester) async {
    await tester.pumpWidget(const SudokuApp());
    final scheme =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.colorScheme;

    bool isNearGray(Color c) {
      final maxC = [c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
      final minC = [c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
      return maxC - minC < 0.02;
    }

    expect(isNearGray(scheme.primaryContainer), isTrue);
    expect(isNearGray(scheme.secondaryContainer), isTrue);
    expect(isNearGray(scheme.tertiaryContainer), isTrue);
    expect(isNearGray(scheme.surface), isTrue);
    expect(isNearGray(scheme.surfaceContainerHighest), isTrue);
    expect(scheme.surfaceTint, Colors.transparent);
  });
}
