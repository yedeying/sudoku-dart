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

Set<String> _cellKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCells)
        if (c.role == role) '${c.row},${c.col}',
    };

Set<String> _candKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCandidates)
        if (c.role == role) '${c.ref.row},${c.ref.col},${c.ref.num}',
    };

void main() {
  test('BUG 类型 3 教学盘：{2,3} 虚拟格和 r2c8 配成数对，c8 别处删 2、3', () {
    final puzzle = _tech('bug_type3').examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);

    final hint = AdvancedTechniques.findBugType3(board);

    expect(hint, isNotNull);
    expect(hint!.technique, 'BUG 类型 3');
    expect(elimKeys(hint), {'5,7,2', '6,7,3'});
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(puzzle, hint);
    expectEvidenceBeyondTargets(hint);
    expect(hint.highlightCols, [7], reason: '数组配在 c8 这条房屋里');
    expect(_cellKeys(hint, HintRole.extra), {'4,7', '7,7'},
        reason: '这两格多出候选，和致命形里的屋顶格同一个角色');
    expect(_candKeys(hint, HintRole.extra), {'4,7,2', '7,7,3'},
        reason: '虚拟格的候选就是两个例外格多出来的数字');
    expect(_cellKeys(hint, HintRole.link), {'1,7'},
        reason: '配数组的格子要单独标出来');
    expect(_candKeys(hint, HintRole.link), {'1,7,2', '1,7,3'});
    final strong = hint.links.where((l) => l.kind == ArrowKind.strong);
    expect(strong, hasLength(1), reason: '两个多余候选至少一真，画成强链');
  });

  test('虚拟格是完整性约束：这张盘上数组数字全在虚拟格里，例外格一个都动不了', () {
    final board = SudokuBoard.fromString(_tech('bug_type3').examplePuzzle);
    final hint = AdvancedTechniques.findBugType3(board);
    expect(hint, isNotNull);
    final touched = {for (final e in hint!.eliminations) '${e.row},${e.col}'};
    // 数组是 {2,3} 两格锁两数，正好等于虚拟格的候选，虚拟格外没有别的数组数字。
    // 一般规则见 virtual_cell_type3_test。
    expect(touched, isNot(contains('4,7')));
    expect(touched, isNot(contains('7,7')));
    expect(touched, isNot(contains('1,7')));
  });

  test('两个例外格多出同一个数字时不走虚拟格，那是类型 2', () {
    final board = SudokuBoard.fromString(_tech('bug_type2').examplePuzzle);
    expect(AdvancedTechniques.findBugType3(board), isNull);
  });

  test('奇偶条件不成立的普通残局不会被当成死盘', () {
    const puzzle =
        '000100504005840203420500087004071859090608401008000306000000708000700902007080045';
    final board = SudokuBoard.fromString(puzzle);
    expect(AdvancedTechniques.findBugType3(board), isNull);
  });

  test('同一张盘上类型 4 也成立，删的是另一批候选，类型 4 排在前面', () {
    final puzzle = _tech('bug_type3').examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);

    final type3 = AdvancedTechniques.findBugType3(board)!;
    final type4 = AdvancedTechniques.findBugType4(board);
    expect(type4, isNotNull, reason: '共有底数 9 在 c8 上只剩这两格，是条强链');
    expect(elimKeys(type4!), {'4,7,1', '7,7,7'});
    expectEliminationsSound(puzzle, type4);
    expect(elimKeys(type4).intersection(elimKeys(type3)), isEmpty);

    final order = SudokuSolver.hintSearchOrder;
    expect(order.indexOf('BUG 类型 4'), lessThan(order.indexOf('BUG 类型 3')));
    // 这张盘上还有更浅的 X-Wing，唯一性技巧都排在它后面，所以整体报法先给 X-Wing。
    expect(SudokuSolver.getHint(board)!.technique, 'X-Wing');
    expect(order.indexOf('X-Wing'), lessThan(order.indexOf('BUG 类型 4')));
  });

  test('BUG 类型 3 排在唯一环 1 之后、唯一环 2 之前，难度分 6.6', () {
    final order = SudokuSolver.hintSearchOrder;
    expect(order, contains('BUG 类型 3'));
    expect(order.indexOf('唯一环 1'), lessThan(order.indexOf('BUG 类型 3')));
    expect(order.indexOf('BUG 类型 3'), lessThan(order.indexOf('唯一环 2')));
    expect(DifficultyAnalyzer.techniqueScores, containsPair('BUG 类型 3', 66));
    expect(_tech('bug_type3').teachingOnly, isFalse);
    expect(
      _tech('bug_plus_n').teachingOnly,
      isTrue,
      reason: 'BUG+n 只是个计数，不给独立报法',
    );
    expect(order, isNot(contains('BUG+n')));
  });
}
