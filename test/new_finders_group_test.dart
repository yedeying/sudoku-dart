import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

/// 这一批新接入的 finder：名字 → 入口。
final _finders = <String, SudokuHint? Function(SudokuBoard)>{
  '多宝鱼': AdvancedTechniques.findTurbotFish,
  '刺身鱼': AdvancedTechniques.findSashimiFish,
  '不完整唯一矩形': AdvancedTechniques.findIncompleteUniqueRectangle,
  '可规避矩形': AdvancedTechniques.findAvoidableRectangle,
  '隐性唯一矩形': AdvancedTechniques.findHiddenUniqueRectangle,
  'BUG 类型 2': AdvancedTechniques.findBugType2,
  'BUG 类型 3': AdvancedTechniques.findBugType3,
  'BUG 类型 4': AdvancedTechniques.findBugType4,
  'Franken 鱼': AdvancedTechniques.findFrankenFish,
  '扩展矩形 1': AdvancedTechniques.findExtendedRectType1,
  '扩展矩形 2': AdvancedTechniques.findExtendedRectType2,
  '扩展矩形 3': AdvancedTechniques.findExtendedRectType3,
  '扩展矩形 4': AdvancedTechniques.findExtendedRectType4,
  '唯一环 1': AdvancedTechniques.findUniqueLoopType1,
  '唯一环 2': AdvancedTechniques.findUniqueLoopType2,
  '唯一环 3': AdvancedTechniques.findUniqueLoopType3,
  '唯一环 4': AdvancedTechniques.findUniqueLoopType4,
  '探长': AdvancedTechniques.findBorescoper,
  '淑芬': AdvancedTechniques.findQiu,
  '死环': AdvancedTechniques.findDeadLoop,
  '毛刺数组': AdvancedTechniques.findBurredSubset,
  'DDS': AdvancedTechniques.findDds,
  'WALS': AdvancedTechniques.findWals,
  '飞鱼导弹': AdvancedTechniques.findExocet,
  '待定唯一矩形': AdvancedTechniques.findPendingUr,
  '待定扩展矩形': AdvancedTechniques.findPendingEr,
  '待定唯一环': AdvancedTechniques.findPendingUl,
  '待定 BUG': AdvancedTechniques.findPendingBug,
};

List<String> _expertBank() =>
    PuzzleBank.parse(File('assets/puzzles/expert.txt').readAsStringSync());

/// 把一张题走到浅层技巧再也推不动为止。
SudokuBoard _stall(String puzzle) {
  final board = SudokuBoard.fromString(puzzle);
  for (var step = 0; step < 200; step++) {
    if (board.isComplete()) break;
    final hint = SudokuSolver.getHint(board);
    if (hint == null) break;
    if (hint.technique == 'Nishio' ||
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
  return board;
}

void main() {
  test('卡住的残局上，新接入的每个 finder 都在两秒内收工', () {
    for (final puzzle in _expertBank().take(8)) {
      final board = _stall(puzzle);
      _finders.forEach((name, find) {
        final sw = Stopwatch()..start();
        find(board);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000), reason: '$name 搜得太久');
      });
      final sw = Stopwatch()..start();
      SudokuSolver.getHint(board);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000), reason: 'getHint 搜得太久');
    }
  });

  test('题库走一遍，新 finder 报的删除没有一条落在唯一解上', () {
    for (final puzzle in _expertBank()) {
      final solved = SudokuBoard.fromString(puzzle);
      expect(SudokuSolver.solve(solved), isTrue);
      final board = SudokuBoard.fromString(puzzle);
      for (var step = 0; step < 200; step++) {
        if (board.isComplete()) break;
        _finders.forEach((name, find) {
          final found = find(board);
          if (found == null) return;
          expect(found.technique, name);
          if (!found.isElimination) {
            expect(
              solved.get(found.row, found.col),
              found.value,
              reason: '$name 填错了 r${found.row + 1}c${found.col + 1}',
            );
          }
          for (final e in found.eliminations) {
            expect(
              solved.get(e.row, e.col) == e.num,
              isFalse,
              reason: '$name 删了正解 r${e.row + 1}c${e.col + 1}=${e.num}',
            );
            expect(
              board.getCandidates(e.row, e.col),
              contains(e.num),
              reason: '$name 要删的候选已经不在盘上了',
            );
          }
          expect(
            found.patternCandidates.any((c) => c.role != HintRole.target),
            isTrue,
            reason: '$name 只标了结论，没标依据',
          );
        });
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
  }, timeout: const Timeout(Duration(minutes: 3)));
}
