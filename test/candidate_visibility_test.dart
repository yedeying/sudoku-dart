import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/theme/app_theme.dart';
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

Future<void> _pumpGrid(
  WidgetTester tester, {
  required SudokuBoard board,
  required bool showCandidates,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 450,
          child: SudokuGrid(
            board: board,
            selectedRow: 0,
            selectedCol: 2,
            showCandidates: showCandidates,
            markup: BoardMarkup(
              candidateColors: {
                const CandidateRef(0, 2, 5): MarkupPalette.colors.first,
              },
            ),
            sameDigitCandidates: {const CandidateRef(0, 2, 1)},
            onCellTap: (_, __) {},
          ),
        ),
      ),
    ),
  );
}

Iterable<Text> _candidateTexts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).where(
          (text) => (text.style?.fontSize ?? double.infinity) < 20,
        );

void main() {
  testWidgets('隐藏候选时选中、上色和同数高亮都不能绕过视图开关', (tester) async {
    final board = SudokuBoard.fromString(_puzzle);
    board.toggleUserCandidate(0, 2, 5);
    expect(board.visibleCandidates(0, 2), contains(5));

    await _pumpGrid(tester, board: board, showCandidates: false);

    expect(_candidateTexts(tester), isEmpty);
    // 隐藏仅影响显示，用户编辑结果仍由模型跟踪。
    expect(board.visibleCandidates(0, 2), contains(5));
  });

  testWidgets('重新显示候选后，隐藏期间保留的编辑结果会恢复显示', (tester) async {
    final board = SudokuBoard.fromString(_puzzle);
    board.toggleUserCandidate(0, 2, 5);

    await _pumpGrid(tester, board: board, showCandidates: false);
    expect(_candidateTexts(tester), isEmpty);

    await _pumpGrid(tester, board: board, showCandidates: true);

    expect(
      _candidateTexts(tester).where((text) => text.data == '5'),
      isNotEmpty,
    );
    expect(board.visibleCandidates(0, 2), contains(5));
  });
}
