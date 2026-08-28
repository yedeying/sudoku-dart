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

void _sweep(
  String label,
  SudokuHint? Function(SudokuBoard) find,
) {
  var emissions = 0;
  for (final name in PuzzleBank.difficulties) {
    final puzzles = PuzzleBank.parse(
      File('assets/puzzles/$name.txt').readAsStringSync(),
    );
    for (final puzzle in puzzles) {
      final board = SudokuBoard.fromString(puzzle);
      for (var step = 0; step < 200; step++) {
        final found = find(board);
        if (found != null) {
          emissions++;
          if (found.isElimination) {
            expectEliminationsSound(puzzle, found);
          } else {
            expectFillSound(puzzle, found);
          }
        }
        final hint = SudokuSolver.getHint(board);
        if (hint == null ||
            hint.technique == 'Nishio' ||
            hint.technique == '分类强制链' ||
            hint.technique == '分类强制网') {
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
  print('$label 题库触发次数：$emissions');
}

void main() {
  group('强制唯一矩形', () {
    test('教学盘：三支都逼出 1r6c7，于是删 1r6c9 与 1r7c7', () {
      final puzzle = _tech('forcing_ur').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findForcingUr(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '强制唯一矩形');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), containsAll({'5,8,1', '6,6,1'}));
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(
        _cellKeys(hint, HintRole.pattern),
        containsAll({'3,2', '3,6', '5,2', '5,6'}),
      );
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('forcing_ur').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findForcingUr(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
      }
    });

    test('题库残局上的每一条删除都避开唯一解', () {
      _sweep('强制唯一矩形', AdvancedTechniques.findForcingUr);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在分类强制链之后、强制扩展矩形之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('强制唯一矩形'));
      expect(
        order.indexOf('分类强制链'),
        lessThan(order.indexOf('强制唯一矩形')),
      );
      expect(order.indexOf('强制唯一矩形'), lessThan(order.indexOf('强制扩展矩形')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('强制唯一矩形', 98));
      expect(_tech('forcing_ur').teachingOnly, isFalse);
    });
  });

  group('强制扩展矩形', () {
    test('教学盘：三支都删掉 1r9c9', () {
      final puzzle = _tech('forcing_er').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findForcingEr(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '强制扩展矩形');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), contains('8,8,1'));
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(
        _cellKeys(hint, HintRole.pattern),
        containsAll({'3,4', '4,4', '5,4', '3,8', '4,8', '5,8'}),
      );
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('forcing_er').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findForcingEr(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
      }
    });

    test('题库残局上的每一条删除都避开唯一解', () {
      _sweep('强制扩展矩形', AdvancedTechniques.findForcingEr);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在强制唯一矩形之后、强制唯一环之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('强制扩展矩形'));
      expect(order.indexOf('强制唯一矩形'), lessThan(order.indexOf('强制扩展矩形')));
      expect(order.indexOf('强制扩展矩形'), lessThan(order.indexOf('强制唯一环')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('强制扩展矩形', 98));
      expect(_tech('forcing_er').teachingOnly, isFalse);
    });
  });

  group('强制唯一环', () {
    test('教学盘：三支都删掉 2r1c1 与 2r7c2', () {
      final puzzle = _tech('forcing_ul').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findForcingUl(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '强制唯一环');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), containsAll({'0,0,2', '6,1,2'}));
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(
        _cellKeys(hint, HintRole.pattern),
        containsAll({'2,2', '2,8', '0,8', '0,5', '1,5', '1,2'}),
      );
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('forcing_ul').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findForcingUl(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
      }
    });

    test('题库残局上的每一条删除都避开唯一解', () {
      _sweep('强制唯一环', AdvancedTechniques.findForcingUl);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在强制扩展矩形之后、ALS-XY-Wing 之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('强制唯一环'));
      expect(order.indexOf('强制扩展矩形'), lessThan(order.indexOf('强制唯一环')));
      expect(order.indexOf('强制唯一环'), lessThan(order.indexOf('ALS-XY-Wing')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('强制唯一环', 98));
      expect(_tech('forcing_ul').teachingOnly, isFalse);
    });
  });
}
