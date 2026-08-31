import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/theme/app_theme.dart';
import 'package:sudoku_app/theme/board_palette.dart';
import 'package:sudoku_app/widgets/sudoku_grid.dart';

GameState _fivesBoard() {
  final g = GameState();
  // 只有 (0,0)=5，避免成数自己互撞；(0,2)/(2,8) 手写候选 5
  g.loadCustomGame(
    '500000000'
    '000000000'
    '000000000'
    '000000000'
    '000000000'
    '000000000'
    '000000000'
    '000000000'
    '000000000',
  );
  g.board!.candidates[0][2] = {};
  g.board!.userCandidates[0][2] = {1, 2, 5};
  g.board!.candidates[2][8] = {};
  g.board!.userCandidates[2][8] = {5};
  return g;
}

void main() {
  test('候选色看到同行/同宫成数时，成数格和该候选都算冲突', () {
    final g = _fivesBoard();
    g.setMarkupMode(MarkupMode.candidateColor);
    g.selectCell(0, 2);
    g.onNumberPad(5);

    expect(
      g.candidateColorConflictRefs(),
      contains(const CandidateRef(0, 2, 5)),
    );
    expect(g.getConflictCells(), contains(BoardMarkup.cellKey(0, 0)));
    expect(g.getConflictCells(), isNot(contains(BoardMarkup.cellKey(1, 1))));
  });

  test('未上色但看见成数的候选也标冲突', () {
    final g = _fivesBoard();
    expect(
      g.candidateColorConflictRefs(),
      contains(const CandidateRef(0, 2, 5)),
    );
    expect(g.getConflictCells(), contains(BoardMarkup.cellKey(0, 0)));
  });

  test('候选色与成数不共宫时不冲突', () {
    final g = _fivesBoard();
    g.board!.userCandidates[0][2] = {1, 2};
    g.setMarkupMode(MarkupMode.candidateColor);
    g.selectCell(2, 8);
    g.onNumberPad(5);

    expect(g.candidateColorConflictRefs(), isEmpty);
    expect(g.getConflictCells(), isEmpty);
  });

  test('先上色再填进冲突成数，双方都会标红', () {
    final g = GameState()
      ..loadCustomGame(
        '000000000'
        '000000000'
        '000000000'
        '000000000'
        '000000000'
        '000000000'
        '000000000'
        '000000000'
        '000000000',
      );
    g.board!.candidates[0][2] = {};
    g.board!.userCandidates[0][2] = {4};
    g.setMarkupMode(MarkupMode.candidateColor);
    g.selectCell(0, 2);
    g.onNumberPad(4);
    g.setMarkupMode(MarkupMode.off);
    g.selectCell(0, 5);
    g.placeNumber(4);

    expect(
      g.candidateColorConflictRefs(),
      contains(const CandidateRef(0, 2, 4)),
    );
    expect(g.getConflictCells(), contains(BoardMarkup.cellKey(0, 5)));
  });

  testWidgets('冲突成数与冲突候选数字用冲突红色', (tester) async {
    final board = SudokuBoard.fromString(
      '500000000050000000000000000000000000000000000000000000000000000000000000000000000',
    );
    board.candidates[0][2] = {5};
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: SudokuGrid(
            board: board,
            selectedRow: 0,
            selectedCol: 2,
            onCellTap: (_, __) {},
            showCandidates: true,
            conflictCells: {BoardMarkup.cellKey(0, 0)},
            conflictCandidates: {const CandidateRef(0, 2, 5)},
            markup: BoardMarkup(
              candidateColors: {
                const CandidateRef(0, 2, 5): MarkupPalette.blue,
              },
            ),
          ),
        ),
      ),
    ));

    final palette = AppTheme.light().extension<BoardPalette>()!;
    final given = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('cell-0-0')),
        matching: find.text('5'),
      ),
    );
    expect(given.style?.color, palette.conflictDigit);

    final cand = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('cand-0-2-5')),
        matching: find.text('5'),
      ),
    );
    expect(cand.style?.color, palette.conflictDigit);
  });
}
