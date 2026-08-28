import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

TechniqueInfo _tech(String id) =>
    TechniqueCatalog.all.firstWhere((t) => t.id == id);

void main() {
  test('隐性唯一矩形教学盘：两条 5 的强链把 9r1c2 逼掉', () {
    final puzzle = _tech('hidden_ur').examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);

    final hint = AdvancedTechniques.findHiddenUniqueRectangle(board);

    expect(hint, isNotNull);
    expect(hint!.technique, '隐性唯一矩形');
    expect(elimKeys(hint), {'0,1,9'});
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(puzzle, hint);
    expectEvidenceBeyondTargets(hint);
    expect(hint.highlightRows, [0]);
    expect(hint.highlightCols, [1]);

    final strong = hint.links.where((l) => l.kind == ArrowKind.strong).toList();
    expect(strong, hasLength(2), reason: '行、列各一条 5 的强链');
    expect(
      strong
          .map((l) => {
                '${l.from.row},${l.from.col},${l.from.num}',
                '${l.to.row},${l.to.col},${l.to.num}',
              })
          .toList(),
      containsAll([
        {'0,1,5', '0,5,5'},
        {'0,1,5', '1,1,5'},
      ]),
    );
  });

  test('对角那格不是干净的底数对时不报', () {
    final board = SudokuBoard.fromString(List.filled(81, '0').join());
    void keep(int row, int col, List<int> digits) {
      for (var digit = 1; digit <= 9; digit++) {
        if (!digits.contains(digit)) board.eliminateCandidate(row, col, digit);
      }
    }

    // r1c2 是目标格，对角的 r2c6 挂着一个多余的 7，推理断在这里。
    keep(0, 1, [5, 9, 3]);
    keep(0, 5, [5, 9]);
    keep(1, 1, [5, 9]);
    keep(1, 5, [5, 9, 7]);
    for (var col = 0; col < 9; col++) {
      if (col != 1 && col != 5) board.eliminateCandidate(0, col, 5);
    }
    for (var row = 0; row < 9; row++) {
      if (row != 0 && row != 1) board.eliminateCandidate(row, 1, 5);
    }

    expect(AdvancedTechniques.findHiddenUniqueRectangle(board), isNull);
  });

  test('少了一条强链就不成立', () {
    final board = SudokuBoard.fromString(List.filled(81, '0').join());
    void keep(int row, int col, List<int> digits) {
      for (var digit = 1; digit <= 9; digit++) {
        if (!digits.contains(digit)) board.eliminateCandidate(row, col, digit);
      }
    }

    keep(0, 1, [5, 9, 3]);
    keep(0, 5, [5, 9]);
    keep(1, 1, [5, 9]);
    keep(1, 5, [5, 9]);
    // 只把行上的 5 收成强链，列上的 5 仍旧散着。
    for (var col = 0; col < 9; col++) {
      if (col != 1 && col != 5) board.eliminateCandidate(0, col, 5);
    }

    expect(AdvancedTechniques.findHiddenUniqueRectangle(board), isNull);
  });

  test('隐性唯一矩形排在唯一矩形 Type 4 之后、XYZ-Wing 之前，难度分 5.8', () {
    final order = SudokuSolver.hintSearchOrder;
    expect(order, contains('隐性唯一矩形'));
    expect(order.indexOf('X-Wing'), lessThan(order.indexOf('隐性唯一矩形')));
    expect(order.indexOf('唯一矩形 Type 4'), lessThan(order.indexOf('隐性唯一矩形')));
    expect(order.indexOf('隐性唯一矩形'), lessThan(order.indexOf('XYZ-Wing')));
    expect(
      order.indexOf('隐性唯一矩形'),
      lessThan(order.indexOf('染色法')),
    );
    expect(DifficultyAnalyzer.techniqueScores, containsPair('隐性唯一矩形', 58));
    expect(
      TechniqueCatalog.all.firstWhere((t) => t.id == 'hidden_ur').teachingOnly,
      isFalse,
    );
  });
}
