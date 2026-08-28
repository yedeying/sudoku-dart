import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

/// 直接读随包题库，覆盖面比手写几道题大得多。
List<String> _bank() {
  final out = <String>[];
  for (final name in PuzzleBank.difficulties) {
    out.addAll(
      PuzzleBank.parse(File('assets/puzzles/$name.txt').readAsStringSync()),
    );
  }
  return out;
}

/// 走一遍逻辑解题，把每一步的提示交给 check。
Set<String> _walk(String puzzle, void Function(SudokuHint) check) {
  final board = SudokuBoard.fromString(puzzle);
  final seen = <String>{};
  for (int step = 0; step < 400; step++) {
    final hint = SudokuSolver.getHint(board);
    if (hint == null) break;
    check(hint);
    seen.add(hint.technique);
    if (hint.isElimination) {
      final changed = board.eliminateCandidates(
        [
          for (final e in hint.eliminations) [e.row, e.col, e.num]
        ],
      );
      expect(changed, true, reason: '${hint.technique} 没有删掉任何候选');
    } else {
      board.set(hint.row, hint.col, hint.value);
    }
  }
  return seen;
}

void main() {
  test('每一步提示都在棋盘上标出依据，而不只标结论', () {
    final covered = <String>{};
    final puzzles = _bank();
    expect(puzzles.length, greaterThan(100));

    for (final puzzle in puzzles) {
      covered.addAll(_walk(puzzle, (hint) {
        final why = hint.technique;
        expect(hint.patternCells, isNotEmpty, reason: '$why 没有标出任何格子');
        expect(hint.patternCandidates, isNotEmpty, reason: '$why 没有标出任何候选');

        // 必须有「留下来的」候选被标出：那才是删除的依据，
        // 只把要删的标红等于没解释。
        final targets = {
          for (final e in hint.eliminations) '${e.row},${e.col},${e.num}',
        };
        final evidence = hint.patternCandidates
            .where((c) =>
                !targets.contains('${c.ref.row},${c.ref.col},${c.ref.num}'))
            .toList();
        expect(evidence, isNotEmpty, reason: '$why 只标了结论，没标依据');
      }));
    }

    print('覆盖到的技巧（${covered.length} 种）: ${covered.toList()..sort()}');
    expect(covered.length, greaterThanOrEqualTo(10));
    for (final must in ['唯余法', '宫区块', '行/列区块']) {
      expect(covered, contains(must));
    }

    // 技巧名同时是难度表的键，漏一个就会被算成未知技巧。
    for (final name in covered) {
      expect(
        DifficultyAnalyzer.techniqueScores.containsKey(name),
        true,
        reason: '$name 没有难度分',
      );
    }
  });
}
