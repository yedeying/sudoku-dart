import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

SudokuBoard _blank() => SudokuBoard.fromString(List.filled(81, '0').join());

String _puzzleWith(Map<int, int> givens) {
  final cells = List.filled(81, '0');
  givens.forEach((index, digit) => cells[index] = '$digit');
  return cells.join();
}

List<String> _bank() {
  final puzzles = <String>[];
  for (final level in PuzzleBank.difficulties) {
    puzzles.addAll(
      PuzzleBank.parse(File('assets/puzzles/$level.txt').readAsStringSync()),
    );
  }
  return puzzles;
}

void main() {
  test('三个角是玩家填的，第四个角不能补成致命矩形', () {
    final board = _blank();
    board.set(0, 0, 5);
    board.set(0, 3, 6);
    board.set(1, 0, 6);

    final hint = AdvancedTechniques.findAvoidableRectangle(board);

    expect(hint, isNotNull);
    expect(hint!.technique, '可规避矩形');
    expect(elimKeys(hint), {'1,3,5'});
    expectEliminationsPresent(board, hint);
    expectEvidenceBeyondTargets(hint);
    expect(
      hint.patternCells.map((c) => '${c.row},${c.col}'),
      containsAll(['0,0', '0,3', '1,0']),
      reason: '三个已填的角是这一步的依据，要标出来',
    );
  });

  test('同样的三个数字若是题目给定，就不能报可规避矩形', () {
    final board = SudokuBoard.fromString(
      _puzzleWith({0: 5, 3: 6, 9: 6}),
    );
    expect(board.isInitial(0, 0), isTrue);
    expect(board.getCandidates(1, 3), contains(5));
    expect(
      AdvancedTechniques.findAvoidableRectangle(board),
      isNull,
      reason: '已知数本身就把整块对调堵死，矩形不致命',
    );
  });

  test('四个角都空着时不报可规避矩形', () {
    final board = _blank();
    void keep(int row, int col, List<int> digits) {
      for (var digit = 1; digit <= 9; digit++) {
        if (!digits.contains(digit)) board.eliminateCandidate(row, col, digit);
      }
    }

    keep(0, 0, [5, 6]);
    keep(0, 3, [5, 6]);
    keep(1, 0, [5, 6]);
    keep(1, 3, [5, 6, 7]);

    expect(AdvancedTechniques.findAvoidableRectangle(board), isNull);
  });

  test('题库残局里报出的可规避矩形都站得住', () {
    final puzzles = _bank();
    var hits = 0;
    for (final puzzle in puzzles) {
      final solved = SudokuBoard.fromString(puzzle);
      if (!SudokuSolver.solve(solved)) continue;
      final board = SudokuBoard.fromString(puzzle);
      for (var step = 0; step < 200; step++) {
        if (board.isComplete()) break;
        final sw = Stopwatch()..start();
        final ar = AdvancedTechniques.findAvoidableRectangle(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
        if (ar != null) {
          hits++;
          expect(ar.technique, '可规避矩形');
          expectEliminationsPresent(board, ar);
          expectEvidenceBeyondTargets(ar);
          for (final e in ar.eliminations) {
            expect(
              solved.get(e.row, e.col) == e.num,
              isFalse,
              reason: '可规避矩形删了正解 r${e.row + 1}c${e.col + 1}=${e.num}',
            );
          }
          for (final cell in ar.patternCells) {
            expect(
              board.isInitial(cell.row, cell.col),
              isFalse,
              reason: '矩形上的角不能是已知数',
            );
          }
          break;
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
    expect(hits, greaterThan(10), reason: '题库里应该常常走到可规避矩形');
  });

  test('可规避矩形排在 BUG+1 之后、唯一矩形 Type 4 之前，难度分 5.5', () {
    final order = SudokuSolver.hintSearchOrder;
    expect(order, contains('可规避矩形'));
    expect(order.indexOf('BUG+1'), lessThan(order.indexOf('可规避矩形')));
    expect(order.indexOf('可规避矩形'), lessThan(order.indexOf('唯一矩形 Type 4')));
    expect(
      order.indexOf('唯一矩形 Type 1'),
      lessThan(order.indexOf('可规避矩形')),
      reason: '基础唯一矩形先报',
    );
    expect(DifficultyAnalyzer.techniqueScores, containsPair('可规避矩形', 55));
    expect(
      TechniqueCatalog.all
          .firstWhere((t) => t.id == 'avoidable_rect')
          .teachingOnly,
      isFalse,
    );
  });
}
