import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

/// 题库里的一张残局：数字 7 在 r3、r4、r6 上的候选，
/// 合起来只落在 c8 和中带的两个宫里，是一条 Swordfish 规格的 Franken 鱼。
const _frankenPuzzle =
    '070000010000040000600208009860000091300106007002000300000070000050804030906305702';

/// 只把 r1、r4、r5 上的 5 收进 c1、c4、c7，其余各行的 5 原样留着。
/// c7 上的两格 r4c7、r5c7 同在 b6，于是这组基既能用三条列覆盖，也能用 c1+c4+b6。
SudokuBoard _lineCoverFirstBoard() {
  final board = SudokuBoard.fromString(List.filled(81, '0').join());
  void keep(int row, List<int> cols) {
    for (var col = 0; col < 9; col++) {
      if (!cols.contains(col)) board.eliminateCandidate(row, col, 5);
    }
  }

  keep(0, [0, 3]);
  keep(3, [3, 6]);
  keep(4, [0, 6]);
  return board;
}

void main() {
  test('Franken 鱼能读出 Swordfish 规格：三条基线对 c8 加两个宫', () {
    expect(
      SudokuSolver.countSolutions(
        SudokuBoard.fromString(_frankenPuzzle),
        limit: 2,
      ),
      1,
    );
    final board = SudokuBoard.fromString(_frankenPuzzle);

    final hint = AdvancedTechniques.findFrankenFish(board);

    expect(hint, isNotNull);
    expect(hint!.technique, 'Franken 鱼');
    expect(elimKeys(hint), {'1,7,7'}, reason: '只删得掉 7r2c8');
    expectEliminationsPresent(board, hint);
    expectEliminationsSound(_frankenPuzzle, hint);
    expectEvidenceBeyondTargets(hint);
    expect(hint.highlightRows, [2, 3, 5], reason: '三条基线要淡亮出来');
    expect(hint.explanation, contains('每个都必须给 7 留一个位置'));
  });

  test('先试出来的全行列覆盖不算数，换成带宫的覆盖照样要报', () {
    // r1、r3、r4 上的 5 落在 c1、c4、c7：先凑出来的 c1+c4+c7 是普通 Swordfish，
    // 但 c7 上那两格同在 b6 里，换成 c1+c4+b6 就是 Franken，还能多删 b6 里的三格。
    final board = _lineCoverFirstBoard();

    final hint = AdvancedTechniques.findFrankenFish(board);

    expect(hint, isNotNull, reason: '第一种覆盖不是 Franken，不代表这组基没有 Franken 读法');
    expect(hint!.technique, 'Franken 鱼');
    expect(hint.highlightRows, [0, 3, 4]);
    expect(
      elimKeys(hint),
      {
        for (final row in [1, 2, 5, 6, 7, 8]) '$row,0,5',
        for (final row in [1, 2, 5, 6, 7, 8]) '$row,3,5',
        '5,6,5',
        '5,7,5',
        '5,8,5',
      },
      reason: 'b6 里的 r6c7、r6c8、r6c9 只有用上宫的那种覆盖才删得掉',
    );
    expectEliminationsPresent(board, hint);
    expectEvidenceBeyondTargets(hint);
    expect(hint.explanation, contains('c1、c4、b6'), reason: '覆盖里真的用上了 b6');
  });

  test('普通行列鱼不改名叫 Franken', () {
    // 干净的 Swordfish：r1、r4、r7 上的 5 只落在 c1、c4、c7。
    // 三条基线分属三个横带，任何一个宫最多只盖得住其中一格，
    // 换不出带宫的完整覆盖，所以这张盘上 Franken 应当一无所获。
    final board = SudokuBoard.fromString(List.filled(81, '0').join());
    void keep(int row, List<int> cols) {
      for (var col = 0; col < 9; col++) {
        if (!cols.contains(col)) board.eliminateCandidate(row, col, 5);
      }
    }

    keep(0, [0, 3]);
    keep(3, [3, 6]);
    keep(6, [0, 6]);

    expect(
      AdvancedTechniques.findFrankenFish(board),
      isNull,
      reason: '普通行列鱼就该留给普通鱼去报，不能改名叫 Franken',
    );
  });

  test('扩档之后 Franken 搜索仍然在两秒内收工', () {
    final board = SudokuBoard.fromString(_frankenPuzzle);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 5; i++) {
      AdvancedTechniques.findFrankenFish(board);
    }
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}
