import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

SudokuBoard _emptyBoard() =>
    SudokuBoard.fromString(List.filled(81, '0').join());

void _setCandidates(
  SudokuBoard board,
  int row,
  int col,
  Set<int> wanted,
) {
  for (var digit = 1; digit <= 9; digit++) {
    if (!wanted.contains(digit)) {
      board.eliminateCandidate(row, col, digit);
    }
  }
}

Set<String> _eliminationKeys(SudokuHint hint) =>
    hint.eliminations.map((e) => '${e.row},${e.col},${e.num}').toSet();

void main() {
  // 提示搜索顺序按评审的「难度」列排，隐性数对、行/列区块都排在四数组前面，
  // 所以这两条不能用 getHint 去测——那只会测出「谁排得更前」。
  // 四数组该测的是它自己认不认得出这个图形，所以直接叫对应的 finder。
  test('显性四数组认得出四格锁四数，并删掉单元内其它候选', () {
    final board = _emptyBoard();
    _setCandidates(board, 0, 0, {1, 2});
    _setCandidates(board, 0, 1, {2, 3});
    _setCandidates(board, 0, 2, {3, 4});
    _setCandidates(board, 0, 3, {1, 4});
    _setCandidates(board, 0, 4, {1, 2, 3, 4, 5});
    _setCandidates(board, 1, 0, {1, 5, 6});
    _setCandidates(board, 1, 1, {2, 5, 6});
    for (var col = 2; col < 9; col++) {
      _setCandidates(board, 1, col, {1, 2, 3, 4, 7, 8, 9});
    }

    final hint = AdvancedTechniques.findNakedQuad(board);

    expect(hint, isNotNull);
    expect(hint!.technique, '显性四数组');
    expect(hint.isElimination, isTrue);
    expect(
      _eliminationKeys(hint),
      {
        '0,4,1',
        '0,4,2',
        '0,4,3',
        '0,4,4',
        '0,5,1',
        '0,5,2',
        '0,5,3',
        '0,5,4',
        '0,6,1',
        '0,6,2',
        '0,6,3',
        '0,6,4',
        '0,7,1',
        '0,7,2',
        '0,7,3',
        '0,7,4',
        '0,8,1',
        '0,8,2',
        '0,8,3',
        '0,8,4',
      },
    );
  });

  test('隐性四数组认得出四数只落四格，并删掉这四格里的其它候选', () {
    final board = _emptyBoard();
    _setCandidates(board, 0, 0, {1, 2, 5, 6});
    _setCandidates(board, 0, 1, {2, 3, 5, 7});
    _setCandidates(board, 0, 2, {3, 4, 6, 8});
    _setCandidates(board, 0, 3, {1, 4, 7, 9});
    for (var col = 4; col < 9; col++) {
      _setCandidates(board, 0, col, {5, 6, 7, 8, 9});
    }

    final hint = AdvancedTechniques.findHiddenQuad(board);

    expect(hint, isNotNull);
    expect(hint!.technique, '隐性四数组');
    expect(hint.isElimination, isTrue);
    expect(
      _eliminationKeys(hint),
      {
        '0,0,5',
        '0,0,6',
        '0,1,5',
        '0,1,7',
        '0,2,6',
        '0,2,8',
        '0,3,7',
        '0,3,9',
      },
    );
  });
}
