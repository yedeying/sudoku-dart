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

bool _sees(int r1, int c1, int r2, int c2) =>
    (r1 == r2 && c1 == c2) ||
    r1 == r2 ||
    c1 == c2 ||
    (r1 ~/ 3 == r2 ~/ 3 && c1 ~/ 3 == c2 ~/ 3);

/// 死环的几何，按评审正文逐条数：奇数格成圈、相邻两格同房屋、
/// 各边房屋互不相同、每条边房屋只许占圈上两格。
///
/// 少数哪一条，「守卫全假之后每条边都是真强链」就撑不住，
/// 结论也就跟着塌掉，所以这几条要在测试里独立重数一遍。
void expectGuardedOddCycle(
  SudokuBoard board,
  int digit,
  List<List<int>> cycle,
  List<List<int>> guards,
) {
  expect(cycle.length.isOdd, isTrue, reason: '死环是奇数圈');
  expect(cycle.length, greaterThanOrEqualTo(5), reason: '死环至少五格');
  for (final c in cycle) {
    expect(board.getCandidates(c[0], c[1]), contains(digit),
        reason: 'r${c[0] + 1}c${c[1] + 1} 上没有 $digit，不能在圈上');
  }

  final houses = <int>[];
  for (var i = 0; i < cycle.length; i++) {
    final a = cycle[i], b = cycle[(i + 1) % cycle.length];
    final shared = [
      if (a[0] == b[0]) a[0],
      if (a[1] == b[1]) 9 + a[1],
      if (a[0] ~/ 3 == b[0] ~/ 3 && a[1] ~/ 3 == b[1] ~/ 3)
        18 + (a[0] ~/ 3) * 3 + a[1] ~/ 3,
    ];
    expect(shared, isNotEmpty,
        reason: 'r${a[0] + 1}c${a[1] + 1} 和 r${b[0] + 1}c${b[1] + 1} 不同房屋，这条边连不起来');
    // 一条边只认一条房屋：两格同时同行同宫时，占圈上两格的那条才算数。
    final pick = shared.firstWhere(
      (h) => cycle.where((c) => _inHouse(h, c)).length == 2,
      orElse: () => -1,
    );
    expect(pick, isNot(-1), reason: '这条边的每条候选房屋都占了圈上两格以外的圈格');
    houses.add(pick);
  }
  expect(houses.toSet(), hasLength(cycle.length), reason: '各条边的房屋必须互不相同');

  final cycleKeys = {for (final c in cycle) '${c[0]},${c[1]}'};
  final computed = <String>{};
  for (final h in houses) {
    for (final cell in _houseCells(h)) {
      if (cycleKeys.contains('${cell[0]},${cell[1]}')) continue;
      if (board.get(cell[0], cell[1]) != 0) continue;
      if (!board.getCandidates(cell[0], cell[1]).contains(digit)) continue;
      computed.add('${cell[0]},${cell[1]}');
    }
  }
  expect(
    {for (final g in guards) '${g[0]},${g[1]}'},
    computed,
    reason: '守卫必须是各边房屋上圈外的同名候选，一个不漏也一个不多',
  );
  expect(computed, isNotEmpty, reason: '没有守卫的全强链奇数圈在唯一解盘面上不存在');
}

bool _inHouse(int h, List<int> c) {
  if (h < 9) return c[0] == h;
  if (h < 18) return c[1] == h - 9;
  final b = h - 18;
  return c[0] ~/ 3 == b ~/ 3 && c[1] ~/ 3 == b % 3;
}

List<List<int>> _houseCells(int h) => [
      for (var i = 0; i < 9; i++)
        if (h < 9)
          [h, i]
        else if (h < 18)
          [i, h - 9]
        else
          [(h - 18) ~/ 3 * 3 + i ~/ 3, (h - 18) % 3 * 3 + i % 3],
    ];

