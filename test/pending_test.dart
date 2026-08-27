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
  for (final name in ['easy', 'medium', 'hard', 'expert']) {
    final puzzles = PuzzleBank.parse(
      File('assets/puzzles/$name.txt').readAsStringSync(),
    );
    for (final puzzle in puzzles) {
      final board = SudokuBoard.fromString(puzzle);
      for (var step = 0; step < 200; step++) {
        final found = find(board);
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
  print('$label 题库触发次数：$emissions');
}

void main() {
  group('待定唯一矩形', () {
    test('教学盘：{2,8} 矩形上 9r2c9 与 5r7c8 作强链，能推出删除', () {
      final puzzle = _tech('pending_ur').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findPendingUr(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '待定唯一矩形');
      expect(hint.isElimination, isTrue);
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(
        _cellKeys(hint, HintRole.pattern),
        containsAll({'1,7', '1,8', '6,7', '6,8'}),
      );
    });

    test('Type 2 那种同数字互见不报待定', () {
      final board = SudokuBoard.fromString(_tech('ur2').examplePuzzle);
      expect(AdvancedTechniques.findPendingUr(board), isNull);
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('pending_ur').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findPendingUr(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
      }
    });

    test('题库残局上的每一条删除都避开唯一解', () {
      _sweep('待定唯一矩形', AdvancedTechniques.findPendingUr);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在死环之后、ALS-XZ 之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('待定唯一矩形'));
      expect(order.indexOf('死环'), lessThan(order.indexOf('待定唯一矩形')));
      expect(order.indexOf('待定唯一矩形'), lessThan(order.indexOf('ALS-XZ')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('待定唯一矩形', 94));
      expect(_tech('pending_ur').teachingOnly, isFalse);
    });
  });

  group('待定扩展矩形', () {
    test('教学盘：六格 {2,5,7} 上 3r3c8 与 8r9c9 作强链，能推出删除', () {
      final puzzle = _tech('pending_er').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findPendingEr(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '待定扩展矩形');
      expect(hint.isElimination, isTrue);
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(
        _cellKeys(hint, HintRole.pattern),
        containsAll({'2,6', '2,7', '2,8', '8,6', '8,7', '8,8'}),
      );
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('pending_er').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findPendingEr(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
      }
    });

    test('题库残局上的每一条删除都避开唯一解', () {
      _sweep('待定扩展矩形', AdvancedTechniques.findPendingEr);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在 DDS 之后、待定唯一环之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('待定扩展矩形'));
      expect(order.indexOf('DDS'), lessThan(order.indexOf('待定扩展矩形')));
      expect(order.indexOf('待定扩展矩形'), lessThan(order.indexOf('待定唯一环')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('待定扩展矩形', 95));
      expect(_tech('pending_er').teachingOnly, isFalse);
    });
  });

  group('待定唯一环', () {
    test('教学盘：六格 {7,8} 环上 3r7c2 与 4r9c9 作强链，能推出删除', () {
      final puzzle = _tech('pending_ul').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findPendingUl(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '待定唯一环');
      expect(hint.isElimination, isTrue);
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(
        _cellKeys(hint, HintRole.pattern),
        containsAll({'6,1', '6,3', '7,3', '7,8', '8,8', '8,1'}),
      );
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('pending_ul').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findPendingUl(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
      }
    });

    test('题库残局上的每一条删除都避开唯一解', () {
      _sweep('待定唯一环', AdvancedTechniques.findPendingUl);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在待定扩展矩形之后、待定 BUG 之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('待定唯一环'));
      expect(order.indexOf('待定扩展矩形'), lessThan(order.indexOf('待定唯一环')));
      expect(order.indexOf('待定唯一环'), lessThan(order.indexOf('待定 BUG')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('待定唯一环', 95));
      expect(_tech('pending_ul').teachingOnly, isFalse);
    });
  });

  group('待定 BUG', () {
    test('教学盘：7r7c1 与 2r9c4 作死盘节点，删 2r8c4', () {
      final puzzle = _tech('pending_bug').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findPendingBug(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '待定 BUG');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), contains('7,3,2'));
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(_cellKeys(hint, HintRole.extra), containsAll({'6,0', '8,3'}));
    });

    test('Type 2 那种同数字互见不报待定', () {
      final board = SudokuBoard.fromString(_tech('bug_type2').examplePuzzle);
      expect(AdvancedTechniques.findPendingBug(board), isNull);
    });

    test('教学盘和空盘都在两秒内收工', () {
      for (final board in [
        SudokuBoard.fromString(_tech('pending_bug').examplePuzzle),
        SudokuBoard.empty(),
      ]) {
        final sw = Stopwatch()..start();
        AdvancedTechniques.findPendingBug(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000));
      }
    });

    test('题库残局上的每一条删除都避开唯一解', () {
      _sweep('待定 BUG', AdvancedTechniques.findPendingBug);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('按难度排在待定唯一环之后、Death Blossom 之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('待定 BUG'));
      expect(order.indexOf('待定唯一环'), lessThan(order.indexOf('待定 BUG')));
      expect(order.indexOf('待定 BUG'), lessThan(order.indexOf('Death Blossom')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('待定 BUG', 95));
      expect(_tech('pending_bug').teachingOnly, isFalse);
    });
  });
}
