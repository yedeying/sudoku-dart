import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
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
  group('DDS', () {
    test('教学盘：六格六数分到 c1、左下宫、r8，片外删除 1/5/8 和 4', () {
      final puzzle = _tech('dds').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findDds(board);

      expect(hint, isNotNull);
      expect(hint!.technique, 'DDS');
      expect(hint.isElimination, isTrue);
      expect(
        elimKeys(hint),
        {'3,0,1', '3,0,5', '3,0,8', '6,2,4', '8,1,4', '8,2,4'},
      );
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(
        _cellKeys(hint, HintRole.pattern),
        {'1,0', '4,0', '6,0', '7,1', '7,2', '7,5'},
      );
      expect(
        _cellKeys(hint, HintRole.target),
        {'3,0', '6,2', '8,1', '8,2'},
      );
      expect(hint.highlightCols, contains(0));
      expect(hint.highlightRows, contains(7));
      expect(hint.highlightBoxes, contains(6));
    });

    test('全部格子落在同一个房屋里时按显性数组处理，不报 DDS', () {
      final board = SudokuBoard.empty();
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (r == 0 && c < 6) continue;
          board.set(r, c, ((r + c) % 9) + 1);
        }
      }
      for (var c = 0; c < 6; c++) {
        for (var d = 1; d <= 9; d++) {
          if (d > 6) board.eliminateCandidate(0, c, d);
        }
      }
      expect(AdvancedTechniques.findDds(board), isNull);
    });

    test('两条房屋就装得下每个数字时不冒充三个以上区域', () {
      final board = SudokuBoard.fromString(_tech('sue_de_coq').examplePuzzle);
      final hint = AdvancedTechniques.findDds(board);
      expect(hint, isNull, reason: 'Sue de Coq 教学盘不该被 DDS 抢走');
    });

    test('某个数字在结构里只落一格时不报', () {
      final board = SudokuBoard.empty();
      // 三格三个数字，其中 7 只出现一次，是摒除不是 DDS。
      final keep = <String, Set<int>>{
        '0,0': {1, 2},
        '1,0': {1, 2},
        '2,3': {2, 7},
      };
      var fill = 3;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (keep.containsKey('$r,$c')) continue;
          board.set(r, c, fill);
          fill = fill == 9 ? 3 : fill + 1;
        }
      }
      for (final entry in keep.entries) {
        final p = entry.key.split(',');
        final r = int.parse(p[0]), c = int.parse(p[1]);
        for (var d = 1; d <= 9; d++) {
          if (!entry.value.contains(d)) board.eliminateCandidate(r, c, d);
        }
      }
      expect(AdvancedTechniques.findDds(board), isNull);
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('dds').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findDds(board);
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
            final found = AdvancedTechniques.findDds(board);
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
      print('DDS 题库触发次数：$emissions');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在 ALS-XZ 之后、Death Blossom 之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('DDS'));
      expect(order.indexOf('ALS-XZ'), lessThan(order.indexOf('DDS')));
      expect(order.indexOf('DDS'), lessThan(order.indexOf('Death Blossom')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('DDS', 95));
      expect(_tech('dds').teachingOnly, isFalse);
    });
  });
}
