import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/bank_sweep.dart';

/// 这一批新接入的 finder：名字 → 入口。
final _finders = <String, SudokuHint? Function(SudokuBoard)>{
  '多宝鱼': AdvancedTechniques.findTurbotFish,
  '刺身鱼': AdvancedTechniques.findSashimiFish,
  '不完整唯一矩形': AdvancedTechniques.findIncompleteUniqueRectangle,
  '可规避矩形': AdvancedTechniques.findAvoidableRectangle,
  '隐性唯一矩形': AdvancedTechniques.findHiddenUniqueRectangle,
  '全双值坟墓 Type 2': AdvancedTechniques.findBugType2,
  '全双值坟墓 Type 3': AdvancedTechniques.findBugType3,
  '全双值坟墓 Type 4': AdvancedTechniques.findBugType4,
  '宫内鱼': AdvancedTechniques.findFrankenFish,
  '扩展矩形 Type 1': AdvancedTechniques.findExtendedRectType1,
  '扩展矩形 Type 2': AdvancedTechniques.findExtendedRectType2,
  '扩展矩形 Type 3': AdvancedTechniques.findExtendedRectType3,
  '扩展矩形 Type 4': AdvancedTechniques.findExtendedRectType4,
  '唯一环 Type 1': AdvancedTechniques.findUniqueLoopType1,
  '唯一环 Type 2': AdvancedTechniques.findUniqueLoopType2,
  '唯一环 Type 3': AdvancedTechniques.findUniqueLoopType3,
  '唯一环 Type 4': AdvancedTechniques.findUniqueLoopType4,
  '探长致命结构': AdvancedTechniques.findBorescoper,
  '淑芬致命结构': AdvancedTechniques.findQiu,
  '死环': AdvancedTechniques.findDeadLoop,
  '毛刺数组': AdvancedTechniques.findBurredSubset,
  'DDS': AdvancedTechniques.findDds,
  '弱待定数组': AdvancedTechniques.findWals,
  '飞鱼导弹': AdvancedTechniques.findExocet,
  '待定唯一矩形': AdvancedTechniques.findPendingUr,
  '待定扩展矩形': AdvancedTechniques.findPendingEr,
  '待定唯一环': AdvancedTechniques.findPendingUl,
  '待定全双值坟墓': AdvancedTechniques.findPendingBug,
  '强制唯一矩形': AdvancedTechniques.findForcingUr,
  '强制扩展矩形': AdvancedTechniques.findForcingEr,
  '强制唯一环': AdvancedTechniques.findForcingUl,
};

List<String> _expertBank() {
  final out = <String>[];
  for (final grade in ['professional', 'master', 'hell']) {
    out.addAll(loadBank(grades: [grade]).take(20));
  }
  return out;
}

/// 把一张题走到浅层技巧再也推不动为止。
SudokuBoard _stall(String puzzle) {
  final board = SudokuBoard.fromString(puzzle);
  for (var step = 0; step < 200; step++) {
    if (board.isComplete()) break;
    final hint = SudokuSolver.getHint(board);
    if (isDeepStop(hint)) break;
    applyHint(board, hint!);
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
        final hint = SudokuSolver.getHint(board, until: '飞鱼导弹');
        if (hint == null) break;
        if (_finders.containsKey(hint.technique)) {
          if (!hint.isElimination) {
            expect(
              solved.get(hint.row, hint.col),
              hint.value,
              reason: '${hint.technique} 填错了 r${hint.row + 1}c${hint.col + 1}',
            );
          }
          for (final e in hint.eliminations) {
            expect(
              solved.get(e.row, e.col) == e.num,
              isFalse,
              reason:
                  '${hint.technique} 删了正解 r${e.row + 1}c${e.col + 1}=${e.num}',
            );
          }
          expect(
            hint.patternCandidates.any((c) => c.role != HintRole.target),
            isTrue,
            reason: '${hint.technique} 只标了结论，没标依据',
          );
        }
        applyHint(board, hint);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
