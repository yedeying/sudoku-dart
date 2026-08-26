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
  test('BUG 类型 4 教学盘：r4 上 8 成强链，两个例外格各删一个底数', () {
    final puzzle = _tech('bug_type4').examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);

    final hint = AdvancedTechniques.findBugType4(board);

    expect(hint, isNotNull);
    expect(hint!.technique, 'BUG 类型 4');
    expect(elimKeys(hint), {'3,4,5', '3,5,2'});
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(puzzle, hint);
    expectEvidenceBeyondTargets(hint);
    expect(hint.highlightRows, [3], reason: '锁定发生在 r4 这条线上');
    final strong = hint.links.where((l) => l.kind == ArrowKind.strong).toList();
    expect(strong, hasLength(1));
    expect(
      {
        '${strong.first.from.row},${strong.first.from.col},'
            '${strong.first.from.num}',
        '${strong.first.to.row},${strong.first.to.col},${strong.first.to.num}',
      },
      {'3,4,8', '3,5,8'},
    );
  });

  test('两个例外格多出同一个数字时，类型 4 的强链推理照样成立', () {
    // 类型 2 那张教学盘：r2c5 与 r3c5 多出来的都是 2，
    // 但两格同在 c5，共有底数 9 在 c5 上只剩这两格，是条独立的强链，
    // 于是各自的「另一个底数」4 和 7 也能删——和类型 2 删的不是同一批候选。
    final puzzle = _tech('bug_type2').examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);

    final hint = AdvancedTechniques.findBugType4(board);

    expect(hint, isNotNull, reason: '多余候选相同不妨碍类型 4 的锁定推理');
    expect(hint!.technique, 'BUG 类型 4');
    expect(elimKeys(hint), {'1,4,4', '2,4,7'});
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(puzzle, hint);
    expectEvidenceBeyondTargets(hint);
    expect(hint.highlightCols, [4], reason: '锁定发生在 c5 这条线上');

    // 同一张盘上类型 2 也成立，删的是另一批候选；两手都在时由更早的类型 2 出面。
    final type2 = AdvancedTechniques.findBugType2(board);
    expect(type2, isNotNull);
    expect(elimKeys(type2!).intersection(elimKeys(hint)), isEmpty);
    expect(
      SudokuSolver.hintSearchOrder.indexOf('BUG 类型 2'),
      lessThan(SudokuSolver.hintSearchOrder.indexOf('BUG 类型 4')),
    );
  });

  test('奇偶条件不成立的普通残局不会被当成死盘', () {
    const puzzle =
        '000100504005840203420500087004071859090608401008000306000000708000700902007080045';
    final board = SudokuBoard.fromString(puzzle);
    expect(AdvancedTechniques.findBugType4(board), isNull);
  });

  test('BUG 类型 4 排在唯一矩形 3 之后、Franken 鱼之前，难度分 6.2', () {
    final order = SudokuSolver.hintSearchOrder;
    expect(order, contains('BUG 类型 4'));
    expect(order.indexOf('BUG 类型 2'), lessThan(order.indexOf('BUG 类型 4')));
    expect(order.indexOf('唯一矩形 3'), lessThan(order.indexOf('BUG 类型 4')));
    expect(order.indexOf('BUG 类型 4'), lessThan(order.indexOf('Franken 鱼')));
    expect(
      order.indexOf('BUG 类型 4'),
      lessThan(order.indexOf('Simple Coloring')),
    );
    expect(DifficultyAnalyzer.techniqueScores, containsPair('BUG 类型 4', 62));
    expect(_tech('bug_type4').teachingOnly, isFalse);
  });
}
