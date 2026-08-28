import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

/// Type 1 只多出一格。那一格要是多出好几个候选，结论不是「填哪一个」，
/// 而是「底数一个都填不了」——该删的是它身上的全部底数，而不是整块放弃。
final _type1 = <String, SudokuHint? Function(SudokuBoard)>{
  '扩展矩形 Type 1': AdvancedTechniques.findExtendedRectType1,
  '唯一环 Type 1': AdvancedTechniques.findUniqueLoopType1,
};

List<String> _bank(String name) =>
    PuzzleBank.parse(File('assets/puzzles/$name.txt').readAsStringSync());

void main() {
  test('唯一那一格多出好几个候选时，Type 1 删掉它身上的全部底数', () {
    final cases = <String>[];
    for (final name in PuzzleBank.difficulties) {
      for (final puzzle in _bank(name)) {
        final solved = SudokuBoard.fromString(puzzle);
        expect(SudokuSolver.solve(solved), isTrue);
        final board = SudokuBoard.fromString(puzzle);
        for (var step = 0; step < 200; step++) {
          if (board.isComplete()) break;
          _type1.forEach((technique, find) {
            final hint = find(board);
            if (hint == null || !hint.isElimination) return;
            cases.add('$technique @ $name');

            final cells = {
              for (final e in hint.eliminations) '${e.row},${e.col}'
            };
            expect(
              cells,
              hasLength(1),
              reason: '$technique 的结论只落在那一格上',
            );
            final target = hint.eliminations.first;
            final struck = {
              for (final c in hint.patternCandidates)
                if (c.role == HintRole.target &&
                    c.ref.row == target.row &&
                    c.ref.col == target.col)
                  c.ref.num
            };
            expect(
              {for (final e in hint.eliminations) e.num},
              struck,
              reason: '$technique 要把删掉的底数逐个标出来',
            );
            final extras = {
              for (final c in hint.patternCandidates)
                if (c.role == HintRole.extra &&
                    c.ref.row == target.row &&
                    c.ref.col == target.col)
                  c.ref.num
            };
            expect(
              extras.length,
              greaterThanOrEqualTo(2),
              reason: '只多出一个候选时应当直接填，不走删除',
            );
            expect(
              struck.intersection(extras),
              isEmpty,
              reason: '多余候选不是结论，不能跟着一起删',
            );
            for (final e in hint.eliminations) {
              expect(
                solved.get(e.row, e.col) == e.num,
                isFalse,
                reason: '$technique 删了正解 '
                    'r${e.row + 1}c${e.col + 1}=${e.num}',
              );
              expect(board.getCandidates(e.row, e.col), contains(e.num));
            }
            expect(
              hint.patternCandidates.any((c) => c.role == HintRole.pattern),
              isTrue,
              reason: '$technique 要把结构格上的底数标成依据',
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
    expect(
      cases,
      isNotEmpty,
      reason: '题库里应当走到过「唯一那一格多出好几个候选」的 Type 1，否则这条路根本没被走过',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  group('题库里挑出来的两张定盘', () {
    /// 把一张题按提示顺序往下走，直到 [find] 报出一条删除。
    SudokuHint walkTo(String puzzle, SudokuHint? Function(SudokuBoard) find) {
      final board = SudokuBoard.fromString(puzzle);
      for (var step = 0; step < 200; step++) {
        final found = find(board);
        if (found != null && found.isElimination) return found;
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
      fail('这张盘上没走到多余候选不止一个的 Type 1');
    }

    void expectSound(String puzzle, SudokuHint hint) {
      final solved = SudokuBoard.fromString(puzzle);
      expect(SudokuSolver.solve(solved), isTrue);
      for (final e in hint.eliminations) {
        expect(
          solved.get(e.row, e.col) == e.num,
          isFalse,
          reason: '删了正解 r${e.row + 1}c${e.col + 1}=${e.num}',
        );
      }
    }

    test('扩展矩形 Type 1：r7c3 多出好几个候选，三个底数一起删', () {
      const puzzle =
          '410905062380072019000004000168000007050040030700000285'
          '000700000840260073570408021';
      final hint = walkTo(puzzle, AdvancedTechniques.findExtendedRectType1);
      expect(hint.technique, '扩展矩形 Type 1');
      expect(elimKeys(hint), {'6,2,2', '6,2,6', '6,2,9'});
      expectSound(puzzle, hint);
      expect(hint.explanation, contains('都可以删'));
    });

    test('唯一环 Type 1：r3c3 多出好几个候选，两个底数一起删', () {
      const puzzle =
          '500700032100326000000000000020070058010803040890040070'
          '000000000000654001230009005';
      final hint = walkTo(puzzle, AdvancedTechniques.findUniqueLoopType1);
      expect(hint.technique, '唯一环 Type 1');
      expect(elimKeys(hint), {'2,2,8', '2,2,9'});
      expectSound(puzzle, hint);
      expect(hint.explanation, contains('都可以删'));
    });
  });

  test('只多出一个候选时仍然是填数，不是删除', () {
    final board = SudokuBoard.fromString(
      '000004028000000000000060900000000000900000000000000000'
      '000000000000000000000000000',
    );
    // 教学盘那一手是填数，这里只钉住「单个多余候选走填数」这条分支不变。
    final hint = AdvancedTechniques.findExtendedRectType1(board);
    expect(hint == null || !hint.isElimination, isTrue);
  });
}
