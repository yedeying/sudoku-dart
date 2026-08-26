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

/// 结构格必须严格是「两条同向线各三格、恰好跨两个宫」。
void _expectSixCellGeometry(SudokuHint hint) {
  final cells = {
    ..._cellKeys(hint, HintRole.pattern),
    ..._cellKeys(hint, HintRole.extra),
  }.map((k) {
    final p = k.split(',');
    return [int.parse(p[0]), int.parse(p[1])];
  }).toList();
  expect(cells, hasLength(6), reason: '扩展矩形是六格');
  final rows = cells.map((c) => c[0]).toSet();
  final cols = cells.map((c) => c[1]).toSet();
  final byRow = rows.length == 2 && cols.length == 3;
  final byCol = cols.length == 2 && rows.length == 3;
  expect(byRow || byCol, isTrue,
      reason: '六格应是 2×3 或 3×2，实际 ${rows.length} 行 ${cols.length} 列');
  final boxes = cells.map((c) => (c[0] ~/ 3) * 3 + c[1] ~/ 3).toSet();
  expect(boxes, hasLength(2), reason: '扩展矩形必须恰好跨两个宫');

  // 三格一线必须整整落在一个宫里。「恰好两个宫」拦不住三格跨宫的摆法
  // （r1c1,r1c2,r1c4 / r2c1,r2c2,r2c4 也只占两个宫），
  // 可那种摆法整块对调之后宫里的底数个数就变了，根本不是致命形。
  final lines = <int, List<List<int>>>{};
  for (final c in cells) {
    lines.putIfAbsent(byRow ? c[0] : c[1], () => []).add(c);
  }
  expect(lines, hasLength(2));
  final lineBoxes = <int>[];
  for (final entry in lines.entries) {
    expect(entry.value, hasLength(3), reason: '每条线三格');
    final own = entry.value.map((c) => (c[0] ~/ 3) * 3 + c[1] ~/ 3).toSet();
    expect(own, hasLength(1),
        reason: '${byRow ? "r" : "c"}${entry.key + 1} 上那三格跨了 $own，'
            '三格一线必须整整落在一个宫里');
    lineBoxes.add(own.single);
  }
  expect(lineBoxes.toSet(), hasLength(2), reason: '两条线必须落在不同的宫');
}

