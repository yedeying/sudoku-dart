import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

SudokuHint _firstElimination(SudokuBoard board) {
  for (var step = 0; step < 200; step++) {
    final hint = SudokuSolver.getHint(board);
    expect(hint, isNotNull, reason: '走到删除之前盘面就不该没提示');
    if (hint!.isElimination) return hint;
    board.set(hint.row, hint.col, hint.value);
  }
  fail('200 步里没有删除提示');
}

void main() {
  test('目标候选已经被手划掉之后，不再报同一手删除', () {
    final puzzle = PuzzleBank.parse(
      File('assets/puzzles/normal.txt').readAsStringSync(),
    ).first;
    final board = SudokuBoard.fromString(puzzle);
    final first = _firstElimination(board);
    expect(first.eliminations, isNotEmpty);

    for (final e in first.eliminations) {
      expect(
        board.visibleCandidates(e.row, e.col),
        contains(e.num),
        reason: '这一手的目标当时必须还看得见',
      );
      board.toggleUserCandidate(e.row, e.col, e.num);
      expect(
        board.visibleCandidates(e.row, e.col),
        isNot(contains(e.num)),
        reason: '划掉之后提示不该再当它还在',
      );
    }

    final again = SudokuSolver.getHint(board);
    if (again == null) return;
    if (!again.isElimination) {
      expect(board.get(again.row, again.col), 0);
      return;
    }
    for (final e in again.eliminations) {
      expect(
        board.visibleCandidates(e.row, e.col),
        contains(e.num),
        reason: '${again.technique} 又要删 ${e.row},${e.col},${e.num}，'
            '但这一格已经看不见这个候选了',
      );
    }
  });

  test('手写多出来的候选，提示按可见盘面删掉它', () {
    // 显性数对教材：r1c1、r1c2 是 {1,4}。r1c7 引擎没有 1，手写补上后必须能删。
    final board = SudokuBoard.fromString(
      '006005009328009700700208010000000002030500090200090000070000001000000008000000000',
    );
    for (var step = 0; step < 200; step++) {
      final hint = SudokuSolver.getHint(board);
      expect(hint, isNotNull, reason: '走到显性数对之前盘面就不该没提示');
      if (hint!.technique == '显性数对') break;
      if (hint.isElimination) {
        for (final e in hint.eliminations) {
          board.eliminateCandidate(e.row, e.col, e.num);
        }
      } else {
        board.set(hint.row, hint.col, hint.value);
      }
    }

    expect(board.get(0, 6), 0);
    expect(board.visibleCandidates(0, 6), isNot(contains(1)));
    board.toggleUserCandidate(0, 6, 1);
    expect(board.visibleCandidates(0, 6), contains(1));

    final again = SudokuSolver.getHint(board);
    expect(again, isNotNull);
    expect(again!.isElimination, isTrue);
    expect(
      again.eliminations.any((e) => e.row == 0 && e.col == 6 && e.num == 1),
      isTrue,
      reason: '${again.technique} 没删 r1c7 手写的 1',
    );
  });
}
