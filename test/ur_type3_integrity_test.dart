import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

void _apply(SudokuBoard board, SudokuHint hint) {
  if (hint.isElimination) {
    for (final e in hint.eliminations) {
      board.eliminateCandidate(e.row, e.col, e.num);
    }
  } else {
    board.set(hint.row, hint.col, hint.value);
  }
}

void main() {
  test('提示不得删掉或填错唯一解，避免把盘面推死', () {
    const puzzle =
        '500007000200900800000000460020710005000506000600039040087000000005001009000800006';
    final solved = SudokuBoard.fromString(puzzle);
    expect(SudokuSolver.solve(solved), isTrue);

    final board = SudokuBoard.fromString(puzzle);
    for (var step = 0; step < 120; step++) {
      final hint = SudokuSolver.getHint(board);
      if (hint == null) break;
      if (hint.isElimination) {
        for (final e in hint.eliminations) {
          expect(
            solved.get(e.row, e.col),
            isNot(e.num),
            reason: '${hint.technique} 删掉了正解 ${e.num}r${e.row + 1}c${e.col + 1}',
          );
        }
      } else {
        expect(
          solved.get(hint.row, hint.col),
          hint.value,
          reason: '${hint.technique} 把 r${hint.row + 1}c${hint.col + 1} '
              '填成 ${hint.value}',
        );
      }
      _apply(board, hint);
    }

    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        expect(
          board.getCandidates(row, col),
          isNotEmpty,
          reason: 'r${row + 1}c${col + 1} 被推空',
        );
      }
    }
  });
}
