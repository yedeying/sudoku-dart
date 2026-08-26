import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

TechniqueInfo _tech(String id) =>
    TechniqueCatalog.all.firstWhere((t) => t.id == id);

SudokuBoard _emptyBoard() =>
    SudokuBoard.fromString(List.filled(81, '0').join());

void _keepOnly(
  SudokuBoard board,
  int digit,
  Iterable<List<int>> cells,
  Iterable<List<int>> keep,
) {
  final keepKeys = {for (final cell in keep) '${cell[0]},${cell[1]}'};
  for (final cell in cells) {
    if (!keepKeys.contains('${cell[0]},${cell[1]}')) {
      board.eliminateCandidate(cell[0], cell[1], digit);
    }
  }
}

List<List<int>> _row(int row) => [
      for (var col = 0; col < 9; col++) [row, col],
    ];

/// 刺身 Swordfish：基线 r1、r2、r4，覆盖 c1、c4、c7。
///
/// r4 在覆盖里只剩 c1 一个顶点（c4、c7 两个覆盖顶点空着），去掉鳍 5r4c5 之后
/// 这条鱼就散了——这正是刺身和普通带鳍的分界。鳍和空掉的 r4c4 同在 b5，
/// 所以能删的是 b5 里踩在 c4 上的 5r5c4、5r6c4。
SudokuBoard _sashimiSwordfishBoard() {
  final board = _emptyBoard();
  _keepOnly(board, 5, _row(0), [
    [0, 0],
    [0, 3],
  ]);
  _keepOnly(board, 5, _row(1), [
    [1, 3],
    [1, 6],
  ]);
  _keepOnly(board, 5, _row(3), [
    [3, 0],
    [3, 4],
  ]);
  // 换一组覆盖（c1、c5、c7）读出来的那条刺身只能删 5r3c5，把它拿掉之后
  // 这张盘上只剩唯一一组刺身删除，断言就不依赖覆盖的枚举次序。
  board.eliminateCandidate(2, 4, 5);
  return board;
}

void main() {
  test('刺身 Swordfish 删掉鳍所在宫里踩着覆盖线的候选', () {
    final board = _sashimiSwordfishBoard();
    final hint = AdvancedTechniques.findSashimiFish(board);

    expect(hint, isNotNull, reason: '基线 r4 在覆盖里只剩一个顶点，应报刺身鱼');
    expect(hint!.technique, '刺身鱼');
    expect(hint.isElimination, isTrue);
    expect(elimKeys(hint), {'4,3,5', '5,3,5'});
    expectEliminationsPresent(board, hint);
    expectEvidenceBeyondTargets(hint);
    expect(hint.highlightRows, [0, 1, 3], reason: '三条基线应淡亮出来');
    expect(hint.highlightCols, isEmpty);
  });

  test('刺身鱼教学盘面报出教学页那两条删除', () {
    final puzzle = _tech('sashimi').examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);
    final hint = AdvancedTechniques.findSashimiFish(board);

    expect(hint, isNotNull, reason: '教学盘面上应找得到刺身 Swordfish');
    expect(hint!.technique, '刺身鱼');
    expect(elimKeys(hint), {'0,6,3', '0,8,3'});
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(puzzle, hint);
    expectEvidenceBeyondTargets(hint);
  });

  test('刺身鱼只报 Swordfish 及以上规格，X-Wing 那一档留给摩天楼', () {
    // 摩天楼那张盘正是「刺身 X-Wing 等于摩天楼」的典型：两条只剩两个候选的行，
    // 共用一个底列。刺身鱼不该在这里抢报。
    final board = _emptyBoard();
    _keepOnly(board, 5, [
      ..._row(0),
      ..._row(1),
      ..._row(3),
    ], [
      [0, 0],
      [0, 3],
      [1, 0],
      [1, 4],
      [3, 0],
      [3, 3],
      [3, 4],
    ]);
    for (var col = 6; col < 9; col++) {
      board.eliminateCandidate(2, col, 5);
    }

    expect(AdvancedTechniques.findSkyscraper(board), isNotNull);
    expect(
      AdvancedTechniques.findSashimiFish(board),
      isNull,
      reason: '刺身 X-Wing 的删除就是摩天楼的删除，不另报一遍',
    );
  });

  test('题库残局逐步核对：刺身鱼删的都不是正解，单次搜索不超过 2 秒', () {
    const puzzles = [
      '000100504005840203420500087004071859090608401008000306000000708000700902007080045',
      '024610007006070402003824560000200800301060024002001000069002100240130600130006240',
      '004060000015830026060001300100006000206100050050000167589072600400610800601000000',
      '070060010000741600600208079860000091300106007002000360000670000050804036906315702',
    ];
    for (final puzzle in puzzles) {
      final solved = SudokuBoard.fromString(puzzle);
      expect(SudokuSolver.solve(solved), isTrue);
      final board = SudokuBoard.fromString(puzzle);
      for (var step = 0; step < 200; step++) {
        if (board.isComplete()) break;
        final sw = Stopwatch()..start();
        final sashimi = AdvancedTechniques.findSashimiFish(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
        if (sashimi != null) {
          for (final e in sashimi.eliminations) {
            expect(
              solved.get(e.row, e.col) == e.num,
              isFalse,
              reason: '刺身鱼删了正解 r${e.row + 1}c${e.col + 1}=${e.num}',
            );
          }
        }
        final hint = SudokuSolver.getHint(board);
        if (hint == null) break;
        if (hint.isElimination) {
          for (final e in hint.eliminations) {
            board.eliminateCandidate(e.row, e.col, e.num);
          }
        } else {
          board.set(hint.row, hint.col, hint.value);
        }
      }
    }
  });

  test('刺身鱼排在带鳍 X-Wing 之后、空矩形之前，难度分取评审的 4.6', () {
    final order = SudokuSolver.hintSearchOrder;
    expect(order, contains('刺身鱼'));
    expect(order.indexOf('摩天楼'), lessThan(order.indexOf('刺身鱼')));
    expect(order.indexOf('带鳍 X-Wing'), lessThan(order.indexOf('刺身鱼')));
    expect(order.indexOf('刺身鱼'), lessThan(order.indexOf('空矩形')));
    expect(order.indexOf('刺身鱼'), lessThan(order.indexOf('带鳍 Swordfish')));
    expect(DifficultyAnalyzer.techniqueScores, containsPair('刺身鱼', 46));
  });
}
