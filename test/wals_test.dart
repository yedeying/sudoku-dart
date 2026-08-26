import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

TechniqueInfo _tech(String id) =>
    TechniqueCatalog.all.firstWhere((t) => t.id == id);

Set<String> _cellKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCells)
        if (c.role == role) '${c.row},${c.col}',
    };

void main() {
  group('WALS', () {
    test('教学盘：c7 上 1、5 占三格，两支都删 3/6 r3c7 和 3/8 r8c7', () {
      final puzzle = _tech('wals').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findWals(board);

      expect(hint, isNotNull);
      expect(hint!.technique, 'WALS');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), {'2,6,3', '2,6,6', '7,6,3', '7,6,8'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(_cellKeys(hint, HintRole.pattern), {'1,6', '2,6', '7,6'});
      expect(hint.highlightCols, contains(6));
    });

    test('已经是隐性数对时不报 WALS', () {
      final board = SudokuBoard.empty();
      var fill = 3;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (c == 0 && (r == 0 || r == 1)) continue;
          board.set(r, c, fill);
          fill = fill == 9 ? 3 : fill + 1;
        }
      }
      for (final cell in [
        [0, 0],
        [1, 0]
      ]) {
        for (var d = 1; d <= 9; d++) {
          if (d > 2) board.eliminateCandidate(cell[0], cell[1], d);
        }
      }
      expect(AdvancedTechniques.findWals(board), isNull);
    });

    test('三格四数的 ALS 不冒充弱待定数组', () {
      final board = SudokuBoard.empty();
      var fill = 5;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (c == 0 && r < 3) continue;
          board.set(r, c, fill);
          fill = fill == 9 ? 5 : fill + 1;
        }
      }
      final keep = <int, Set<int>>{
        0: {1, 2, 3},
        1: {1, 2, 4},
        2: {1, 3, 4},
      };
      for (final entry in keep.entries) {
        for (var d = 1; d <= 9; d++) {
          if (!entry.value.contains(d)) {
            board.eliminateCandidate(entry.key, 0, d);
          }
        }
      }
      expect(AdvancedTechniques.findWals(board), isNull);
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('wals').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findWals(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
      }
    });

    test('题库残局上的每一条删除都避开唯一解', () {
      var emissions = 0;
      for (final name in ['easy', 'medium', 'hard', 'expert']) {
        final puzzles = PuzzleBank.parse(
          File('assets/puzzles/$name.txt').readAsStringSync(),
        );
        for (final puzzle in puzzles) {
          final board = SudokuBoard.fromString(puzzle);
          for (var step = 0; step < 200; step++) {
            final found = AdvancedTechniques.findWals(board);
            if (found != null) {
              emissions++;
              expectEliminationsSound(puzzle, found);
            }
            final hint = SudokuSolver.getHint(board);
            if (hint == null ||
                hint.technique == 'Nishio' ||
                hint.technique == 'Forcing Chain' ||
                hint.technique == 'Forcing Net') {
              break;
            }
            if (hint.isElimination) {
              for (final e in hint.eliminations) {
                board.eliminateCandidate(e.row, e.col, e.num);
              }
            } else {
              board.set(hint.row, hint.col, hint.value);
            }
          }
        }
      }
      // ignore: avoid_print
      print('WALS 题库触发次数：$emissions');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在 Death Blossom 之后、Kraken 之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('WALS'));
      expect(
        order.indexOf('Death Blossom'),
        lessThan(order.indexOf('WALS')),
      );
      expect(order.indexOf('WALS'), lessThan(order.indexOf('Kraken Fish')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('WALS', 96));
      expect(_tech('wals').teachingOnly, isFalse);
    });
  });
}
