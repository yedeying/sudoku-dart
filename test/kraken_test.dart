import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

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

/// 数字 5 在 r1、r9 只落在 c1、c5，r6 的 5r6c1 看得见其中一端。
///
/// 旧实现会把 r1 上那对共轭报成 Kraken；这其实是普通 X-Wing，没有鳍。
SudokuBoard _conjugateOnlyBoard() {
  final board = _emptyBoard();
  _keepOnly(board, 5, _row(0), [
    [0, 0],
    [0, 4],
  ]);
  _keepOnly(board, 5, _row(5), [
    [5, 0],
  ]);
  _keepOnly(board, 5, _row(8), [
    [8, 0],
    [8, 4],
  ]);
  for (final row in [1, 2, 3, 4, 6, 7]) {
    _keepOnly(board, 5, _row(row), const []);
  }
  return board;
}

/// 带鳍 X-Wing：r1 / r3 几乎覆盖 c1 / c5，鳍在 r1c8。
///
/// 覆盖线上的 5r7c1 看不到鳍，普通带鳍鱼删不掉它。
/// 鳍为真时 r9 只剩 5r9c1，填进去之后同列的 5r7c1 被排除。
SudokuBoard _krakenXWingBoard() {
  final board = _emptyBoard();
  _keepOnly(board, 5, _row(0), [
    [0, 0],
    [0, 4],
    [0, 7],
  ]);
  _keepOnly(board, 5, _row(2), [
    [2, 0],
    [2, 4],
  ]);
  _keepOnly(board, 5, _row(6), [
    [6, 0],
    [6, 2],
  ]);
  _keepOnly(board, 5, _row(8), [
    [8, 0],
    [8, 7],
  ]);
  for (final row in [1, 3, 4, 5, 7]) {
    _keepOnly(board, 5, _row(row), const []);
  }
  return board;
}

void main() {
  test('共轭强链不是 Kraken Fish', () {
    final hint = AdvancedTechniques.findKrakenFish(_conjugateOnlyBoard());
    expect(hint, isNull, reason: '一对共轭加看得见的一端，不是带鳍鱼接链');
  });

  test('旧教学盘上的共轭读法不再叫 Kraken', () {
    final board = SudokuBoard.fromString(
      '083020090000800100029300008000098700070000060006740000300006980002005000010030540',
    );
    final hint = AdvancedTechniques.findKrakenFish(board);
    expect(
      hint == null ||
          hint.highlightRows.length >= 2 ||
          hint.highlightCols.length >= 2,
      isTrue,
      reason: '真 Kraken 必须从至少两条基线的几乎鱼出发',
    );
  });

  test('带鳍 X-Wing 的远程鳍用唯余链删掉看不到鳍的覆盖候选', () {
    final board = _krakenXWingBoard();
    final hint = AdvancedTechniques.findKrakenFish(board);
    expect(hint, isNotNull);
    expect(hint!.technique, 'Kraken Fish');
    expect(hint.isElimination, isTrue);
    expect(elimKeys(hint), contains('6,0,5'));
    expect(hint.highlightRows, containsAll([0, 2]));
    expect(
      hint.patternCells.where((c) => c.role == HintRole.extra),
      isNotEmpty,
      reason: '必须标出鳍',
    );
    expect(
      hint.patternCandidates.where((c) => c.role == HintRole.link),
      isNotEmpty,
      reason: '鳍出发的唯余链应标在候选上',
    );
    expect(
      hint.links.where((a) => a.kind == ArrowKind.weak),
      isNotEmpty,
    );
    expect(hint.explanation, contains('鳍'));
    expect(hint.explanation, contains('→'));
    expectEliminationsPresent(board, hint);
    expectEvidenceBeyondTargets(hint);
  });

  test('鳍出发的唯余链不超过六步', () {
    final hint = AdvancedTechniques.findKrakenFish(
      SudokuBoard.fromString(
        '050703060007000800000816000000030000005000100730040086906000204840572093000409000',
      ),
    );
    if (hint == null) return;
    final linkCount =
        hint.patternCandidates.where((c) => c.role == HintRole.link).length;
    expect(
      linkCount,
      lessThanOrEqualTo(12),
      reason: '两枚鳍各至多六步唯余，不能把整盘推完再叫 Kraken',
    );
  });

  test('教学盘连点提示能走到 Kraken Fish', () {
    final puzzle = TechniqueCatalog.all
        .firstWhere((t) => t.id == 'kraken')
        .examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);
    SudokuHint? hint;
    for (var i = 0; i < 200; i++) {
      hint = SudokuSolver.getHint(board);
      if (hint == null) break;
      if (hint.technique == 'Kraken Fish') break;
      if (hint.isElimination) {
        for (final e in hint.eliminations) {
          board.eliminateCandidate(e.row, e.col, e.num);
        }
      } else {
        board.set(hint.row, hint.col, hint.value);
      }
      if (board.isComplete()) break;
    }
    expect(hint, isNotNull);
    expect(
      hint!.technique,
      'Kraken Fish',
      reason: '更浅的技巧不该把这盘做完，连点提示必须报到 Kraken',
    );
    expect(
      hint.highlightRows.length >= 2 || hint.highlightCols.length >= 2,
      isTrue,
    );
    expect(
      hint.patternCells.where((c) => c.role == HintRole.extra),
      isNotEmpty,
      reason: '必须标出鳍',
    );
    expect(hint.explanation, contains('鳍'));
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(puzzle, hint);
    expectEvidenceBeyondTargets(hint);
  });

  test('教学盘上找得到图上那条带鳍 X-Wing 接链', () {
    final puzzle = TechniqueCatalog.all
        .firstWhere((t) => t.id == 'kraken')
        .examplePuzzle;
    final board = SudokuBoard.fromString(puzzle);
    final hint = AdvancedTechniques.findKrakenFish(board);
    expect(hint, isNotNull);
    expect(hint!.technique, 'Kraken Fish');
    expect(elimKeys(hint), {'6,5,1'});
    expect(hint.highlightRows, containsAll([0, 1]));
    expect(
      {
        for (final c in hint.patternCells)
          if (c.role == HintRole.extra) '${c.row},${c.col}'
      },
      {'0,3', '1,6'},
    );
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(puzzle, hint);
  });

  test('看得见全部鳍的删除留给带鳍鱼', () {
    final board = SudokuBoard.fromString(
      '089250467076948032000367589020694375934715826765823941258136794493572618607489253',
    );
    final finned = AdvancedTechniques.findFinnedXWing(board);
    expect(finned, isNotNull);
    final kraken = AdvancedTechniques.findKrakenFish(board);
    if (kraken != null) {
      expect(
        elimKeys(kraken).intersection(elimKeys(finned!)),
        isEmpty,
        reason: '同一处普通带鳍删除不该改叫 Kraken',
      );
    }
  });
}
