import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/teaching_colors.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

/// 在 [row],[col] 强行填入 [digit]（不经过 initial 校验），看能否推出一个完整解。
/// 用于独立于 finder 之外，验证某个候选真的可以/不可以完成一个合法数独，
/// 这样即使 [SudokuSolver.getHint] 在这一手牌面上不报告该技巧，也能确认
/// 教学标记宣称的删除/结论在数学上站得住脚。
bool _completionExists(SudokuBoard base, int row, int col, int digit) {
  final probe = SudokuBoard(
    board: base.board.map((r) => List<int>.from(r)).toList(),
    initial: base.initial.map((r) => List<int>.from(r)).toList(),
  );
  probe.board[row][col] = digit;
  return SudokuSolver.countSolutions(probe, limit: 1) >= 1;
}

void main() {
  test('技巧目录 rank 严格递增', () {
    final all = TechniqueCatalog.all;
    expect(all, isNotEmpty);
    for (int i = 1; i < all.length; i++) {
      expect(all[i].rank, greaterThan(all[i - 1].rank),
          reason: '${all[i].id} rank 应大于 ${all[i - 1].id}');
    }
  });

  test('保留 Simple Coloring，不含独立 3D Medusa', () {
    final names = TechniqueCatalog.all.map((t) => t.name).toList();
    expect(names, contains('Simple Coloring'));
    expect(
        names.any((n) => n.contains('Medusa') || n.contains('Multi-Coloring')),
        isFalse);
  });

  test('含 AIC 与 Forcing Net', () {
    final ids = TechniqueCatalog.all.map((t) => t.id).toSet();
    expect(ids, containsAll(['aic', 'nice_loop', 'forcing_net', 'naked_quad']));
  });

  test('每条技巧都有独立盘面和完整说明', () {
    const placeholder =
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
    final puzzles = <String>{};
    for (final t in TechniqueCatalog.all) {
      expect(t.examplePuzzle.length, 81, reason: t.id);
      expect(t.examplePuzzle, isNot(placeholder), reason: '${t.id} 仍是占位盘');
      expect(puzzles.add(t.examplePuzzle), isTrue, reason: '${t.id} 盘面重复');
      expect(t.definition.length, greaterThanOrEqualTo(80), reason: t.id);
      expect(t.howToSpot.length, greaterThanOrEqualTo(40), reason: t.id);
      expect(t.walkthrough.length, greaterThanOrEqualTo(80), reason: t.id);
      expect(t.walkthrough, isNot(contains(RegExp(r'第\s*\d+\s*行第'))),
          reason: '${t.id} walkthrough 仍用第x行第x列');
      expect(t.caveats.length, greaterThanOrEqualTo(20), reason: t.id);
      expect(t.legend, isNotEmpty, reason: t.id);
      final marked = t.exampleMarkup.cellColors.isNotEmpty ||
          t.exampleMarkup.candidateColors.isNotEmpty ||
          t.exampleMarkup.arrows.isNotEmpty ||
          t.exampleMarkup.struck.isNotEmpty;
      expect(marked, isTrue, reason: '${t.id} 没有标记');
    }
  });

  test('链类技巧 walkthrough 含链表达式', () {
    const ids = [
      'xy_chain',
      'aic',
      'nice_loop',
      'grouped_aic',
      'skyscraper',
      'kite',
      'xy_wing',
    ];
    final map = {for (final t in TechniqueCatalog.all) t.id: t};
    for (final id in ids) {
      final text = map[id]!.walkthrough;
      expect(text.contains(' = ') || text.contains('{'), isTrue, reason: id);
      expect(RegExp(r'\d+r\d+c\d+').hasMatch(text), isTrue, reason: id);
    }
  });

  test('基础技巧盘面互不相同且带标记', () {
    const ids = [
      'naked_single',
      'hidden_single',
      'naked_pair',
      'naked_triple',
      'naked_quad',
      'hidden_pair',
      'hidden_triple',
      'hidden_quad',
      'pointing',
      'box_line',
    ];
    final map = {for (final t in TechniqueCatalog.all) t.id: t};
    for (final id in ids) {
      final t = map[id]!;
      expect(
          t.exampleMarkup.cellColors.length +
              t.exampleMarkup.candidateColors.length,
          greaterThan(1),
          reason: id);
    }
  });

  test('鱼类与带鳍/Franken 鱼盘面都有实质标记', () {
    const ids = [
      'xwing',
      'swordfish',
      'jellyfish',
      'finned_xwing',
      'finned_swordfish',
      'finned_jellyfish',
      'franken_fish',
    ];
    final map = {for (final t in TechniqueCatalog.all) t.id: t};
    for (final id in ids) {
      final t = map[id]!;
      final marked = t.exampleMarkup.arrows.isNotEmpty ||
          t.exampleMarkup.cellColors.length >= 4;
      expect(marked, isTrue, reason: '$id 缺少足够的标记');
    }
  });

  test('链式翼技巧盘面都带箭头', () {
    const chainLikeIds = [
      'skyscraper',
      'kite',
      'empty_rect',
      'xy_wing',
      'xyz_wing',
      'w_wing',
      'simple_coloring',
    ];
    final map = {for (final t in TechniqueCatalog.all) t.id: t};
    for (final id in chainLikeIds) {
      final t = map[id]!;
      expect(t.exampleMarkup.arrows, isNotEmpty, reason: '$id 缺少链路箭头');
    }
  });

  test('唯一矩形与 BUG+1 盘面标出四个模式格', () {
    const rectLikeIds = ['ur1', 'ur2', 'ur3', 'ur4', 'bug1'];
    final map = {for (final t in TechniqueCatalog.all) t.id: t};
    for (final id in rectLikeIds) {
      final t = map[id]!;
      expect(t.exampleMarkup.cellColors.length, greaterThanOrEqualTo(4),
          reason: '$id 应标出矩形/BUG 四个格子');
    }
  });

  test(
    '求解器抽查：elimCand 候选不可能出现在任何完整解里，'
    '填数结论是该格唯一能完成解的数字',
    () {
      // GameState.getHint / 各 finder 不一定在教学盘面这一手就报出对应技巧，
      // 所以不能用「finder 是否命中」来验证例子，而要直接用回溯求解器
      // 检验标记宣称的数学结论：删除的候选永远凑不出完整解；
      // 填数结论是该格所有候选里唯一能凑出完整解的那个。
      for (final t in TechniqueCatalog.all) {
        final board = SudokuBoard.fromString(t.examplePuzzle);
        t.exampleMarkup.candidateColors.forEach((ref, color) {
          if (color == TeachingColors.elimCand) {
            expect(
              board.get(ref.row, ref.col),
              0,
              reason: '${t.id}: 删除目标 (${ref.row + 1},${ref.col + 1}) '
                  '应该是空格，不该是已填的给定数',
            );
            expect(
              _completionExists(board, ref.row, ref.col, ref.num),
              isFalse,
              reason: '${t.id}: (${ref.row + 1},${ref.col + 1})=${ref.num} '
                  '仍能凑出一个完整解，说明这个候选其实没被真正排除',
            );
          } else if (color == TeachingColors.start) {
            expect(
              board.get(ref.row, ref.col),
              0,
              reason: '${t.id}: 结论格 (${ref.row + 1},${ref.col + 1}) '
                  '应该是空格，不该是已填的给定数',
            );
            expect(
              _completionExists(board, ref.row, ref.col, ref.num),
              isTrue,
              reason: '${t.id}: 结论数字 ${ref.num} 在 '
                  '(${ref.row + 1},${ref.col + 1}) 应该能凑出至少一个完整解',
            );
            for (final other in board.getCandidates(ref.row, ref.col)) {
              if (other == ref.num) continue;
              expect(
                _completionExists(board, ref.row, ref.col, other),
                isFalse,
                reason: '${t.id}: (${ref.row + 1},${ref.col + 1}) 候选 '
                    '$other 也能凑出完整解，说明 ${ref.num} 并非唯一结论',
              );
            }
          }
        });
      }
    },
  );
}
