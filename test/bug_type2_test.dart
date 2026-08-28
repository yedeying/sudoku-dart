import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

TechniqueInfo _tech(String id) =>
    TechniqueCatalog.all.firstWhere((t) => t.id == id);

void main() {
  test('全双值坟墓 Type 2教学盘：两个例外格多出同一个 2，共同可见处删 2', () {
    final puzzle = _tech('bug_type2').examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);

    final hint = AdvancedTechniques.findBugType2(board);

    expect(hint, isNotNull);
    expect(hint!.technique, '全双值坟墓 Type 2');
    expect(elimKeys(hint), {'1,3,2', '2,5,2', '5,4,2', '7,4,2'});
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(puzzle, hint);
    expectEvidenceBeyondTargets(hint);
    expect(
      hint.patternCells.map((c) => '${c.row},${c.col}'),
      containsAll(['1,4', '2,4']),
      reason: '两个例外格是这一步的依据',
    );
  });

  test('两个例外格多出的不是同一个数字时，Type 2 不成立', () {
    final puzzle = _tech('bug_type4').examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);
    expect(AdvancedTechniques.findBugType2(board), isNull);
  });

  test('奇偶条件不成立的普通残局不会被当成死盘', () {
    const puzzle =
        '000100504005840203420500087004071859090608401008000306000000708000700902007080045';
    final board = SudokuBoard.fromString(puzzle);
    expect(AdvancedTechniques.findBugType2(board), isNull);
  });

  test('全双值坟墓 Type 2排在隐性唯一矩形之后、XYZ-Wing 之前，难度分 6.0', () {
    final order = SudokuSolver.hintSearchOrder;
    expect(order, contains('全双值坟墓 Type 2'));
    expect(order.indexOf('全双值坟墓+1'), lessThan(order.indexOf('全双值坟墓 Type 2')));
    expect(
      order.indexOf('隐性唯一矩形'),
      lessThan(order.indexOf('全双值坟墓 Type 2')),
    );
    expect(order.indexOf('全双值坟墓 Type 2'), lessThan(order.indexOf('XYZ-Wing')));
    expect(DifficultyAnalyzer.techniqueScores, containsPair('全双值坟墓 Type 2', 60));
    expect(_tech('bug_type2').teachingOnly, isFalse);
  });
}
