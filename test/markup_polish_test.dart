import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/theme/app_theme.dart';
import 'package:sudoku_app/widgets/board_arrows_painter.dart';
import 'package:sudoku_app/widgets/sudoku_grid.dart';

const _classic = '530070000'
    '600195000'
    '098000060'
    '800060003'
    '400803001'
    '700020006'
    '060000280'
    '000419005'
    '000080079';

void main() {
  test('调色板给够 10 个可区分的颜色', () {
    expect(MarkupPalette.colors.length, 10);
    expect(MarkupPalette.colors.toSet().length, 10);
    for (final color in MarkupPalette.colors) {
      expect(MarkupPalette.wash(color).computeLuminance(), greaterThan(0.5),
          reason: '格底淡洗要够浅，格子里才能用深色数字');
    }
    // 相邻两色不能太接近，否则 10 个色等于摆设。
    for (int i = 0; i < MarkupPalette.colors.length; i++) {
      for (int j = i + 1; j < MarkupPalette.colors.length; j++) {
        final a = HSLColor.fromColor(MarkupPalette.colors[i]);
        final b = HSLColor.fromColor(MarkupPalette.colors[j]);
        final dh = (a.hue - b.hue).abs();
        final hueGap = dh > 180 ? 360 - dh : dh;
        final lightGap = (a.lightness - b.lightness).abs();
        expect(hueGap > 20 || lightGap > 0.15, true,
            reason: '第 $i 色和第 $j 色太像了');
      }
    }
  });

  test('强弱链沿用当前标记色', () {
    final state = GameState()..loadCustomGame(_classic);
    state.setMarkupMode(MarkupMode.strong);
    state.setMarkupColor(MarkupPalette.colors[4]);
    state.onCandidateMarkupTap(0, 2, 1);
    state.onCandidateMarkupTap(0, 3, 1);

    expect(state.userMarkup.arrows, hasLength(1));
    expect(state.userMarkup.arrows.first.color, MarkupPalette.colors[4]);
  });

  test('自动强链也带上当前标记色', () {
    final state = GameState()..loadCustomGame(_classic);
    state.setMarkupMode(MarkupMode.autoStrong);
    state.setMarkupColor(MarkupPalette.colors[6]);
    final added = state.paintAutoStrong(5);

    expect(added, greaterThan(0));
    expect(
      state.userMarkup.arrows.every((a) => a.color == MarkupPalette.colors[6]),
      true,
    );
  });

  test('提示自带的箭头不指定颜色，走主题的强/弱链色', () {
    const arrow = MarkupArrow(
      from: CandidateRef(0, 0, 1),
      to: CandidateRef(0, 1, 1),
      kind: ArrowKind.strong,
    );
    expect(arrow.color, isNull);
  });

  test('箭头两端从数字上退开，不压在候选数上', () {
    const from = CandidateRef(0, 0, 1);
    const to = CandidateRef(0, 8, 1);
    final painter = BoardArrowsPainter(
      markup: BoardMarkup(
        arrows: const [
          MarkupArrow(from: from, to: to, kind: ArrowKind.strong)
        ],
      ),
      strongColor: Colors.blue,
      weakColor: Colors.grey,
    );
    const size = Size(360, 360);
    final path = painter.debugPath(painter.markup.arrows.first, size);
    final centers = painter.debugCenters(painter.markup.arrows.first, size);

    final startGap = (path.first - centers.$1).distance;
    final endGap = (path.last - centers.$2).distance;
    // 360 宽的棋盘上让开约 6px：不贴数字，也不至于离得老远。
    expect(startGap, inInclusiveRange(5, 7));
    expect(endGap, inInclusiveRange(5, 7));
    // 退让不能把线缩没了
    double total = 0;
    for (int i = 0; i + 1 < path.length; i++) {
      total += (path[i + 1] - path[i]).distance;
    }
    expect(total, greaterThan(100));
  });

  testWidgets('候选上色可以直接点棋盘上的小数字', (tester) async {
    final state = GameState()..loadCustomGame(_classic);
    state.setMarkupMode(MarkupMode.candidateColor);
    state.setMarkupColor(MarkupPalette.colors[3]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 450,
            child: SudokuGrid(
              board: state.board!,
              selectedRow: null,
              selectedCol: null,
              onCellTap: (_, __) {},
              onCandidateTap: state.onCandidateTap,
              showCandidates: true,
              markup: state.displayMarkup,
            ),
          ),
        ),
      ),
    );

    state.onCandidateTap(0, 2, 4);
    expect(
      state.userMarkup.candidateColors[const CandidateRef(0, 2, 4)],
      MarkupPalette.colors[3],
    );

    // 再点一次取消
    state.onCandidateTap(0, 2, 4);
    expect(
      state.userMarkup.candidateColors.containsKey(const CandidateRef(0, 2, 4)),
      false,
    );
  });

  testWidgets('格内候选不再是可滚动网格，鼠标悬停不会冒出滚动条', (tester) async {
    final board = SudokuBoard.fromString(_classic);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 450,
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

    // 只剩棋盘本体那一个 GridView
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('上色格子里的数字取对照色，不会蓝底蓝字', (tester) async {
    final board = SudokuBoard.fromString(_classic);
    board.set(0, 2, 4);
    final markup = BoardMarkup(
      cellColors: {BoardMarkup.cellKey(0, 2): MarkupPalette.colors[2]},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 450,
            child: SudokuGrid(
              board: board,
              selectedRow: null,
              selectedCol: null,
              onCellTap: (_, __) {},
              showCandidates: true,
              markup: markup,
            ),
          ),
        ),
      ),
    );

    final digit = tester.widget<Text>(find.text('4').first);
    final bg = MarkupPalette.wash(MarkupPalette.colors[2]);
    final fg = digit.style!.color!;
    final contrast = (fg.computeLuminance() + 0.05) /
        (bg.computeLuminance() + 0.05);
    final ratio = contrast > 1 ? contrast : 1 / contrast;
    expect(ratio, greaterThan(3.5));
  });
}
