import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

import 'support/finder_soundness.dart';

TechniqueInfo _tech(String id) =>
    TechniqueCatalog.all.firstWhere((t) => t.id == id);

List<List<int>> _cells(SudokuHint hint, HintRole role) => [
      for (final c in hint.patternCells)
        if (c.role == role) [c.row, c.col],
    ];

Set<String> _candKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCandidates)
        if (c.role == role) '${c.ref.row},${c.ref.col},${c.ref.num}',
    };

/// 毛刺数组的计数，按评审正文逐条重数：N 格锁 N+1 个数字，
/// 多出来的那个数字只落在一格上，而且那一格不是双值格；
/// 把毛刺格拿掉之后剩下的格子不能已经自己锁住自己的数字。
void expectBurredSubset(
  SudokuBoard board,
  List<List<int>> cells,
  List<int> burr,
  int burrDigit,
) {
  expect(cells.length, greaterThanOrEqualTo(2), reason: '毛刺数组至少两格');
  final union = <int>{};
  for (final c in cells) {
    expect(board.get(c[0], c[1]), 0, reason: '给定数不能算进数组');
    final cands = board.getCandidates(c[0], c[1]);
    expect(cands.length, greaterThanOrEqualTo(2), reason: '单候选格是唯余法');
    union.addAll(cands);
  }
  expect(union, hasLength(cells.length + 1), reason: 'N 格要锁 N+1 个数字');
  expect(union, contains(burrDigit));

  final owners = cells
      .where((c) => board.getCandidates(c[0], c[1]).contains(burrDigit))
      .toList();
  expect(owners, hasLength(1), reason: '毛刺只许落在一格上');
  expect(owners.single, burr);
  expect(
    board.getCandidates(burr[0], burr[1]).length,
    greaterThanOrEqualTo(3),
    reason: '毛刺格是双值格的话，「有没有毛刺」就没得谈',
  );

  final rest = cells.where((c) => c[0] != burr[0] || c[1] != burr[1]).toList();
  final restUnion = <int>{};
  for (final c in rest) {
    restUnion.addAll(board.getCandidates(c[0], c[1]));
  }
  expect(restUnion.length, greaterThan(rest.length),
      reason: '去掉毛刺格就已经是显性数组的话，毛刺根本没参与推理');
}

void main() {
  group('毛刺数组', () {
    test('教学盘：r7 上三格锁四数，毛刺 7r7c8，两支交集删 2r7c7、5r7c7', () {
      final puzzle = _tech('burr_array').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findBurredSubset(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '毛刺数组');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), {'6,6,2', '6,6,5'});
      expectEliminationsSound(puzzle, hint);
      expectEliminationsPresent(board, hint);
      expectEvidenceBeyondTargets(hint);

      final cells = _cells(hint, HintRole.pattern);
      expect(
        {for (final c in cells) '${c[0]},${c[1]}'},
        {'6,0', '6,5', '6,7'},
      );
      expect(_candKeys(hint, HintRole.extra), {'6,7,7'},
          reason: '毛刺那一枚候选要单独标出来，它是推理节点不是删除对象');
      expectBurredSubset(board, cells, [6, 7], 7);
      expect(hint.highlightRows, contains(6), reason: '数组所在的那条房屋要亮出来');
    });

    test('甲支单独删掉的候选不算结论，只报两支的交集', () {
      final puzzle = _tech('burr_array').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      final hint = AdvancedTechniques.findBurredSubset(board)!;
      expect(elimKeys(hint), isNot(contains('6,6,4')),
          reason: '4r7c7 只在「毛刺为假」那一支里死，另一支没删到，报它就是错的');
      for (final e in hint.eliminations) {
        // 毛刺为真那一支：把毛刺填下去顺着唯余摒除推，这几个必须真的没了。
        final probe = SudokuBoard.fromString(puzzle);
        probe.set(6, 7, 7);
        var moved = true;
        while (moved) {
          moved = false;
          for (var r = 0; r < 9 && !moved; r++) {
            for (var c = 0; c < 9 && !moved; c++) {
              if (probe.get(r, c) != 0) continue;
              final cands = probe.getCandidates(r, c);
              if (cands.length == 1) {
                probe.set(r, c, cands.single);
                moved = true;
              }
            }
          }
        }
        expect(
          probe.get(e.row, e.col) == e.num ||
              (probe.get(e.row, e.col) == 0 &&
                  probe.getCandidates(e.row, e.col).contains(e.num)),
          isFalse,
          reason: '${e.num}r${e.row + 1}c${e.col + 1} 在「毛刺为真」那一支里没死，不能删',
        );
      }
    });

    test('数组里同一个数字只落两格时，那条弱链才画得出来', () {
      final board = SudokuBoard.fromString(_tech('burr_array').examplePuzzle);
      final hint = AdvancedTechniques.findBurredSubset(board)!;
      final cellKeys = {
        for (final c in _cells(hint, HintRole.pattern)) '${c[0]},${c[1]}'
      };
      for (final link in hint.links) {
        expect(link.kind, ArrowKind.weak, reason: '数组内部同数字只有弱链，没有强链');
        expect(link.from.num, link.to.num);
        expect(cellKeys, contains('${link.from.row},${link.from.col}'));
        expect(cellKeys, contains('${link.to.row},${link.to.col}'));
        final count = _cells(hint, HintRole.pattern)
            .where(
                (c) => board.getCandidates(c[0], c[1]).contains(link.from.num))
            .length;
        expect(count, 2, reason: '一个数字落到三格上就不是一条弱链，画出来是撒谎');
      }
    });

    test('拿掉毛刺就已经是显性数组时不按毛刺数组报', () {
      // r1c1、r1c2 只剩 {1,2}，r1c3 再加个 3：拿掉 r1c3 之后前两格是现成的裸对，
      // 这时候讲毛刺等于绕远路。
      final board = SudokuBoard.fromString(List.filled(81, '0').join());
      for (var d = 3; d <= 9; d++) {
        board.eliminateCandidate(0, 0, d);
        board.eliminateCandidate(0, 1, d);
      }
      for (var d = 4; d <= 9; d++) {
        board.eliminateCandidate(0, 2, d);
      }
      final hint = AdvancedTechniques.findBurredSubset(board);
      final cells =
          hint == null ? <List<int>>[] : _cells(hint, HintRole.pattern);
      expect(
        {for (final c in cells) '${c[0]},${c[1]}'},
        isNot({'0,0', '0,1', '0,2'}),
        reason: '这是裸对加一格，不是毛刺数组',
      );
    });

    test('空盘上不乱报，而且立刻收工', () {
      final board = SudokuBoard.fromString(List.filled(81, '0').join());
      final sw = Stopwatch()..start();
      expect(AdvancedTechniques.findBurredSubset(board), isNull);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('教学盘上搜索在两秒内收工', () {
      final board = SudokuBoard.fromString(_tech('burr_array').examplePuzzle);
      final sw = Stopwatch()..start();
      AdvancedTechniques.findBurredSubset(board);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('按难度排进提示顺序，有难度分，教学页不再是教学专属', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('毛刺数组'));
      expect(order.indexOf('死环'), lessThan(order.indexOf('毛刺数组')));
      // 乙支推到推不动为止，力度同强制链，所以和 Kraken 同档、排在它之后。
      // 按 9.4 排到 ALS-XZ 前面时它会把后面三种深技巧该出面的局面全抢走。
      expect(order.indexOf('Kraken Fish'), lessThan(order.indexOf('毛刺数组')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('毛刺数组', 97));
      expect(_tech('burr_array').teachingOnly, isFalse);
    });
  });
}
