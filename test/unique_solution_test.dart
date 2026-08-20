import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

void main() {
  group('唯一解计数', () {
    test('完整有效盘有且仅有 1 个解', () {
      final board = SudokuBoard.fromString(
        '534678912'
        '672195348'
        '198342567'
        '859761423'
        '426853791'
        '713924856'
        '961537284'
        '287419635'
        '345286179',
      );
      expect(SudokuSolver.countSolutions(board, limit: 2), 1);
      expect(SudokuSolver.hasUniqueSolution(board), isTrue);
    });

    test('多解题返回非唯一', () {
      // 挖掉过多格子导致多解的极简构造：几乎空盘
      final board = SudokuBoard.empty();
      expect(SudokuSolver.hasUniqueSolution(board), isFalse);
      expect(SudokuSolver.countSolutions(board, limit: 2), greaterThan(1));
    });

    test('标准唯一解题', () {
      final board = SudokuBoard.fromString(
        '530070000'
        '600195000'
        '098000060'
        '800060003'
        '400803001'
        '700020006'
        '060000280'
        '000419005'
        '000080079',
      );
      expect(SudokuSolver.hasUniqueSolution(board), isTrue);
    });
  });
}
