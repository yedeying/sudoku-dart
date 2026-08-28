import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/puzzle_grade.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

void main() {
  test('六级按最高技巧分档', () {
    expect(PuzzleGrades.gradeForTechnique('唯余法'), PuzzleGrade.beginner);
    expect(PuzzleGrades.gradeForTechnique('摒除法（行/列/宫）'), PuzzleGrade.beginner);
    expect(PuzzleGrades.gradeForTechnique('显性数对'), PuzzleGrade.normal);
    expect(PuzzleGrades.gradeForTechnique('X-Wing'), PuzzleGrade.advanced);
    expect(PuzzleGrades.gradeForTechnique('XY-Chain'), PuzzleGrade.professional);
    expect(PuzzleGrades.gradeForTechnique('Kraken Fish'), PuzzleGrade.master);
    expect(PuzzleGrades.gradeForTechnique('Nishio'), PuzzleGrade.hell);
    expect(
      PuzzleGrades.gradeForTechniques(['唯余法', 'X-Wing', '显性数对']),
      PuzzleGrade.advanced,
    );
  });

  test('经典入门盘判为入门', () {
    final board = SudokuBoard.fromString(
      '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    );
    final result = DifficultyAnalyzer.analyzeDifficulty(board);
    expect(result.level, 'beginner');
    expect(DifficultyAnalyzer.validateDifficulty(board, 'beginner'), isTrue);
    expect(DifficultyAnalyzer.validateDifficulty(board, 'advanced'), isFalse);
  });

  test('多解题不入档', () {
    final board = SudokuBoard.fromString(
      '040082003006400701300600000000025060002907835008006029004060372030070000200034910',
    );
    expect(SudokuSolver.countSolutions(board, limit: 2), greaterThan(1));
    expect(DifficultyAnalyzer.analyzeDifficulty(board).level, 'invalid');
  });

  test('hint 顺序里的每个技巧都有档', () {
    for (final name in SudokuSolver.hintSearchOrder) {
      expect(
        PuzzleGrades.gradeForTechnique(name).index,
        inInclusiveRange(0, 5),
        reason: name,
      );
    }
  });
}
