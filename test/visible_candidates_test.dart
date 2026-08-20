import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';

void main() {
  test('笔记加上 2 不会丢掉自动候选 8', () {
    final board = SudokuBoard.fromString(
      '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    );
    // (0,2) is empty in this classic puzzle; force auto set to {8}
    board.candidates[0][2] = {8};
    board.userCandidates[0][2] = {};
    board.toggleUserCandidate(0, 2, 2);
    expect(board.visibleCandidates(0, 2), {2, 8});
    expect(board.getCandidates(0, 2), {8});
    expect(board.getUserCandidates(0, 2), {2});
  });
}