void main() {
  group('扩展矩形 1', () {
    test('教学盘：六格只多出 5r3c8，那一格就填 5', () {
      final puzzle = _tech('er1').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findExtendedRectType1(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '扩展矩形 1');
      expect(hint.isElimination, isFalse);
      expect([hint.row, hint.col, hint.value], [2, 7, 5]);
      expectFillSound(puzzle, hint);
      _expectSixCellGeometry(hint);
      expect(
        _candKeys(hint, HintRole.extra),
        contains('2,7,5'),
        reason: '多出来的候选就是结论，必须标出来',
      );
      expect(
        _candKeys(hint, HintRole.pattern),
        containsAll(['0,5,2', '0,5,4', '0,5,6', '2,7,2']),
        reason: '六格上的底数候选是这一步的依据',
      );
    });

    test('抹掉一个底数候选后六格不再都含底数，类型 1 就不成立', () {
      final board = SudokuBoard.fromString(_tech('er1').examplePuzzle);
      board.eliminateCandidate(1, 5, 4);
      expect(AdvancedTechniques.findExtendedRectType1(board), isNull);
    });

    test('抹掉那唯一的多余候选后，只剩底数的六格不该报类型 1', () {
      final board = SudokuBoard.fromString(_tech('er1').examplePuzzle);
      board.eliminateCandidate(2, 7, 5);
      expect(AdvancedTechniques.findExtendedRectType1(board), isNull);
    });
  });

  group('扩展矩形 2', () {
    test('教学盘：同侧两格多出 7，共同可见处删 7', () {
      final puzzle = _tech('er2').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findExtendedRectType2(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '扩展矩形 2');
      expect(elimKeys(hint), {'2,4,7', '5,4,7', '8,3,7'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      _expectSixCellGeometry(hint);
      expect(_cellKeys(hint, HintRole.extra), {'6,4', '8,4'});
      expect(_candKeys(hint, HintRole.extra), {'6,4,7', '8,4,7'});
      expect(_linkKeys(hint, ArrowKind.strong), {'6,4,7-8,4,7'},
          reason: '两个多余候选至少一真，画成强链');
    });

    test('两格多出的不是同一个数字时不报类型 2', () {
      final board = SudokuBoard.fromString(_tech('er4').examplePuzzle);
      expect(AdvancedTechniques.findExtendedRectType2(board), isNull);
    });

    test('结构格只剩底数的一部分也照样成立：r8 那一对各少一个 3', () {
      // 残局里候选是一路删下来的，结构格常常只剩底数里的两个。
      // 只要「整块对调」还走得通，这仍是一个致命形——
      // 从前按「六格都含全部底数」筛，这一类读法整批漏掉了。
      final puzzle = _tech('er2').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      board.eliminateCandidate(7, 2, 3);
      board.eliminateCandidate(7, 4, 3);
      expect(board.getCandidates(7, 2), {6, 8});
      expect(board.getCandidates(7, 4), {6, 8});

      final hint = AdvancedTechniques.findExtendedRectType2(board);

      expect(hint, isNotNull, reason: 'r8 这一对同时少了 3，对调依旧走得通');
      expect(hint!.technique, '扩展矩形 2');
      expect(elimKeys(hint), {'2,4,7', '5,4,7', '8,3,7'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      _expectSixCellGeometry(hint);
    });

    test('只有一格少了底数、对面那格还留着，对调就走不通，不许报', () {
      // r8c3 少了 3、r8c5 还留着 3：存在一种合法填法，
      // 对调之后要往 r8c3 放 3，而那里已经放不下 3 了。
      // 这时候「另一个解」并不存在，报出来就是误删。
      final board = SudokuBoard.fromString(_tech('er2').examplePuzzle);
      board.eliminateCandidate(7, 2, 3);
      final hint = AdvancedTechniques.findExtendedRectType2(board);
      if (hint != null) {
        expect(
          elimKeys(hint),
          isNot({'2,4,7', '5,4,7', '8,3,7'}),
          reason: '这副几何已经不是致命形了，不能再拿它删 7',
        );
      }
    });
  });

  group('扩展矩形 4', () {
    test('教学盘：r3 上 4 成强链，两个多余格各删两个底数', () {
      final puzzle = _tech('er4').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findExtendedRectType4(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '扩展矩形 4');
      expect(elimKeys(hint), {'2,1,6', '2,1,9', '2,7,6', '2,7,9'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      _expectSixCellGeometry(hint);
      expect(hint.highlightRows, [2], reason: '锁定发生在 r3 这条垂直房屋上');
      expect(_linkKeys(hint, ArrowKind.strong), {'2,1,4-2,7,4'});
      expect(_candKeys(hint, HintRole.link), {'2,1,4', '2,7,4'},
          reason: '成强链的底数要标在候选上');
      expect(_candKeys(hint, HintRole.extra), {'2,1,3', '2,7,1'});
    });

    test('结构格缺了锁定的那个底数也照样成立：r1 那一对各少一个 4', () {
      // 锁定房屋是 r3，缺 4 的是 r1 上那一对结构格，两件事互不相干。
      // 这一类读法从前也整批漏掉了。
      final puzzle = _tech('er4').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      board.eliminateCandidate(0, 1, 4);
      board.eliminateCandidate(0, 7, 4);
      expect(board.getCandidates(0, 1), {6, 9});
      expect(board.getCandidates(0, 7), {6, 9});

      final hint = AdvancedTechniques.findExtendedRectType4(board);

      expect(hint, isNotNull, reason: 'r1 这一对同时少了 4，对调依旧走得通');
      expect(hint!.technique, '扩展矩形 4');
      expect(elimKeys(hint), {'2,1,6', '2,1,9', '2,7,6', '2,7,9'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expect(hint.highlightRows, [2]);
      _expectSixCellGeometry(hint);
    });

    test('结构自己那两条三格线锁不出强链，不该拿来当类型 4 的房屋', () {
      final hint = AdvancedTechniques.findExtendedRectType4(
        SudokuBoard.fromString(_tech('er4').examplePuzzle),
      );
      expect(hint, isNotNull);
      // 教学盘的六格在 c2、c8 上各三格，锁定房屋只能是横着的 r1/r2/r3。
      expect(hint!.highlightCols, isEmpty);
      expect(hint.highlightRows, hasLength(1));
    });
  });

  group('扩展矩形 3', () {
    test('教学盘：{1,5} 虚拟格和 r4c1 配成数对，r4 别处删 1', () {
      final puzzle = _tech('er3').examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);

      final hint = AdvancedTechniques.findExtendedRectType3(board);

      expect(hint, isNotNull);
      expect(hint!.technique, '扩展矩形 3');
      expect(elimKeys(hint), {'3,6,1', '3,7,1'});
      expectEliminationsPresent(board, hint);
      expectEliminationsSound(puzzle, hint);
      expectEvidenceBeyondTargets(hint);
      _expectSixCellGeometry(hint);
      expect(hint.highlightRows, [3], reason: '数组配在 r4 这条房屋里');
      expect(_cellKeys(hint, HintRole.extra), {'3,4', '3,5'});
      expect(_candKeys(hint, HintRole.extra), {'3,4,1', '3,5,5'},
          reason: '虚拟格的候选就是这两个多余数字');
      expect(_cellKeys(hint, HintRole.link), {'3,0'},
          reason: '配数组的格子要单独标出来');
    });

    test('虚拟格是完整性约束：这张盘上数组数字全在虚拟格里，两个多余格一个都动不了', () {
      final board = SudokuBoard.fromString(_tech('er3').examplePuzzle);
      final hint = AdvancedTechniques.findExtendedRectType3(board);
      expect(hint, isNotNull);
      final touched = {for (final e in hint!.eliminations) '${e.row},${e.col}'};
      // 这里的数组是 {1,5} 两格锁两数，正好就是虚拟格自己的候选，
      // 虚拟格之外没有别的数组数字，所以两个多余格身上一个候选都删不动。
      // 「多余格永远不能删」并不成立，一般规则见 virtual_cell_type3_test。
      expect(touched, isNot(contains('3,4')));
      expect(touched, isNot(contains('3,5')));
      expect(touched, isNot(contains('3,0')));
      // 把额外候选当成裸对硬删，就会顺手把六格上的底数删掉；这一步一个都不许碰。
      for (final e in hint.eliminations) {
        expect(
          const {'1,3', '1,4', '1,5', '3,3'},
          isNot(contains('${e.row},${e.col}')),
          reason: '结构格上的底数不是类型 3 的删除对象',
        );
      }
    });

    test('两个多余格不同房屋时合不成虚拟格', () {
      // 类型 1 的教学盘只有一个多余候选，凑不出虚拟格。
      final board = SudokuBoard.fromString(_tech('er1').examplePuzzle);
      expect(AdvancedTechniques.findExtendedRectType3(board), isNull);
    });
  });

  test('四型都不在普通空盘上乱报', () {
    final board = SudokuBoard.fromString(List.filled(81, '0').join());
    expect(AdvancedTechniques.findExtendedRectType1(board), isNull);
    expect(AdvancedTechniques.findExtendedRectType2(board), isNull);
    expect(AdvancedTechniques.findExtendedRectType3(board), isNull);
    expect(AdvancedTechniques.findExtendedRectType4(board), isNull);
  });

  test('四型按难度排进提示顺序，各有难度分', () {
    final order = SudokuSolver.hintSearchOrder;
    for (final name in ['扩展矩形 1', '扩展矩形 2', '扩展矩形 3', '扩展矩形 4']) {
      expect(order, contains(name), reason: '$name 应进提示顺序');
    }
    expect(order.indexOf('唯一矩形 2'), lessThan(order.indexOf('扩展矩形 1')));
    expect(order.indexOf('扩展矩形 1'), lessThan(order.indexOf('扩展矩形 2')));
    expect(order.indexOf('扩展矩形 2'), lessThan(order.indexOf('扩展矩形 4')));
    expect(order.indexOf('扩展矩形 4'), lessThan(order.indexOf('扩展矩形 3')));
    expect(order.indexOf('唯一矩形 3'), lessThan(order.indexOf('扩展矩形 4')));
    expect(order.indexOf('扩展矩形 3'), lessThan(order.indexOf('Franken 鱼')));

    expect(DifficultyAnalyzer.techniqueScores, containsPair('扩展矩形 1', 60));
    expect(DifficultyAnalyzer.techniqueScores, containsPair('扩展矩形 2', 62));
    expect(DifficultyAnalyzer.techniqueScores, containsPair('扩展矩形 4', 63));
    expect(DifficultyAnalyzer.techniqueScores, containsPair('扩展矩形 3', 65));
    for (final id in ['er1', 'er2', 'er3', 'er4']) {
      expect(_tech(id).teachingOnly, isFalse, reason: '$id 已有独立报法');
    }
  });
}
