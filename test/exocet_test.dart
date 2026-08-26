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
  group('飞鱼导弹', () {
    test('教学盘：中带 JE，目标格删掉非基格数字 1、9 和 4', () {
      final puzzle = _tech('exocet').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findExocet(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '飞鱼导弹');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), {'5,2,1', '5,2,9', '3,6,4'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(_cellKeys(hint, HintRole.pattern), {'4,3', '4,5'});
      expect(_cellKeys(hint, HintRole.cover), {'5,2', '3,6'});
      expect(hint.highlightRows, containsAll([3, 4, 5]));
      expect(hint.highlightCols, containsAll([2, 4, 6]));
    });

    test('基格候选并集只有两个数字时不报', () {
      final board = SudokuBoard.empty();
      var fill = 4;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (r == 4 && (c == 3 || c == 5)) continue;
          board.set(r, c, fill);
          fill = fill == 9 ? 4 : fill + 1;
        }
      }
      for (final cell in [
        [4, 3],
        [4, 5]
      ]) {
        for (var d = 1; d <= 9; d++) {
          if (d > 2) board.eliminateCandidate(cell[0], cell[1], d);
        }
      }
      expect(AdvancedTechniques.findExocet(board), isNull);
    });

    test('伴随格带着基格数字时整枚导弹不成立', () {
      // 教学盘 r4c3=7 是伴随格。改成基格数字 2 之后，
      // 这对对象格就能装两个基格数字，JE 不再成立。
      final raw = _tech('exocet').examplePuzzle;
      final broken = raw.substring(0, 29) + '2' + raw.substring(30);
      expect(AdvancedTechniques.findExocet(SudokuBoard.fromString(broken)),
          isNull);
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('exocet').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findExocet(board);
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
            final found = AdvancedTechniques.findExocet(board);
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
      print('飞鱼导弹 题库触发次数：$emissions');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在毛刺数组之后、Forcing Chain 之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('飞鱼导弹'));
      expect(
        order.indexOf('毛刺数组'),
        lessThan(order.indexOf('飞鱼导弹')),
      );
      expect(order.indexOf('飞鱼导弹'), lessThan(order.indexOf('Forcing Chain')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('飞鱼导弹', 97));
      expect(_tech('exocet').teachingOnly, isFalse);
    });
  });
}
