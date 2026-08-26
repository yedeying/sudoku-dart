import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/teaching_colors.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/difficulty_analyzer.dart';
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

/// docs/superpowers/inbox/2026-08-25-technique-review.md「总表」里的全部技巧，
/// 按总表出现顺序抄下来。教学目录必须和这张表一一对应：
/// 多一条说明表里没收录，少一条说明教学缺口。
const _reviewTableNames = <String>[
  '唯余法',
  '摒除法',
  '显性数对',
  '显性三数组',
  '隐性数对',
  '宫区块',
  '行/列区块',
  '隐性三数组',
  '显性四数组',
  'X-Wing',
  '隐性四数组',
  '摩天楼',
  '双线风筝',
  'Swordfish',
  '多宝鱼',
  '带鳍 X-Wing',
  '刺身鱼',
  '空矩形',
  'Jellyfish',
  'XY-Wing',
  '唯一矩形 1',
  '双生鱼',
  '不完整唯一矩形',
  '唯一矩形 2',
  'BUG+1',
  '可规避矩形',
  '带鳍 Swordfish',
  '自噬',
  '唯一矩形 4',
  '隐性唯一矩形',
  'XYZ-Wing',
  '扩展矩形 1',
  'BUG 类型 2',
  '扩展矩形 2',
  '带鳍 Jellyfish',
  '唯一矩形 3',
  'BUG 类型 4',
  '扩展矩形 4',
  '扩展矩形 3',
  '唯一环 1',
  'BUG 类型 3',
  '唯一环 2',
  'BUG+n',
  '唯一环 4',
  '唯一环 3',
  'Franken 鱼',
  'Simple Coloring',
  '探长',
  'Mutant 鱼',
  '淑芬',
  'W-Wing',
  'XY-Chain',
  'WXYZ-Wing',
  'AIC 开链',
  'Sue de Coq',
  'Nice Loop',
  'Grouped AIC',
  '死环',
  '毛刺数组',
  '待定唯一矩形',
  'ALS-XZ',
  'DDS',
  '待定扩展矩形',
  '待定唯一环',
  '待定 BUG',
  'Death Blossom',
  'WALS',
  'MSLS',
  'Kraken Fish',
  '动态 AIC',
  '飞鱼导弹',
  'ALS-XY-Wing',
  'Forcing Chain',
  '强制唯一矩形',
  '强制扩展矩形',
  '强制唯一环',
  'Nishio',
  'Forcing Net',
];

/// 只做教学、还没有独立报法的条目，取自production的
/// [TechniqueInfo.teachingOnly]。
///
/// 这里不再另抄一份名单：抄一份就要人手同步两处，漏一条谁也不会发现。
/// 分类的对不对由下面「教学标记和引擎的报法对得上」那条测试盯着——
/// 它拿 [SudokuSolver.hintSearchOrder] 反查，标错一条就红。
Set<String> get _teachingOnlyNames => {
      for (final t in TechniqueCatalog.all)
        if (t.teachingOnly) t.name
    };

