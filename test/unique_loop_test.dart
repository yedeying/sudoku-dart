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

Set<String> _cellKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCells)
        if (c.role == role) '${c.row},${c.col}',
    };

Set<String> _candKeys(SudokuHint hint, HintRole role) => {
      for (final c in hint.patternCandidates)
        if (c.role == role) '${c.ref.row},${c.ref.col},${c.ref.num}',
    };

Set<String> _linkKeys(SudokuHint hint, ArrowKind kind) => {
      for (final l in hint.links)
        if (l.kind == kind)
          '${l.from.row},${l.from.col},${l.from.num}-'
              '${l.to.row},${l.to.col},${l.to.num}',
    };

List<List<int>> _structureCells(SudokuHint hint) => [
      for (final key in {
        ..._cellKeys(hint, HintRole.pattern),
        ..._cellKeys(hint, HintRole.extra),
      })
        [int.parse(key.split(',')[0]), int.parse(key.split(',')[1])],
    ];

/// 唯一环的几何：偶数格、不少于六格、每条房屋恰好占环上两格，
/// 而且这些格子真的串成**一个**环、沿环隔一格一色是个合法两染色。
///
/// 提示里的格子是无序的，但环的顺序不必另外声明：每格恰好两个同房屋的邻居时
/// 串法唯一，这里把它还原出来即可。还原不出一整圈，就说明这不是一个环
/// （两个各自合法的环拼在一起也能骗过「每条房屋恰好两格」这一条）。
void expectLoopGeometry(List<List<int>> cells) {
  expect(cells.length, greaterThanOrEqualTo(6), reason: '唯一环不少于六格');
  expect(cells.length.isEven, isTrue, reason: '唯一环是偶环');
  for (var house = 0; house < 27; house++) {
    final hit = cells.where((c) {
      if (house < 9) return c[0] == house;
      if (house < 18) return c[1] == house - 9;
      final b = house - 18;
      return c[0] ~/ 3 == b ~/ 3 && c[1] ~/ 3 == b % 3;
    }).length;
    expect(hit == 0 || hit == 2, isTrue,
        reason: '房屋 $house 上占了 $hit 格，唯一环要求恰好两格');
  }

  bool sees(List<int> a, List<int> b) {
    if (a[0] == b[0] && a[1] == b[1]) return false;
    return a[0] == b[0] ||
        a[1] == b[1] ||
        (a[0] ~/ 3 == b[0] ~/ 3 && a[1] ~/ 3 == b[1] ~/ 3);
  }

  final n = cells.length;
  final neighbors = <int, List<int>>{
    for (var i = 0; i < n; i++)
      i: [
        for (var j = 0; j < n; j++)
          if (i != j && sees(cells[i], cells[j])) j
      ]
  };
  for (var i = 0; i < n; i++) {
    expect(neighbors[i], hasLength(2),
        reason: 'r${cells[i][0] + 1}c${cells[i][1] + 1} 有 '
            '${neighbors[i]!.length} 个同房屋的邻居，环上每格只连着前后两格');
  }

  final order = <int>[0];
  var prev = -1;
  var cur = 0;
  while (order.length < n) {
    final next = neighbors[cur]!.firstWhere((x) => x != prev, orElse: () => -1);
    if (next == -1 || order.contains(next)) break;
    order.add(next);
    prev = cur;
    cur = next;
  }
  expect(order, hasLength(n), reason: '这些格子串不成一整个环，只走通了 ${order.length} 格');
  expect(neighbors[order.last], contains(0), reason: '环没闭合');

  final color = <int, int>{for (var i = 0; i < n; i++) order[i]: i % 2};
  for (var i = 0; i < n; i++) {
    for (final j in neighbors[i]!) {
      expect(color[i], isNot(color[j]),
          reason: 'r${cells[i][0] + 1}c${cells[i][1] + 1} 和 '
              'r${cells[j][0] + 1}c${cells[j][1] + 1} 同房屋又同色，两染色不成立');
    }
  }
}