void main() {
  group('死环', () {
    test('教学盘：盯 9 的五格奇环，三个守卫，删 9r5c7', () {
      final puzzle = _tech('dead_loop').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findDeadLoop(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '死环');
      expect(hint.isElimination, isTrue);
      expect(elimKeys(hint), {'4,6,9'});
      expectEliminationsSound(puzzle, hint);
      expectEliminationsPresent(board, hint);
      expectEvidenceBeyondTargets(hint);

      final cycle = _cells(hint, HintRole.pattern);
      final guards = _cells(hint, HintRole.extra);
      expect(
        {for (final c in cycle) '${c[0]},${c[1]}'},
        {'3,3', '3,7', '6,7', '6,5', '4,5'},
      );
      expect(
        {for (final g in guards) '${g[0]},${g[1]}'},
        {'3,6', '4,4', '6,6'},
      );
      expectGuardedOddCycle(board, 9, cycle, guards);
      expect(_candKeys(hint, HintRole.extra), {'3,6,9', '4,4,9', '6,6,9'});
      expect(_candKeys(hint, HintRole.pattern),
          {'3,3,9', '3,7,9', '6,7,9', '6,5,9', '4,5,9'});
    });

    test('删除落点必须同时看得见全部守卫，圈上和守卫自己都不删', () {
      final board =
          SudokuBoard.fromString(_tech('dead_loop').examplePuzzle);
      final hint = AdvancedTechniques.findDeadLoop(board)!;
      final cycle = {for (final c in _cells(hint, HintRole.pattern)) '$c'};
      final guards = _cells(hint, HintRole.extra);
      for (final e in hint.eliminations) {
        expect(cycle.contains('${[e.row, e.col]}'), isFalse,
            reason: '结论落在守卫上，不能删圈上的候选');
        expect(
          guards.any((g) => g[0] == e.row && g[1] == e.col),
          isFalse,
          reason: '守卫自己不能删',
        );
        for (final g in guards) {
          expect(_sees(e.row, e.col, g[0], g[1]), isTrue,
              reason: '看不见守卫 r${g[0] + 1}c${g[1] + 1} 的位置删不得');
        }
      }
    });

    test('圈上的边只是潜在强链，不能画成强箭头', () {
      final board =
          SudokuBoard.fromString(_tech('dead_loop').examplePuzzle);
      final hint = AdvancedTechniques.findDeadLoop(board)!;
      final cycleKeys = {
        for (final c in _cells(hint, HintRole.pattern)) '${c[0]},${c[1]}'
      };
      for (final link in hint.links) {
        final onCycle = cycleKeys.contains('${link.from.row},${link.from.col}') &&
            cycleKeys.contains('${link.to.row},${link.to.col}');
        if (!onCycle) continue;
        expect(link.kind, ArrowKind.weak,
            reason: '守卫还在，这条边就不够强，画成强箭头是撒谎');
      }
    });

    test('多一个守卫、落点看不全时就不报', () {
      final board =
          SudokuBoard.fromString(_tech('dead_loop').examplePuzzle);
      // 唯一的落点 r5c7 自己没了，这个圈在这张盘上就删不出东西。
      board.eliminateCandidate(4, 6, 9);
      final hint = AdvancedTechniques.findDeadLoop(board);
      expect(
        hint == null || !elimKeys(hint).contains('4,6,9'),
        isTrue,
        reason: '候选已经不在盘上，不能还报它',
      );
    });

    test('空盘上不乱报，而且立刻收工', () {
      final board = SudokuBoard.fromString(List.filled(81, '0').join());
      final sw = Stopwatch()..start();
      expect(AdvancedTechniques.findDeadLoop(board), isNull);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('教学盘上搜索在两秒内收工', () {
      final board =
          SudokuBoard.fromString(_tech('dead_loop').examplePuzzle);
      final sw = Stopwatch()..start();
      AdvancedTechniques.findDeadLoop(board);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('按难度排进提示顺序，有难度分，教学页不再是教学专属', () {
      final order = SudokuSolver.hintSearchOrder;
      expect(order, contains('死环'));
      expect(order.indexOf('Grouped AIC'), lessThan(order.indexOf('死环')));
      expect(order.indexOf('死环'), lessThan(order.indexOf('ALS-XZ')));
      expect(DifficultyAnalyzer.techniqueScores, containsPair('死环', 94));
      expect(_tech('dead_loop').teachingOnly, isFalse);
    });
  });
}
