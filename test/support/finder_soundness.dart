import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'teaching_verifier.dart';

/// finder 报出来的删除，逐条拿盘面的唯一解核对。
///
/// 这是所有新 finder 的共同底线：一条删除只要出现在唯一解里，这个 finder 就是错的，
/// 再漂亮的图示也救不回来。和教学页那套复核一样，这里只用回溯求解器，
/// 不碰任何 finder 自己的推理。
void expectEliminationsSound(String puzzle, SudokuHint hint) {
  final solution = uniqueSolution(puzzle);
  expect(solution, isNotNull, reason: '盘面必须唯一解才谈得上核对删除');
  for (final e in hint.eliminations) {
    expect(
      solution![e.row][e.col],
      isNot(e.num),
      reason: '${hint.technique} 要删 ${e.num}r${e.row + 1}c${e.col + 1}，'
          '但唯一解那一格正是 ${e.num}',
    );
  }
}

/// 填数结论必须和唯一解一致。
void expectFillSound(String puzzle, SudokuHint hint) {
  final solution = uniqueSolution(puzzle);
  expect(solution, isNotNull, reason: '盘面必须唯一解才谈得上核对填数');
  expect(
    solution![hint.row][hint.col],
    hint.value,
    reason: '${hint.technique} 说 r${hint.row + 1}c${hint.col + 1} 填 ${hint.value}，'
        '唯一解那一格是 ${solution[hint.row][hint.col]}',
  );
}

Set<String> elimKeys(SudokuHint hint) =>
    {for (final e in hint.eliminations) '${e.row},${e.col},${e.num}'};

/// 提示必须标出「留下来的」依据，只把要删的标红等于没解释。
void expectEvidenceBeyondTargets(SudokuHint hint) {
  expect(hint.patternCells, isNotEmpty, reason: '${hint.technique} 没有标出任何格子');
  expect(hint.patternCandidates, isNotEmpty, reason: '${hint.technique} 没有标出任何候选');
  final targets = elimKeys(hint);
  final evidence = hint.patternCandidates.where(
    (c) => !targets.contains('${c.ref.row},${c.ref.col},${c.ref.num}'),
  );
  expect(evidence, isNotEmpty, reason: '${hint.technique} 只标了结论，没标依据');
}

/// 提示要删的候选此刻真的还在盘上，否则这一步等于没走。
void expectEliminationsPresent(SudokuBoard board, SudokuHint hint) {
  expect(hint.eliminations, isNotEmpty, reason: '${hint.technique} 一个候选都没删');
  for (final e in hint.eliminations) {
    expect(
      board.getCandidates(e.row, e.col),
      contains(e.num),
      reason: '${hint.technique} 要删 ${e.num}r${e.row + 1}c${e.col + 1}，'
          '可那一格本来就没有这个候选',
    );
  }
}