void main() {
  group('唯一环 1', () {
    test('教学盘：六格偶环只多出 2r7c7，那一格就填 2', () {
      final puzzle = _tech('ul1').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findUniqueLoopType1(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '唯一环 1');
      expect(hint.isElimination, isFalse);
      expect([hint.row, hint.col, hint.value], [6, 6, 2]);
      expectFillSound(puzzle, hint);
      expectLoopGeometry(_structureCells(hint));
      expect(_candKeys(hint, HintRole.extra), contains('6,6,2'));
      expect(
        _candKeys(hint, HintRole.pattern),
        containsAll(['2,6,3', '2,6,7', '6,6,3', '6,6,7']),
        reason: '环上的底数候选是这一步的依据',
      );
    });

    test('抹掉那唯一的多余候选后，只剩底数的环不该报类型 1', () {
      final board = SudokuBoard.fromString(_tech('ul1').examplePuzzle);
      board.eliminateCandidate(6, 6, 2);
      expect(AdvancedTechniques.findUniqueLoopType1(board), isNull);
    });

    test('环上某格掉了一个底数，环就断了', () {
      final board = SudokuBoard.fromString(_tech('ul1').examplePuzzle);
      board.eliminateCandidate(4, 7, 3);
      expect(AdvancedTechniques.findUniqueLoopType1(board), isNull);
    });
  });

  group('唯一环 2', () {
    test('教学盘：环上两格多出 4，共同可见处删 4', () {
      final puzzle = _tech('ul2').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findUniqueLoopType2(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '唯一环 2');
      expect(elimKeys(hint), {'0,6,4', '2,8,4'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expectLoopGeometry(_structureCells(hint));
      expect(_cellKeys(hint, HintRole.extra), {'2,6', '2,7'});
      expect(_candKeys(hint, HintRole.extra), {'2,6,4', '2,7,4'});
      expect(_linkKeys(hint, ArrowKind.strong), {'2,6,4-2,7,4'});
    });

    test('两格多出的不是同一个数字时不报类型 2', () {
      final board = SudokuBoard.fromString(_tech('ul4').examplePuzzle);
      expect(AdvancedTechniques.findUniqueLoopType2(board), isNull);
    });
  });

  group('唯一环 4', () {
    test('教学盘：c7 上 5 成强链，两个多余格各删底数 8', () {
      final puzzle = _tech('ul4').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findUniqueLoopType4(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '唯一环 4');
      expect(elimKeys(hint), {'1,6,8', '2,6,8'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expectLoopGeometry(_structureCells(hint));
      expect(hint.highlightCols, [6], reason: '锁定发生在 c7 上');
      expect(hint.highlightRows, isEmpty);
      expect(
        _candKeys(hint, HintRole.link),
        {'1,6,5', '2,6,5'},
        reason: '成强链的底数要标在候选上',
      );
      expect(_candKeys(hint, HintRole.extra), {'1,6,4', '2,6,6'});
      expect(_linkKeys(hint, ArrowKind.strong), hasLength(1));
    });
  });

  group('唯一环 3', () {
    test('教学盘：{1,6} 虚拟格和 r1c4 配成数对，c4 别处删 1 和 6', () {
      final puzzle = _tech('ul3').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findUniqueLoopType3(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '唯一环 3');
      expect(elimKeys(hint), {'1,3,1', '4,3,6'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      expectLoopGeometry(_structureCells(hint));
      expect(hint.highlightCols, [3], reason: '数组配在 c4 这条房屋里');
      expect(_cellKeys(hint, HintRole.extra), {'7,3', '8,3'});
      expect(_candKeys(hint, HintRole.extra), {'7,3,1', '8,3,6'});
      expect(_cellKeys(hint, HintRole.link), {'0,3'});
    });

    test('虚拟格是完整性约束：这张盘上数组数字全在虚拟格里，两个多余格一个都动不了', () {
      final board = SudokuBoard.fromString(_tech('ul3').examplePuzzle);
      final hint = AdvancedTechniques.findUniqueLoopType3(board);
      expect(hint, isNotNull);
      final touched = {for (final e in hint!.eliminations) '${e.row},${e.col}'};
      // 数组是 {1,6} 两格锁两数，跟虚拟格的候选一模一样，虚拟格外没有别的数组数字。
      // 一般规则（虚拟格外的数组数字可以删）见 virtual_cell_type3_test。
      expect(touched, isNot(contains('7,3')));
      expect(touched, isNot(contains('8,3')));
      expect(touched, isNot(contains('0,3')));
    });

    test('只有一个多余候选时凑不出虚拟格', () {
      final board = SudokuBoard.fromString(_tech('ul1').examplePuzzle);
      expect(AdvancedTechniques.findUniqueLoopType3(board), isNull);
    });
  });

  test('四型都不在空盘上乱报，而且搜索立刻收工', () {
    final board = SudokuBoard.fromString(List.filled(81, '0').join());
    final sw = Stopwatch()..start();
    expect(AdvancedTechniques.findUniqueLoopType1(board), isNull);
    expect(AdvancedTechniques.findUniqueLoopType2(board), isNull);
    expect(AdvancedTechniques.findUniqueLoopType3(board), isNull);
    expect(AdvancedTechniques.findUniqueLoopType4(board), isNull);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(2000), reason: '空盘上环搜索必须立刻剪光');
  });

  group('搜索预算', () {
    /// 环搜索的访问预算是每个起点各一份，所以一个起点的子树再大也吃不掉
    /// 后面起点的份额，「哪些环搜得到」只由（底数对，起点）决定，
    /// 跟先搜过谁无关。这一组测试钉住这条：同一盘反复搜、换着顺序搜，
    /// 结果都必须一模一样。
    String sig(SudokuHint? hint) => hint == null
        ? 'null'
        : '${hint.technique}|${hint.row},${hint.col},${hint.value}|'
            '${(elimKeys(hint).toList()..sort()).join(';')}';

    final finders = <String, SudokuHint? Function(SudokuBoard)>{
      '唯一环 1': AdvancedTechniques.findUniqueLoopType1,
      '唯一环 2': AdvancedTechniques.findUniqueLoopType2,
      '唯一环 3': AdvancedTechniques.findUniqueLoopType3,
      '唯一环 4': AdvancedTechniques.findUniqueLoopType4,
    };

    test('同一盘上反复搜，结果一字不差', () {
      for (final id in ['ul1', 'ul2', 'ul3', 'ul4']) {
        final puzzle = _tech(id).examplePuzzle;
        finders.forEach((name, find) {
          final first = sig(find(SudokuBoard.fromString(puzzle)));
          final again = sig(find(SudokuBoard.fromString(puzzle)));
          expect(again, first, reason: '$id 上 $name 两次搜出来的不一样');
        });
      }
    });

    test('先搜别的类型不影响后搜的结果：预算不是四型共用的', () {
      for (final id in ['ul1', 'ul2', 'ul3', 'ul4']) {
        final puzzle = _tech(id).examplePuzzle;
        final alone = <String, String>{
          for (final entry in finders.entries)
            entry.key: sig(entry.value(SudokuBoard.fromString(puzzle)))
        };
        // 同一块盘上把四型正着搜一遍、再倒着搜一遍。
        final board = SudokuBoard.fromString(puzzle);
        final order = finders.entries.toList();
        for (final entry in [...order, ...order.reversed]) {
          expect(
            sig(entry.value(board)),
            alone[entry.key],
            reason: '$id 上 ${entry.key} 的结果被前面搜过的类型带偏了',
          );
        }
      }
    });
  });

  test('四型按难度排进提示顺序，各有难度分', () {
    final order = SudokuSolver.hintSearchOrder;
    for (final name in ['唯一环 1', '唯一环 2', '唯一环 3', '唯一环 4']) {
      expect(order, contains(name), reason: '$name 应进提示顺序');
    }
    expect(order.indexOf('扩展矩形 3'), lessThan(order.indexOf('唯一环 1')));
    expect(order.indexOf('唯一环 1'), lessThan(order.indexOf('唯一环 2')));
    expect(order.indexOf('唯一环 2'), lessThan(order.indexOf('唯一环 4')));
    // 唯一环 3（7.2）比 Simple Coloring（7.0）还深，排在它后面才跟难度分同向。
    expect(
      order.indexOf('Simple Coloring'),
      lessThan(order.indexOf('唯一环 3')),
    );

    expect(DifficultyAnalyzer.techniqueScores, containsPair('唯一环 1', 66));
    expect(DifficultyAnalyzer.techniqueScores, containsPair('唯一环 2', 68));
    expect(DifficultyAnalyzer.techniqueScores, containsPair('唯一环 4', 70));
    expect(DifficultyAnalyzer.techniqueScores, containsPair('唯一环 3', 72));
    for (final id in ['ul1', 'ul2', 'ul3', 'ul4']) {
      expect(_tech(id).teachingOnly, isFalse, reason: '$id 已有独立报法');
    }
  });
}
