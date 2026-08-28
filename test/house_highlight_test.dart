import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/puzzle_bank.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

/// 关键房屋是一条具体房屋的技巧：虚拟格数组配在哪条房屋里、底数锁在哪条房屋里。
/// 这一族的提示必须把那条房屋标出来，不管它是行、是列还是宫。
final _houseFinders = <String, SudokuHint? Function(SudokuBoard)>{
  '扩展矩形 Type 3': AdvancedTechniques.findExtendedRectType3,
  '扩展矩形 Type 4': AdvancedTechniques.findExtendedRectType4,
  '唯一环 Type 3': AdvancedTechniques.findUniqueLoopType3,
  '唯一环 Type 4': AdvancedTechniques.findUniqueLoopType4,
  '全双值坟墓 Type 3': AdvancedTechniques.findBugType3,
  '全双值坟墓 Type 4': AdvancedTechniques.findBugType4,
  '唯一矩形 Type 3': AdvancedTechniques.findUniqueRectangleType3,
  '唯一矩形 Type 4': AdvancedTechniques.findUniqueRectangleType4,
};

List<String> _bank(String name) =>
    PuzzleBank.parse(File('assets/puzzles/$name.txt').readAsStringSync());

bool _houseHolds(String house, int row, int col) {
  final kind = house[0];
  final index = int.parse(house.substring(1));
  if (kind == 'r') return row == index;
  if (kind == 'c') return col == index;
  return (row ~/ 3) * 3 + col ~/ 3 == index;
}

List<String> _houses(SudokuHint hint) => [
      for (final r in hint.highlightRows) 'r$r',
      for (final c in hint.highlightCols) 'c$c',
      for (final b in hint.highlightBoxes) 'b$b',
    ];

/// 这一手里「参与那条房屋推理」的格子：带额外候选的例外格、配数组的伙伴格、
/// 成强链的两端。关键房屋必须同时罩住它们。
///
/// 结构本体（pattern）不算：致命形的地板格散在房屋外面是正常的。
List<List<int>> _inHouse(SudokuHint hint) => [
      for (final cell in hint.patternCells)
        if (cell.role == HintRole.extra || cell.role == HintRole.link)
          [cell.row, cell.col],
    ];

void main() {
  test('虚拟格数组和底数锁定这一族，关键房屋一定标得出来', () {
    final seen = <String>{};
    final boxCases = <String>[];
    for (final name in PuzzleBank.difficulties) {
      for (final puzzle in _bank(name)) {
        final board = SudokuBoard.fromString(puzzle);
        for (var step = 0; step < 200; step++) {
          if (board.isComplete()) break;
          _houseFinders.forEach((technique, find) {
            final hint = find(board);
            if (hint == null) return;
            seen.add(technique);
            final houses = _houses(hint);
            expect(
              houses,
              isNotEmpty,
              reason: '$technique 没标出关键房屋',
            );
            final inHouse = _inHouse(hint);
            expect(
              inHouse,
              isNotEmpty,
              reason: '$technique 一个参与房屋推理的格子都没标，这条房屋就成了空话',
            );
            for (final house in houses) {
              for (final cell in inHouse) {
                expect(
                  _houseHolds(house, cell[0], cell[1]),
                  isTrue,
                  reason: '$technique 淡亮的 $house 没罩住 '
                      'r${cell[0] + 1}c${cell[1] + 1}',
                );
              }
            }
            if (hint.highlightBoxes.isNotEmpty) {
              boxCases.add('$technique @ ${hint.highlightBoxes}');
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
    expect(seen, isNotEmpty, reason: '题库里一条都没走到，这个测试就白写了');
    expect(
      seen,
      hasLength(_houseFinders.length),
      reason: '这一族每一条都该在题库里走到过，漏了的那条等于没测：$seen',
    );
    // 唯一矩形的四个角正好压在两个宫上，两个例外格同行或同列时常常还共一个宫，
    // 所以宫那一种情况在题库默认轨迹上就会走到，不是纸上的分支。
    expect(
      boxCases,
      isNotEmpty,
      reason: '宫作为关键房屋的那一种情况一次都没走到，highlightBoxes 就成了死代码',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('关键房屋是宫时，提示标的是宫，图上也照着涂', () {
    // 这张盘顺着扩展矩形 Type 3 自己的删除往下走，第 27 步上虚拟格的数组
    // 只在 b5 里配得起来（r5、c6 上都配不成），于是关键房屋是一个宫。
    // 题库默认轨迹上碰不到这一种情况，所以单独钉一张盘。
    const puzzle =
        '236000591010050070008000400849000237000000000000428000'
        '097000140000306000580070026';
    final board = SudokuBoard.fromString(puzzle);
    final solved = SudokuBoard.fromString(puzzle);
    expect(SudokuSolver.solve(solved), isTrue);

    SudokuHint? boxed;
    for (var step = 0; step < 200; step++) {
      if (board.isComplete()) break;
      final own = AdvancedTechniques.findExtendedRectType3(board);
      if (own != null && own.highlightBoxes.isNotEmpty) {
        boxed = own;
        break;
      }
      if (own != null) {
        for (final e in own.eliminations) {
          board.eliminateCandidate(e.row, e.col, e.num);
        }
        continue;
      }
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

    expect(boxed, isNotNull, reason: '这张盘上应当走到关键房屋是宫的扩展矩形 Type 3');
    expect(boxed!.technique, '扩展矩形 Type 3');
    expect(boxed.highlightBoxes, [4]);
    expect(boxed.highlightRows, isEmpty);
    expect(boxed.highlightCols, isEmpty);
    expect(boxed.explanation, contains('b5'));
    for (final e in boxed.eliminations) {
      expect(
        solved.get(e.row, e.col) == e.num,
        isFalse,
        reason: '删了正解 r${e.row + 1}c${e.col + 1}=${e.num}',
      );
      expect(_houseHolds('b4', e.row, e.col), isTrue, reason: '删除都发生在 b5 里');
    }

    final markup = GameState.markupFromHint(boxed);
    for (var r = 3; r < 6; r++) {
      for (var c = 3; c < 6; c++) {
        expect(
          markup.cellColors,
          contains(BoardMarkup.cellKey(r, c)),
          reason: 'b5 里的 r${r + 1}c${c + 1} 应当有底色',
        );
      }
    }
    expect(markup.cellColors.containsKey(BoardMarkup.cellKey(0, 0)), isFalse);
  });
}
