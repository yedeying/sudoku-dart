import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

TechniqueInfo _tech(String id) =>
    TechniqueCatalog.all.firstWhere((t) => t.id == id);

Set<String> _cellKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCells)
        if (c.role == role) '${c.row},${c.col}',
    };

void main() {
  group('弱待定数组', () {
    test('教学盘：c7 上 1、5 占三格，两支都删 3/6 r3c7 和 3/8 r8c7', () {
      final puzzle = _tech('wals').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findWals(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '弱待定数组');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), {'2,6,3', '2,6,6', '7,6,3', '7,6,8'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(_cellKeys(hint, HintRole.pattern), {'1,6', '2,6', '7,6'});
      expect(hint.highlightCols, contains(6));
    });

    test('已经是隐性数对时不报弱待定数组', () {
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

    test('按难度排在死亡绽放之后、Kraken 之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('弱待定数组'));
      expect(
        order.indexOf('死亡绽放'),
        lessThan(order.indexOf('弱待定数组')),
      );
      expect(order.indexOf('弱待定数组'), lessThan(order.indexOf('Kraken Fish')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('弱待定数组', 96));
      expect(_tech('wals').teachingOnly, isFalse);
    });
  });
}