void main() {
  test('技巧目录和评审总表一一对应', () {
    final names = TechniqueCatalog.all.map((t) => t.name).toList();
    expect(
      names.toSet().length,
      names.length,
      reason: '目录里有重名条目：'
          '${names.where((n) => names.where((m) => m == n).length > 1).toSet()}',
    );

    final expected = _reviewTableNames.toSet();
    expect(expected.length, _reviewTableNames.length, reason: '总表抄录里有重名');
    expect(
      names.toSet().difference(expected),
      isEmpty,
      reason: '目录里有总表没收录的技巧',
    );
    expect(
      expected.difference(names.toSet()),
      isEmpty,
      reason: '总表里的技巧还缺教学条目',
    );
    expect(names.length, _reviewTableNames.length);
  });

  test('总表里的每个名字都能唯一查到教学条目', () {
    for (final name in _reviewTableNames) {
      final info = TechniqueCatalog.byName(name);
      expect(info, isNotNull, reason: '$name 查不到教学条目');
      expect(info!.name, name);
    }
  });

  test('教学条目不进提示搜索顺序，也不进难度分表', () {
    for (final name in _teachingOnlyNames) {
      expect(
        _reviewTableNames,
        contains(name),
        reason: '$name 不在总表里，教学专属名单写错了',
      );
      expect(
        SudokuSolver.hintSearchOrder,
        isNot(contains(name)),
        reason: '$name 还没有独立报法，不该出现在 getHint 搜索顺序里',
      );
      expect(
        DifficultyAnalyzer.techniqueScores.keys,
        isNot(contains(name)),
        reason: '$name 还没有独立报法，不该有难度分',
      );
    }
  });

  test('教学标记和引擎的报法对得上', () {
    // [TechniqueInfo.teachingOnly] 是「本条有没有 finder 兜底」的唯一出处，
    // 所以它必须和引擎实际报得出的名字严格互补：提示顺序里出现过的一律不算
    // 教学专属，没出现过的一律算。这样标错一条就红，将来给某条补上 finder、
    // 或者新加一条没有 finder 的教学页，都会被这条测试逼着改标记。
    final reported = <String>{
      for (final finderName in SudokuSolver.hintSearchOrder)
        TechniqueCatalog.byName(finderName)!.name
    };
    for (final t in TechniqueCatalog.all) {
      expect(
        t.teachingOnly,
        !reported.contains(t.name),
        reason: t.teachingOnly
            ? '${t.name} 标成了教学专属，但引擎报得出它'
            : '${t.name} 没标教学专属，引擎却报不出它——'
                '要么补上 finder，要么把 teachingOnly 打开并写出结构声明',
      );
    }
  });

  test('每条教学专属条目都在总表里', () {
    for (final name in _teachingOnlyNames) {
      expect(
        _reviewTableNames,
        contains(name),
        reason: '$name 不在总表里，教学专属标记打在了总表之外的条目上',
      );
    }
  });

  test('已实现技巧仍能从 finder 名字查回教学条目', () {
    for (final finderName in SudokuSolver.hintSearchOrder) {
      final info = TechniqueCatalog.byName(finderName);
      expect(info, isNotNull, reason: '$finderName 查不到教学条目');
      expect(
        _teachingOnlyNames,
        isNot(contains(info!.name)),
        reason: '${info.name} 被标成教学专属，却出现在提示搜索顺序里',
      );
    }
  });

  test('教学条目不用红色删除标记，避免宣称站不住脚的删除', () {
    for (final t in TechniqueCatalog.all) {
      if (!_teachingOnlyNames.contains(t.name)) continue;
      final claims = t.exampleMarkup.candidateColors.values.where(
        (c) => c == TeachingColors.elimCand || c == TeachingColors.start,
      );
      expect(
        claims,
        isEmpty,
        reason: '${t.id} 还没有独立判定，示意图不该标红删除或断言填数',
      );
    }
  });

  test('示意图标出的候选真实存在，同数字连线两端同属一个房屋', () {
    bool sameHouse(int r1, int c1, int r2, int c2) =>
        r1 == r2 || c1 == c2 || (r1 ~/ 3 == r2 ~/ 3 && c1 ~/ 3 == c2 ~/ 3);

    // 这三条画的是「假设 A 推出 B」的蕴含关系，中间可能隔着好几步唯一余数，
    // 两端不必同属一个房屋。其余条目的箭头都是链接，同数字两端必须共处一房。
    // 名单只放真的画了跨房屋同数字箭头的条目，别拿它当免检通道。
    const implicationStyle = {
      'forcing_chain',
      'forcing_net',
      'kraken',
    };

    for (final t in TechniqueCatalog.all) {
      final board = SudokuBoard.fromString(t.examplePuzzle);
      void checkRef(CandidateRef ref, String what) {
        expect(
          board.get(ref.row, ref.col),
          0,
          reason: '${t.id}: $what r${ref.row + 1}c${ref.col + 1} 已经是给定数，'
              '不该在上面标候选',
        );
        expect(
          board.getCandidates(ref.row, ref.col),
          contains(ref.num),
          reason: '${t.id}: $what r${ref.row + 1}c${ref.col + 1} 上没有 '
              '${ref.num} 这个候选，示意图和盘面对不上',
        );
      }

      t.exampleMarkup.candidateColors.forEach((ref, _) {
        checkRef(ref, '候选标记');
      });
      for (final arrow in t.exampleMarkup.arrows) {
        checkRef(arrow.from, '连线起点');
        checkRef(arrow.to, '连线终点');
        if (arrow.from.num == arrow.to.num &&
            !implicationStyle.contains(t.id)) {
          expect(
            sameHouse(
                arrow.from.row, arrow.from.col, arrow.to.row, arrow.to.col),
            isTrue,
            reason: '${t.id}: r${arrow.from.row + 1}c${arrow.from.col + 1} 与 '
                'r${arrow.to.row + 1}c${arrow.to.col + 1} 上的 ${arrow.from.num} '
                '不同行不同列不同宫，连不成链',
          );
        }
      }
    }
  });

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

  test('已实现技巧使用评审中的规范名称和难度分', () {
    final names = TechniqueCatalog.all.map((t) => t.name).toSet();
    expect(
      names,
      containsAll([
        'Franken 鱼',
        '唯一矩形 1',
        '唯一矩形 2',
        '唯一矩形 3',
        '唯一矩形 4',
      ]),
    );
    expect(names.any((name) => name.contains('唯一矩形 Type')), isFalse);
    expect(names, isNot(contains('Franken/Mutant Fish')));

    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('摩天楼', 32),
    );
    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('双线风筝', 36),
    );
    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('空矩形', 48),
    );
    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('唯一矩形 1', 50),
    );
    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('唯一矩形 2', 54),
    );
    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('唯一矩形 3', 62),
    );
    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('唯一矩形 4', 56),
    );
    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('BUG+1', 54),
    );
    expect(
      DifficultyAnalyzer.techniqueScores,
      containsPair('Franken 鱼', 68),
    );
    expect(
      DifficultyAnalyzer.techniqueScores.keys
          .any((name) => name.contains('唯一矩形 Type')),
      isFalse,
    );
    expect(
      DifficultyAnalyzer.techniqueScores,
      isNot(contains('Franken/Mutant Fish')),
    );
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
      expect(t.copyPuzzle.length, 81, reason: t.id);
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

  test(
    '练习原题连点提示能走到对应技巧',
    () {
      void apply(SudokuBoard board, SudokuHint hint) {
        if (hint.isElimination) {
          for (final e in hint.eliminations) {
            board.eliminateCandidate(e.row, e.col, e.num);
          }
        } else {
          board.set(hint.row, hint.col, hint.value);
        }
      }

      // 凡是配了练习原题的条目一律逐条核。`copyPuzzle` 的文档就是拿
      // 「有 practicePuzzles 条目 → 连点提示走得到」这句话当承诺的，
      // 只抽查几条的话，剩下的条目等于在替一句没人核过的话背书。
      // bug1 额外带一条：它的教学图本身就走得到，没有单独的练习原题，
      // 走 copyPuzzle 正好把两种情况都盖上。
      //
      // 下面这几条是已知不达标的：练习原题上有更浅的技巧先出面，
      // 顺手把目标结构拆掉了（比如 empty_rect 上刺身鱼 4.6 比空矩形 4.8 浅，
      // 先报了就没空矩形可认）。要修得换练习原题，本轮不凭空造盘，
      // 所以明确记在这里，而不是让它们躲在「只抽查六条」后面没人知道。
      // 这几条都是鱼和 ALS，轨迹里没有唯一结构那一族，跟这一轮的改动无关。
      //
      // ur3 曾经也在这张名单上。它已经换了练习原题（见 practicePuzzles 的注释），
      // 走得到了，所以从名单里摘掉——豁免不是修法。
      const knownUnreachable = {
        'empty_rect',
        'finned_xwing',
        'finned_swordfish',
        'finned_jellyfish',
        'als_xy',
        // 强制致命结构 9.8 比 Nishio 9.9 浅，练习原题上先报了就把 Nishio 拆掉。
        'nishio',
      };
      final checked = {...TechniqueCatalog.practicePuzzles.keys, 'bug1'}
        ..removeAll(knownUnreachable);
      expect(checked.length, greaterThan(6), reason: '抽查名单退化了');
      final misses = <String>[];
      for (final t in TechniqueCatalog.all) {
        if (!checked.contains(t.id)) continue;
        final board = SudokuBoard.fromString(t.copyPuzzle);
        var hit = false;
        for (var i = 0; i < 200; i++) {
          final hint = SudokuSolver.getHint(board);
          if (hint == null) break;
          // finder 报的名字可能是历史长名（如「Nice Loop / AIC 环」），
          // 走一遍别名再比，等价于比同一条教学条目。
          if (TechniqueCatalog.byName(hint.technique)?.id == t.id) {
            hit = true;
            break;
          }
          apply(board, hint);
        }
        if (!hit) misses.add('${t.id}（${t.name}）');
      }
      expect(misses, isEmpty, reason: '这些练习原题连点提示走不到本技巧：$misses');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
