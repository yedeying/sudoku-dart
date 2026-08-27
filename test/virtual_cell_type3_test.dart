import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

/// 走虚拟格数组这一族。
final _type3 = <String, SudokuHint? Function(SudokuBoard)>{
  '扩展矩形 Type 3': AdvancedTechniques.findExtendedRectType3,
  '唯一环 Type 3': AdvancedTechniques.findUniqueLoopType3,
  'BUG Type 3': AdvancedTechniques.findBugType3,
};

List<String> _bank(String name) =>
    PuzzleBank.parse(File('assets/puzzles/$name.txt').readAsStringSync());

/// 例外格 → 它多出来的那些候选。
Map<String, Set<int>> _extrasByCell(SudokuHint hint) {
  final out = <String, Set<int>>{};
  for (final c in hint.patternCandidates) {
    if (c.role != HintRole.extra) continue;
    out.putIfAbsent('${c.ref.row},${c.ref.col}', () => <int>{}).add(c.ref.num);
  }
  return out;
}

void main() {
  test('例外格多出好几个候选时，不画那条并不成立的强链', () {
    var multi = 0;
    for (final name in ['easy', 'medium', 'hard', 'expert']) {
      for (final puzzle in _bank(name)) {
        final board = SudokuBoard.fromString(puzzle);
        for (var step = 0; step < 200; step++) {
          if (board.isComplete()) break;
          _type3.forEach((technique, find) {
            final hint = find(board);
            if (hint == null) return;
            final extras = _extrasByCell(hint);
            final wide = extras.values.where((s) => s.length > 1).length;
            final strong =
                hint.links.where((l) => l.kind == ArrowKind.strong).toList();
            if (wide == 0) {
              // 两边各只多出一个候选，「这个或那个」是条真强链，照画。
              expect(
                strong,
                hasLength(1),
                reason: '$technique 两边各一个多余候选，应当画出强链',
              );
              return;
            }
            multi++;
            expect(
              strong,
              isEmpty,
              reason: '$technique 有一格多出 $wide 组候选，'
                  '「某个具体候选或某个具体候选」并不成立，不能画成强链',
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
    }
    expect(multi, greaterThan(0), reason: '题库里应当走到过多余候选不止一个的 Type 3');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('例外格自己：虚拟格里的候选一个都不许删，虚拟格外的数组数字可以删', () {
    var ownerElims = 0;
    for (final name in ['easy', 'medium', 'hard', 'expert']) {
      for (final puzzle in _bank(name)) {
        final solved = SudokuBoard.fromString(puzzle);
        expect(SudokuSolver.solve(solved), isTrue);
        final board = SudokuBoard.fromString(puzzle);
        for (var step = 0; step < 200; step++) {
          if (board.isComplete()) break;
          _type3.forEach((technique, find) {
            final hint = find(board);
            if (hint == null) return;
            final extras = _extrasByCell(hint);
            final virtual = <int>{for (final s in extras.values) ...s};
            for (final e in hint.eliminations) {
              expect(
                solved.get(e.row, e.col) == e.num,
                isFalse,
                reason: '$technique 删了正解 '
                    'r${e.row + 1}c${e.col + 1}=${e.num}',
              );
              final key = '${e.row},${e.col}';
              if (!extras.containsKey(key)) continue;
              ownerElims++;
              expect(
                virtual,
                isNot(contains(e.num)),
                reason: '$technique 把虚拟格自己的候选 $key=${e.num} 删了——'
                    '不知道是哪一格跳出底数，这就是把完整性约束当裸对用',
              );
            }
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
    }
    expect(
      ownerElims,
      greaterThan(0),
      reason: '数组数字里凡是落在虚拟格之外的，例外格上也该跟着删；题库里一次都没删过说明这一种情况没实现',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
