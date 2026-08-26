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

/// 行强链 — 列弱链 — 宫强链：三段各走一种房屋，任何一种读法都落不回
/// 摩天楼（两条同向线强链）、双线风筝（一行一列在宫里拐弯）或空矩形（宫里十字）。
SudokuBoard _generalTurbotBoard() {
  final board = _emptyBoard();
  _keepOnly(
    board,
    5,
    [
      for (var col = 0; col < 9; col++) [5, col],
    ],
    [
      [5, 1],
      [5, 7],
    ],
  );
  _keepOnly(
    board,
    5,
    [
      for (var row = 6; row < 9; row++)
        for (var col = 6; col < 9; col++) [row, col],
    ],
    [
      [7, 7],
      [8, 7],
    ],
  );
  // 另一种读法（两端换成 r6c2 与 r8c8）只能删 r8c2，把它拿掉之后
  // 这张盘上只剩唯一一组多宝鱼删除，测试断言才不依赖搜索次序。
  board.eliminateCandidate(7, 1, 5);
  return board;
}

/// 摩天楼那张盘：两条行强链共用 c1，属于已命名特例，一般多宝鱼不该抢报。
SudokuBoard _skyscraperBoard() {
  final board = _emptyBoard();
  _keepOnly(
    board,
    5,
    [
      for (final row in [0, 1, 3])
        for (var col = 0; col < 9; col++) [row, col],
    ],
    [
      [0, 0],
      [0, 3],
      [1, 0],
      [1, 4],
      [3, 0],
      [3, 3],
      [3, 4],
    ],
  );
  for (var col = 6; col < 9; col++) {
    board.eliminateCandidate(2, col, 5);
  }
  return board;
}

/// 宫强链 + 线强链，但空矩形读不出来：宫里那个十字的删除格 r3c2 落在宫内，
/// 空矩形明令跳过宫内的删除，所以这条链多出来的 5r2c4、5r2c6 只有多宝鱼报得了。
SudokuBoard _boxLineTurbotWithoutEmptyRectangle() {
  final board = _emptyBoard();
  _keepOnly(
    board,
    5,
    [
      for (var row = 0; row < 9; row++)
        for (var col = 0; col < 9; col++) [row, col],
    ],
    [
      [0, 0],
      [1, 1],
      [0, 4],
      [2, 4],
      [1, 3],
      [1, 5],
    ],
  );
  return board;
}

/// 同样是宫强链 + 列强链，但这一张的删除格 r5c2 在宫外，空矩形正好读得出来，
/// 链和删除都跟空矩形那一手重合，一般多宝鱼就该让位。
SudokuBoard _realEmptyRectangleBoard() {
  final board = _emptyBoard();
  _keepOnly(
    board,
    5,
    [
      for (var row = 0; row < 9; row++)
        for (var col = 0; col < 9; col++) [row, col],
    ],
    [
      [0, 0],
      [1, 1],
      [0, 4],
      [4, 4],
      [4, 1],
      // 这两格只是把 c2、r5 撑到三个候选，免得多冒出别的强链读法。
      [6, 1],
      [4, 7],
    ],
  );
  return board;
}

