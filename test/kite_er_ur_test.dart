import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

SudokuBoard _emptyBoard() =>
    SudokuBoard.fromString(List.filled(81, '0').join());

void _removeDigitExcept(
  SudokuBoard board,
  int digit,
  Iterable<List<int>> cells,
  Iterable<List<int>> keep,
) {
  final keepKeys = {for (final cell in keep) '${cell[0]},${cell[1]}'};
  for (final cell in cells) {
    final key = '${cell[0]},${cell[1]}';
    if (!keepKeys.contains(key)) {
      board.eliminateCandidate(cell[0], cell[1], digit);
    }
  }
}

void _stripDigits(SudokuBoard board, int row, int col, Iterable<int> digits) {
  for (final digit in digits) {
    board.eliminateCandidate(row, col, digit);
  }
}

Set<String> _elimKeys(SudokuHint hint) =>
    hint.eliminations.map((e) => '${e.row},${e.col},${e.num}').toSet();

void main() {
  test('双线风筝删除同时看见两个远端的候选', () {
    final board = _emptyBoard();
    _removeDigitExcept(
      board,
      5,
      [
        for (var col = 0; col < 9; col++) [0, col]
      ],
      [
        [0, 1],
        [0, 7],
      ],
    );
    _removeDigitExcept(
      board,
      5,
      [
        for (var row = 0; row < 9; row++) [row, 2]
      ],
      [
        [1, 2],
        [8, 2],
      ],
    );

    final hint = SudokuSolver.getHint(board);

    expect(hint, isNotNull);
    expect(hint!.technique, '双线风筝');
    expect(hint.isElimination, isTrue);
    expect(_elimKeys(hint), {'8,7,5'});
    expect(hint.links.where((a) => a.kind == ArrowKind.strong), hasLength(2));
    expect(hint.links.where((a) => a.kind == ArrowKind.weak), hasLength(1));
    expect(hint.patternCells, isNotEmpty);
  });

  test('空矩形配合宫外强链删除远端候选', () {
    final board = _emptyBoard();
    // 宫 0 内 (1,0)(1,1)(2,0)(2,1) 没有 5，形成空矩形。
    for (final cell in [
      [1, 0],
      [1, 1],
      [2, 0],
      [2, 1],
    ]) {
      board.eliminateCandidate(cell[0], cell[1], 5);
    }
    _removeDigitExcept(
      board,
      5,
      [
        for (var row = 0; row < 9; row++) [row, 7]
      ],
      [
        [0, 7],
        [5, 7],
      ],
    );

    final hint = SudokuSolver.getHint(board);

    expect(hint, isNotNull);
    expect(hint!.technique, '空矩形');
    expect(hint.isElimination, isTrue);
    expect(_elimKeys(hint), {'5,2,5'});
  });

  test('唯一矩形 Type 2 删除额外数字的共同可见处', () {
    final board = _emptyBoard();
    _stripDigits(board, 0, 0, [3, 4, 5, 6, 7, 8, 9]);
    _stripDigits(board, 0, 3, [3, 4, 5, 6, 7, 8, 9]);
    _stripDigits(board, 1, 0, [3, 4, 6, 7, 8, 9]);
    _stripDigits(board, 1, 3, [3, 4, 6, 7, 8, 9]);
    for (var col = 0; col < 9; col++) {
      if (col == 0 || col == 3) continue;
      _stripDigits(board, 0, col, [1, 2]);
    }

    final hint = SudokuSolver.getHint(board);

    expect(hint, isNotNull);
    expect(hint!.technique, '唯一矩形 Type 2');
    expect(hint.explanation, contains('题目保证唯一解'));
    expect(hint.isElimination, isTrue);
    expect(
      _elimKeys(hint),
      {
        '1,1,5',
        '1,2,5',
        '1,4,5',
        '1,5,5',
        '1,6,5',
        '1,7,5',
        '1,8,5',
      },
    );
  });

  test('唯一矩形 Type 3 把额外候选当数组删除', () {
    final board = _emptyBoard();
    _stripDigits(board, 0, 0, [3, 4, 5, 6, 7, 8, 9]);
    _stripDigits(board, 0, 3, [3, 4, 5, 6, 7, 8, 9]);
    _stripDigits(board, 1, 0, [3, 4, 7, 8, 9]);
    _stripDigits(board, 1, 3, [3, 4, 7, 8, 9]);
    _stripDigits(board, 1, 1, [1, 2, 3, 4, 7, 8, 9]);
    for (var col = 0; col < 9; col++) {
      if (col == 0 || col == 3) continue;
      _stripDigits(board, 0, col, [1, 2]);
    }

    final hint = SudokuSolver.getHint(board);

    expect(hint, isNotNull);
    expect(hint!.technique, '唯一矩形 Type 3');
    expect(hint.explanation, contains('题目保证唯一解'));
    expect(hint.isElimination, isTrue);
    expect(
      _elimKeys(hint),
      {
        '1,2,5',
        '1,2,6',
        '1,4,5',
        '1,4,6',
        '1,5,5',
        '1,5,6',
        '1,6,5',
        '1,6,6',
        '1,7,5',
        '1,7,6',
        '1,8,5',
        '1,8,6',
      },
    );
  });

  test('唯一矩形 Type 4 利用强链删除矩形内另一数字', () {
    final board = _emptyBoard();
    _stripDigits(board, 0, 0, [3, 4, 5, 6, 7, 8, 9]);
    _stripDigits(board, 0, 3, [3, 4, 5, 6, 7, 8, 9]);
    _stripDigits(board, 1, 0, [3, 4, 8, 9]);
    _stripDigits(board, 1, 3, [3, 4, 8, 9]);
    for (var col = 0; col < 9; col++) {
      if (col == 0 || col == 3) continue;
      _stripDigits(board, 0, col, [1, 2]);
      _stripDigits(board, 1, col, [1]);
    }
    for (var col = 6; col < 9; col++) {
      board.eliminateCandidate(2, col, 1);
    }

    final hint = SudokuSolver.getHint(board);
    expect(hint, isNotNull);
    expect(hint!.technique, 'X-Wing');

    final type4 = AdvancedTechniques.findUniqueRectangleType4(board);
    expect(type4, isNotNull);
    expect(type4!.technique, '唯一矩形 Type 4');
    expect(type4.explanation, contains('题目保证唯一解'));
    expect(type4.isElimination, isTrue);
    expect(_elimKeys(type4), {'1,0,2', '1,3,2'});
  });
}
