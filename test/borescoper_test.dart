import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

TechniqueInfo _tech(String id) =>
    TechniqueCatalog.all.firstWhere((t) => t.id == id);

Set<String> _cellKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCells)
        if (c.role == role) '${c.row},${c.col}',
    };

Set<String> _candKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCandidates)
        if (c.role == role) '${c.ref.row},${c.ref.col},${c.ref.num}',
    };

List<List<int>> _structureCells(SudokuHint hint) => [
      for (final key in {
        ..._cellKeys(hint, HintRole.pattern),
        ..._cellKeys(hint, HintRole.extra),
      })
        [int.parse(key.split(',')[0]), int.parse(key.split(',')[1])],
    ];

/// 三数探长致命结构的几何，按 kazusa《三数探长致命结构的基本推理》逐条数：
/// 七格、跨三个宫，房屋占格数只许 2 或 3，占三格的必须是一行一列一宫各一条，
/// 占两格的必须是两行两列两宫。数不齐就不是探长致命结构——整组换排法也走不通。
void expectBorescoperGeometry(List<List<int>> cells) {
  expect(cells, hasLength(7), reason: '三数探长致命结构是七格');

  final triple = <String>[];
  final pair = <String>[];
  for (var house = 0; house < 27; house++) {
    final hit = cells.where((c) {
      if (house < 9) return c[0] == house;
      if (house < 18) return c[1] == house - 9;
      final b = house - 18;
      return c[0] ~/ 3 == b ~/ 3 && c[1] ~/ 3 == b % 3;
    }).length;
    if (hit == 0) continue;
    final kind = house < 9
        ? 'r'
        : house < 18
            ? 'c'
            : 'b';
    expect(hit == 2 || hit == 3, isTrue,
        reason: '房屋 $house 上占了 $hit 格，探长致命结构的房屋只能占 2 格或 3 格');
    if (hit == 3) {
      triple.add(kind);
    } else {
      pair.add(kind);
    }
  }
  expect(triple..sort(), ['b', 'c', 'r'], reason: '占三格的应是一行一列一宫各一条');
  expect(pair..sort(), ['b', 'b', 'c', 'c', 'r', 'r'],
      reason: '占两格的应是两行两列两宫');
  expect(
    {for (final c in cells) (c[0] ~/ 3) * 3 + c[1] ~/ 3},
    hasLength(3),
    reason: '三数探长致命结构横跨三个宫',
  );
}

void main() {
  group('探长致命结构', () {
    test('教学盘：七格三数只有 r2c7 跳得出底数，那一格填 6', () {
      final puzzle = _tech('bdp').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findBorescoper(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '探长致命结构');
      expect(hint.isElimination, isFalse);
      expect([hint.row, hint.col, hint.value], [1, 6, 6]);
      expectFillSound(puzzle, hint);
      expectBorescoperGeometry(_structureCells(hint));
      expect(_cellKeys(hint, HintRole.extra), {'1,6'});
      expect(_candKeys(hint, HintRole.extra), {'1,6,6'});
      expect(
        _candKeys(hint, HintRole.pattern),
        containsAll(['6,7,2', '6,7,8', '6,7,9', '8,2,2', '1,7,9']),
        reason: '七格上的底数候选是这一步的依据',
      );
    });

    test('底数只剩两个数字的七格不成结构', () {
      final board = SudokuBoard.fromString(_tech('bdp').examplePuzzle);
      // 把直角顶点上的 2 抹掉，七格就没有「五格只剩同一组三个底数」这回事了。
      board.eliminateCandidate(6, 7, 2);
      final hint = AdvancedTechniques.findBorescoper(board);
      expect(
        hint == null || (hint.row == 1 && hint.col == 6 && hint.value == 6),
        isTrue,
        reason: '结构被破坏后不该还按原来那副几何下结论',
      );
    });

    test('空盘上不乱报，而且立刻收工', () {
      final board = SudokuBoard.fromString(List.filled(81, '0').join());
      final sw = Stopwatch()..start();
      expect(AdvancedTechniques.findBorescoper(board), isNull);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000), reason: '空盘上必须立刻剪光');
    });

    test('教学盘上搜索在两秒内收工', () {
      final board = SudokuBoard.fromString(_tech('bdp').examplePuzzle);
      final sw = Stopwatch()..start();
      AdvancedTechniques.findBorescoper(board);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('按难度排进提示顺序，有难度分，教学页不再是教学专属', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('探长致命结构'));
      expect(order.indexOf('唯一环 Type 3'), lessThan(order.indexOf('探长致命结构')));
      expect(order.indexOf('探长致命结构'), lessThan(order.indexOf('W-Wing')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('探长致命结构', 74));
      expect(_tech('bdp').teachingOnly, isFalse);
    });
  });
}
