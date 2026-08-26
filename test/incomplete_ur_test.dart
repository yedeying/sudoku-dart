import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

/// 唯一矩形 2 的教学盘：矩形 r7c2、r7c4、r9c2、r9c4，底数 `{6,9}`，
/// r7c4、r9c4 各多出一个 3，唯一解里 r7c4 就是 3。
const _ur2Puzzle =
    '687040001031008700049701008123596800956874123874123500005082410012400080408010002';

void main() {
  test('底数被删过一个的矩形改由不完整唯一矩形接手', () {
    final solved = SudokuBoard.fromString(_ur2Puzzle);
    expect(SudokuSolver.solve(solved), isTrue);
    expect(solved.get(6, 3), 3, reason: 'r7c4 的正解是 3，删掉那里的 9 是条真删除');

    final board = SudokuBoard.fromString(_ur2Puzzle);
    board.eliminateCandidate(6, 3, 9);

    expect(
      AdvancedTechniques.findUniqueRectangleType2(board),
      isNull,
      reason: 'r7c4 少了一个底数，标准唯一矩形 2 的认形条件已经不满足',
    );

    final hint = AdvancedTechniques.findIncompleteUniqueRectangle(board);
    expect(hint, isNotNull);
    expect(hint!.technique, '不完整唯一矩形');
    expect(elimKeys(hint), {'0,3,3', '7,4,3'});
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(_ur2Puzzle, hint);
    expectEvidenceBeyondTargets(hint);
    final link = hint.links.singleWhere((l) => l.kind == ArrowKind.strong);
    expect(
      {
        '${link.from.row},${link.from.col},${link.from.num}',
        '${link.to.row},${link.to.col},${link.to.num}',
      },
      {'6,3,3', '8,3,3'},
      reason: '两个多出 3 的角之间至少有一个为真，画成强链',
    );
  });

  test('四角都完整时不抢唯一矩形 2 的活', () {
    final board = SudokuBoard.fromString(_ur2Puzzle);
    expect(AdvancedTechniques.findUniqueRectangleType2(board), isNotNull);
    expect(AdvancedTechniques.findIncompleteUniqueRectangle(board), isNull);
  });

  test('只剩一个角带额外候选时，那个角不能再填底数', () {
    final board = SudokuBoard.fromString(List.filled(81, '0').join());
    void keep(int row, int col, List<int> digits) {
      for (var digit = 1; digit <= 9; digit++) {
        if (!digits.contains(digit)) {
          board.eliminateCandidate(row, col, digit);
        }
      }
    }

    // r1c1、r2c1 是干净的 {5,6}；r1c4 之前已经被删掉过 5，只剩 6；
    // r2c4 是 {5,6,7}。四角要都落在 {5,6} 里就能整块对调，所以 r2c4 只能填 7。
    keep(0, 0, [5, 6]);
    keep(1, 0, [5, 6]);
    keep(0, 3, [6]);
    keep(1, 3, [5, 6, 7]);

    final hint = AdvancedTechniques.findIncompleteUniqueRectangle(board);
    expect(hint, isNotNull);
    expect(hint!.technique, '不完整唯一矩形');
    expect(elimKeys(hint), {'1,3,5', '1,3,6'});
    expectEvidenceBeyondTargets(hint);
  });

  test('不完整唯一矩形排在唯一矩形 1 之后、唯一矩形 2 之前，难度分 5.2', () {
    final order = SudokuSolver.hintSearchOrder;
    expect(order, contains('不完整唯一矩形'));
    expect(
      order.indexOf('唯一矩形 1'),
      lessThan(order.indexOf('不完整唯一矩形')),
    );
    expect(
      order.indexOf('不完整唯一矩形'),
      lessThan(order.indexOf('唯一矩形 2')),
    );
    expect(
      order.indexOf('X-Wing'),
      lessThan(order.indexOf('不完整唯一矩形')),
    );
    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('不完整唯一矩形', 52),
    );
    expect(
      TechniqueCatalog.all
          .firstWhere((t) => t.id == 'incomplete_ur')
          .teachingOnly,
      isFalse,
    );
  });
}
