import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

const puzzle =
    '000100504005840203420500087004071859090608401008000306000000708000700902007080045';

void _apply(SudokuBoard board, SudokuHint hint) {
  if (hint.isElimination) {
    for (final e in hint.eliminations) {
      board.eliminateCandidate(e.row, e.col, e.num);
    }
  } else {
    board.set(hint.row, hint.col, hint.value);
  }
}

bool _elimIsFalse(SudokuBoard solution, CandidateElim e) =>
    solution.get(e.row, e.col) != e.num;

void main() {
  test('ALS 走完后卡住的残局会提示 Nishio', () {
    final solved = SudokuBoard.fromString(puzzle);
    expect(SudokuSolver.solve(solved), isTrue);

    final board = SudokuBoard.fromString(puzzle);
    for (var i = 0; i < 80; i++) {
      final hint = SudokuSolver.getHint(board);
      if (hint == null) break;
      if (hint.technique == 'Nishio' || hint.technique == 'Grouped AIC') {
        break;
      }
      _apply(board, hint);
      if (board.isComplete()) break;
    }
    expect(board.isComplete(), isFalse);

    final sw = Stopwatch()..start();
    final hint = SudokuSolver.getHint(board);
    sw.stop();

    expect(hint, isNotNull);
    expect(['Nishio', 'Grouped AIC'].contains(hint!.technique), isTrue);
    expect(hint.isElimination, isTrue);
    expect(hint.eliminations, isNotEmpty);
    expect(hint.eliminations.every((e) => _elimIsFalse(solved, e)), isTrue);
    expect(hint.patternCells, isNotEmpty);
    expect(
      hint.patternCandidates.any((c) => c.role != HintRole.target),
      isTrue,
    );
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });

  test('000100504 残局连续提示能做完', () {
    final solved = SudokuBoard.fromString(puzzle);
    expect(SudokuSolver.solve(solved), isTrue);
    final board = SudokuBoard.fromString(puzzle);

    for (var step = 0; step < 120; step++) {
      if (board.isComplete()) break;
      final hint = SudokuSolver.getHint(board);
      expect(hint, isNotNull, reason: '未完成却找不到下一步');
      if (hint!.isElimination) {
        expect(
          hint.eliminations.every((e) => _elimIsFalse(solved, e)),
          isTrue,
        );
      }
      _apply(board, hint);
    }
    expect(board.isComplete(), isTrue);
  });

  test('Nishio 技巧名在难度表里', () {
    expect(DifficultyAnalyzer.techniqueScores.containsKey('Nishio'), isTrue);
  });
}
