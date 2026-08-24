import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/main.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/theme/app_theme.dart';
import 'package:sudoku_app/theme/board_palette.dart';
import 'package:sudoku_app/theme/theme_controller.dart';
import 'package:sudoku_app/widgets/sudoku_grid.dart';

const _puzzle = '530070000'
    '600195000'
    '098000060'
    '800060003'
    '400803001'
    '700020006'
    '060000280'
    '000419005'
    '000080079';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('主题使用随包内置的中文字体，避免 Web 首帧方块字', (tester) async {
    await tester.pumpWidget(const SudokuApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.theme!.textTheme.bodyMedium!.fontFamily, AppTheme.fontFamily);
    expect(app.theme!.textTheme.bodyMedium!.fontFamilyFallback, isNotEmpty);
  });

  testWidgets('深浅两套主题都提供，跟随系统', (tester) async {
    await tester.pumpWidget(const SudokuApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.themeMode, ThemeMode.system);
    expect(app.darkTheme, isNotNull);
  });

  test('两套主题的按钮前后景对比度都达标', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      expect(_contrast(scheme.primary, scheme.onPrimary), greaterThan(4.5));
      expect(_contrast(scheme.surface, scheme.onSurface), greaterThan(4.5));
      expect(
        _contrast(scheme.surface, scheme.onSurfaceVariant),
        greaterThan(3.0),
      );
      // 按钮实心底色必须能从页面底色里分辨出来。
      expect(_contrast(scheme.primary, scheme.surface), greaterThan(2.0));
      expect(
        _contrast(scheme.primaryContainer, scheme.onPrimaryContainer),
        greaterThan(4.5),
      );
    }
  });

  test('两套棋盘配色的数字与格背景对比度都达标', () {
    for (final palette in [
      BoardPalette.lightPalette,
      BoardPalette.darkPalette,
    ]) {
      expect(_contrast(palette.paper, palette.givenDigit), greaterThan(4.5));
      expect(_contrast(palette.paper, palette.userDigit), greaterThan(3.0));
      expect(_contrast(palette.paper, palette.candidate), greaterThan(2.5));
      expect(_contrast(palette.selected, palette.givenDigit), greaterThan(3.0));
      expect(_contrast(palette.anchor, palette.onAnchor), greaterThan(4.5));
      // 宫线要比格线更显眼。
      expect(
        _contrast(palette.paper, palette.gridStrong),
        greaterThan(_contrast(palette.paper, palette.gridThin)),
      );
    }
  });

  test('强调底与对照字对比度达标', () {
    for (final id in AccentId.values) {
      final c = ThemeController.colorFor(id);
      for (final b in Brightness.values) {
        final p = BoardPalette.fromAccent(b, c);
        final fg = p.sameDigit.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
        expect(_contrast(p.sameDigit, fg), greaterThan(4.5));
      }
    }
  });

  test('棋盘跟随主题亮暗，深色下不再是白纸盖深灰块', () {
    final lightPalette = AppTheme.light().extension<BoardPalette>()!;
    final darkPalette = AppTheme.dark().extension<BoardPalette>()!;

    expect(lightPalette.paper.computeLuminance(), greaterThan(0.6));
    expect(darkPalette.paper.computeLuminance(), lessThan(0.1));
    expect(
      darkPalette.sameDigit.computeLuminance(),
      greaterThan(darkPalette.paper.computeLuminance()),
    );
  });

  testWidgets('候选数字号随格子尺寸缩放，落在可读区间', (tester) async {
    final board = SudokuBoard.fromString(_puzzle);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: SudokuGrid(
              board: board,
              selectedRow: null,
              selectedCol: null,
              onCellTap: (_, __) {},
              showCandidates: true,
            ),
          ),
        ),
      ),
    );

    final sizes = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.style?.fontSize)
        .whereType<double>()
        .toSet();

    // 360 宽的棋盘每格约 38px：候选数约 9.5pt，已填数字约 21pt。
    expect(sizes.every((s) => s >= 9 && s <= 22), isTrue, reason: '字号: $sizes');
  });
}
