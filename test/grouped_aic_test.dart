import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
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
  test('区块链 教学结构删除同时看见组和单格的候选', () {
    final board = SudokuBoard.fromString(List.filled(81, '0').join());
    final keep = {
      for (final cell in [
        [6, 1],
        [7, 1],
        [8, 1],
        [6, 0],
        [7, 0],
        [8, 0],
      ])
        '${cell[0]},${cell[1]}'
    };
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        for (var digit = 1; digit <= 9; digit++) {
          if (keep.contains('$row,$col') && digit == 2) continue;
          board.eliminateCandidate(row, col, digit);
        }
      }
    }

    final hint = AdvancedTechniques.findGroupedAic(board);

    expect(hint, isNotNull);
    expect(hint!.technique, '区块链');
    expect(hint.eliminations, isNotEmpty);
    expect(hint.eliminations.every((e) => e.num == 2), isTrue);
    expect(
      hint.patternCandidates.any((c) => c.role != HintRole.target),
      isTrue,
    );
  });

  test('024610007 卡点下一步是 区块链 而不是 Nishio', () {
    const puzzle =
        '024610007006070402003824560000200800301060024002001000069002100240130600130006240';
    final solved = SudokuBoard.fromString(puzzle);
    expect(SudokuSolver.solve(solved), isTrue);
    final board = SudokuBoard.fromString(puzzle);
    for (var i = 0; i < 80; i++) {
      final hint = SudokuSolver.getHint(board);
      if (hint == null) break;
      if (hint.technique == '区块链' || hint.technique == 'Nishio') {
        break;
      }
      _apply(board, hint);
    }
    final sw = Stopwatch()..start();
    final hint = SudokuSolver.getHint(board);
    sw.stop();
    expect(hint, isNotNull);
    expect(hint!.technique, '区块链');
    expect(
      hint.eliminations.every((e) => solved.get(e.row, e.col) != e.num),
      isTrue,
    );
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });

  test('区块链 技巧名在难度表里', () {
    expect(
      DifficultyAnalyzer.techniqueScores.containsKey('区块链'),
      isTrue,
    );
  });
}