void main() {
  test('一般多宝鱼在行强链—列弱链—宫强链上删两端共同可见处', () {
    final board = _generalTurbotBoard();
    final hint = AdvancedTechniques.findTurbotFish(board);

    expect(hint, isNotNull, reason: '强-弱-强已经串成，应报多宝鱼');
    expect(hint!.technique, '多宝鱼');
    expect(hint.isElimination, isTrue);
    expect(elimKeys(hint), {'8,1,5'});
    expectEliminationsPresent(board, hint);
    expectEvidenceBeyondTargets(hint);
    expect(
      hint.links.where((a) => a.kind == ArrowKind.strong),
      hasLength(2),
      reason: '两条强链都要画出来',
    );
    expect(
      hint.links.where((a) => a.kind == ArrowKind.weak),
      hasLength(1),
      reason: '中间那段弱链也要画出来',
    );
    expect(
      hint.patternCandidates.where((c) => c.role == HintRole.link),
      hasLength(4),
      reason: '链上四个节点的候选都该标成链角色',
    );
  });

  test('摩天楼/双线风筝/空矩形这三个已命名特例不按一般多宝鱼报', () {
    expect(
      AdvancedTechniques.findSkyscraper(_skyscraperBoard()),
      isNotNull,
      reason: '这张盘本来就有摩天楼',
    );
    expect(
      AdvancedTechniques.findTurbotFish(_skyscraperBoard()),
      isNull,
      reason: '这条链换个说法就是摩天楼，一般多宝鱼不该报',
    );

    final kite = _emptyBoard();
    _keepOnly(
      kite,
      5,
      [
        for (var col = 0; col < 9; col++) [0, col],
      ],
      [
        [0, 1],
        [0, 7],
      ],
    );
    _keepOnly(
      kite,
      5,
      [
        for (var row = 0; row < 9; row++) [row, 2],
      ],
      [
        [1, 2],
        [8, 2],
      ],
    );
    expect(AdvancedTechniques.findTwoStringKite(kite), isNotNull);
    expect(
      AdvancedTechniques.findTurbotFish(kite),
      isNull,
      reason: '一行一列在宫里拐弯就是双线风筝，一般多宝鱼不该报',
    );
  });

  test('宫里是十字但空矩形读不出这一手时，仍按一般多宝鱼报', () {
    final board = _boxLineTurbotWithoutEmptyRectangle();

    expect(
      AdvancedTechniques.findEmptyRectangle(board),
      isNull,
      reason: '删除格落在宫内，空矩形这张盘上什么都报不出来',
    );
    expect(AdvancedTechniques.findSkyscraper(board), isNull);
    expect(AdvancedTechniques.findTwoStringKite(board), isNull);

    final hint = AdvancedTechniques.findTurbotFish(board);
    expect(hint, isNotNull, reason: '没有别的报法接得住，这条链只能算一般多宝鱼');
    expect(hint!.technique, '多宝鱼');
    expect(elimKeys(hint), {'1,3,5', '1,5,5'});
    expectEliminationsPresent(board, hint);
    expectEvidenceBeyondTargets(hint);
  });

  test('空矩形真的读得出同一条链同一个删除时，一般多宝鱼让位', () {
    final board = _realEmptyRectangleBoard();

    final er = AdvancedTechniques.findEmptyRectangle(board);
    expect(er, isNotNull, reason: '这张盘上空矩形本来就成立');
    expect(elimKeys(er!), {'4,1,5'});

    expect(
      AdvancedTechniques.findTurbotFish(board),
      isNull,
      reason: '链和删除都跟空矩形那一手一样，一般多宝鱼不该抢报',
    );
  });

  test('多宝鱼教学盘面上报出的删除都不在唯一解里', () {
    final puzzle = _tech('turbot').examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);
    final hint = AdvancedTechniques.findTurbotFish(board);

    expect(hint, isNotNull, reason: '教学盘面上应找得到一般多宝鱼');
    expect(hint!.technique, '多宝鱼');
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(puzzle, hint);
    expectEvidenceBeyondTargets(hint);
  });

  test('多宝鱼名字进了难度分表和提示顺序，且排在 Swordfish 与带鳍 X-Wing 之间', () {
    final order = SudokuSolver.hintSearchOrder;
    expect(order, contains('多宝鱼'));
    expect(order.indexOf('多宝鱼'), greaterThan(order.indexOf('Swordfish')));
    expect(order.indexOf('多宝鱼'), lessThan(order.indexOf('带鳍 X-Wing')));
    expect(order.indexOf('摩天楼'), lessThan(order.indexOf('多宝鱼')));
    expect(order.indexOf('双线风筝'), lessThan(order.indexOf('多宝鱼')));
    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('多宝鱼', 40),
      reason: '评审总表给多宝鱼的难度是 4.0',
    );
  });
}
