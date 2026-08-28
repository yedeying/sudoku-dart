import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

void _apply(SudokuBoard board, SudokuHint hint) {
  if (hint.isElimination) {
    for (final e in hint.eliminations) {
      board.eliminateCandidate(e.row, e.col, e.num);
    }
  } else {
    board.set(hint.row, hint.col, hint.value);
  }
}

bool _walksTo(String puzzle, String id) {
  final board = SudokuBoard.fromString(puzzle);
  for (var i = 0; i < 200; i++) {
    final hint = SudokuSolver.getHint(board);
    if (hint == null) return false;
    if (TechniqueCatalog.byName(hint.technique)?.id == id) return true;
    if (hint.technique == 'Nishio' ||
        hint.technique == '分类强制链' ||
        hint.technique == '分类强制网') {
      return id == TechniqueCatalog.byName(hint.technique)?.id;
    }
    _apply(board, hint);
    if (board.isComplete()) return false;
  }
  return false;
}

void main() {
  test('链与强制档教学盘连点提示能走到本技巧', () {
    // 这一档是「用此盘对局」会直接载入示意图盘的高阶条目。
    // 题库里还挖不到、或 finder 在填数快照上认不出来的，先记在这里：
    // 示意图只保证结构成立，不保证连点提示会报到这一手。
    const schematicOnly = {
      'als_xy',
      'death_blossom',
      'forcing_chain',
      'forcing_net',
      'franken_fish',
      'dead_loop',
      'qdp',
      'pending_ur',
      'pending_bug',
      'pending_er',
      'pending_ul',
      'dds',
      'forcing_ur',
      'forcing_er',
      'forcing_ul',
      'ul2',
      'ul3',
      'ul4',
      'wals',
      'burr_array',
      'bdp',
    };
    final misses = <String>[];
    for (final t in TechniqueCatalog.all) {
      if (t.teachingOnly) continue;
      if (t.rank < 552) continue;
      if (schematicOnly.contains(t.id)) continue;
      if (!_walksTo(t.examplePuzzle, t.id)) {
        misses.add('${t.id}（${t.name}）');
      }
    }
    expect(misses, isEmpty, reason: '这些教学盘连点提示走不到本技巧：$misses');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
