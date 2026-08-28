import 'dart:io';
import 'dart:math' as math;

import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'finder_soundness.dart';

/// 还有唯余可填时，深层 finder 不该先出面。
bool hasNakedSingle(SudokuBoard board) {
  for (var r = 0; r < 9; r++) {
    for (var c = 0; c < 9; c++) {
      if (board.get(r, c) == 0 && board.getCandidates(r, c).length == 1) {
        return true;
      }
    }
  }
  return false;
}

bool hasHiddenSingle(SudokuBoard board) {
  bool houseHas(Iterable<List<int>> cells) {
    final counts = List<int>.filled(10, 0);
    for (final cell in cells) {
      if (board.get(cell[0], cell[1]) != 0) continue;
      for (final n in board.getCandidates(cell[0], cell[1])) {
        counts[n]++;
      }
    }
    return counts.any((n) => n == 1);
  }

  for (var i = 0; i < 9; i++) {
    if (houseHas([
      for (var c = 0; c < 9; c++) [i, c]
    ])) {
      return true;
    }
    if (houseHas([
      for (var r = 0; r < 9; r++) [r, i]
    ])) {
      return true;
    }
    final br = (i ~/ 3) * 3;
    final bc = (i % 3) * 3;
    if (houseHas([
      for (var r = br; r < br + 3; r++)
        for (var c = bc; c < bc + 3; c++) [r, c],
    ])) {
      return true;
    }
  }
  return false;
}

bool hasSingle(SudokuBoard board) =>
    hasNakedSingle(board) || hasHiddenSingle(board);

bool isDeepStop(SudokuHint? hint) =>
    hint == null ||
    hint.technique == 'Nishio' ||
    hint.technique == '分类强制链' ||
    hint.technique == '分类强制网';

void applyHint(SudokuBoard board, SudokuHint hint) {
  if (hint.isElimination) {
    for (final e in hint.eliminations) {
      board.eliminateCandidate(e.row, e.col, e.num);
    }
  } else {
    board.set(hint.row, hint.col, hint.value);
  }
}

int techniqueRank(String name) {
  final i = SudokuSolver.hintSearchOrder.indexOf(name);
  return i < 0 ? SudokuSolver.hintSearchOrder.length : i;
}

List<String> loadBank({Iterable<String>? grades}) {
  final out = <String>[];
  for (final name in grades ?? PuzzleBank.difficulties) {
    final file = File('assets/puzzles/$name.txt');
    if (!file.existsSync()) continue;
    out.addAll(PuzzleBank.parse(file.readAsStringSync()));
  }
  return out;
}

void _checkFound(String puzzle, SudokuHint found) {
  if (found.isElimination) {
    expectEliminationsSound(puzzle, found);
  } else {
    expectFillSound(puzzle, found);
  }
}

/// 沿 getHint 往下走。深层 finder 只在提示已经走到该技巧（或更后）时才调用。
int sweepFinder(
  String label,
  SudokuHint? Function(SudokuBoard) find, {
  String? until,
  void Function(String puzzle, SudokuBoard board, SudokuHint found)? onFound,
}) =>
    sweepFinders({label: find}, until: until, onFound: onFound)[label]!;

Map<String, int> sweepFinders(
  Map<String, SudokuHint? Function(SudokuBoard)> finders, {
  String? until,
  void Function(String puzzle, SudokuBoard board, SudokuHint found)? onFound,
}) {
  final emissions = {for (final name in finders.keys) name: 0};
  final minRank = finders.keys.map(techniqueRank).fold<int>(
        SudokuSolver.hintSearchOrder.length,
        math.min,
      );

  for (final puzzle in loadBank()) {
    final board = SudokuBoard.fromString(puzzle);
    for (var step = 0; step < 200; step++) {
      final hint = SudokuSolver.getHint(board, until: until);
      if (isDeepStop(hint)) break;
      final rank = techniqueRank(hint!.technique);
      if (rank >= minRank) {
        finders.forEach((label, find) {
          if (rank < techniqueRank(label)) return;
          final found = find(board);
          if (found == null) return;
          emissions[label] = emissions[label]! + 1;
          _checkFound(puzzle, found);
          onFound?.call(puzzle, board, found);
        });
      }
      applyHint(board, hint);
    }
  }
  for (final label in finders.keys) {
    // ignore: avoid_print
    print('$label 题库触发次数：${emissions[label]}');
  }
  return emissions;
}
