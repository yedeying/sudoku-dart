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
  group('飞鱼导弹', () {
    test('教学盘：开局第一步就是飞鱼导弹，目标格删掉 5 和 6', () {
      final puzzle = _tech('exocet').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findExocet(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '飞鱼导弹');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), {'1,3,5', '0,6,6'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expect(_cellKeys(hint, HintRole.pattern), {'2,0', '2,1'});
      expect(_cellKeys(hint, HintRole.cover), {'1,3', '0,6'});
      expect(hint.highlightRows, containsAll([0, 1, 2]));
      expect(hint.highlightCols, containsAll([2, 3, 6]));
      expect(SudokuSolver.getHint(board)!.technique, '飞鱼导弹');
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
      // 教学盘 r1c4=7 是伴随格。改成基格数字 1 之后，
      // 这对对象格就能装两个基格数字，JE 不再成立。
      final raw = _tech('exocet').examplePuzzle;
      final broken = '${raw.substring(0, 3)}1${raw.substring(4)}';
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

    test('按难度排在毛刺数组之后、分类强制链之前，并开放教学页', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('飞鱼导弹'));
      expect(
        order.indexOf('毛刺数组'),
        lessThan(order.indexOf('飞鱼导弹')),
      );
      expect(order.indexOf('飞鱼导弹'), lessThan(order.indexOf('分类强制链')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('飞鱼导弹', 97));
      expect(_tech('exocet').teachingOnly, isFalse);
    });
  });
}
