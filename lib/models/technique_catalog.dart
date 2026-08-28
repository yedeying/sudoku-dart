import 'package:flutter/material.dart';
import 'board_markup.dart';
import 'technique_examples_advanced_chains.dart';
import 'technique_examples_advanced_sets.dart';
import 'technique_examples_basic.dart';
import 'technique_examples_bug.dart';
import 'technique_examples_chains.dart';
import 'technique_examples_extended_rect.dart';
import 'technique_examples_fish.dart';
import 'technique_examples_fish_variants.dart';
import 'technique_examples_forcing_patterns.dart';
import 'technique_examples_pending.dart';
import 'technique_examples_unique_loop.dart';
import 'technique_examples_uniqueness.dart';
import 'technique_examples_wings.dart';
import 'technique_structure.dart';

class TechniqueLegendItem {
  final Color color;
  final String label;

  const TechniqueLegendItem({required this.color, required this.label});
}

class TechniqueInfo {
  final String id;
  final String name;
  final String summary;
  final String definition;
  final String howToSpot;
  final String walkthrough;
  final String caveats;
  final int rank;

  /// 81-char puzzle; 0 = empty
  final String examplePuzzle;
  final BoardMarkup exampleMarkup;
  final List<TechniqueLegendItem> legend;

  /// 只做教学、引擎还没有以本条之名独立报法的条目。
  ///
  /// 这是「本条有没有 finder 兜底」的唯一出处：为真时本条不许出现在
  /// [SudokuSolver.hintSearchOrder] 与 [DifficultyAnalyzer.techniqueScores] 里，
  /// 示意图不许标红删除，而且必须写出 [structure] 让测试独立复核那张图——
  /// 没有 finder 的测试盯着，教学页说错了就没有别的东西会发现。
  final bool teachingOnly;

  /// 本条讲的结构，写成数据供测试独立复核（见 [TeachingStructure]）。
  /// 已实现技巧靠 finder 自己的测试兜底，这里可以留空；
  /// [teachingOnly] 为真的条目一律不许留空。
  final TeachingStructure? structure;

  const TechniqueInfo({
    required this.id,
    required this.name,
    required this.summary,
    required this.definition,
    required this.howToSpot,
    required this.walkthrough,
    required this.caveats,
    required this.rank,
    required this.examplePuzzle,
    required this.exampleMarkup,
    required this.legend,
    this.teachingOnly = false,
    this.structure,
  });

  /// 「复制例题」按钮实际复制的盘面。
  ///
  /// [TechniqueCatalog.practicePuzzles] 里有条目时复制那一张：它比结构示意图更适合
  /// 直接上手。「连点提示走得到本技巧」这一条由 technique_catalog_test 逐条核，
  /// 目前 empty_rect、finned_xwing、finned_swordfish、finned_jellyfish、als_xy
  /// 这五条不达标：练习原题上有更浅的技巧先出面，顺手把目标结构拆掉了
  /// （比如 empty_rect 上刺身鱼 4.6 比空矩形 4.8 浅，先报了就没空矩形可认）。
  /// 所以界面上不再拿「连点提示走得到」当承诺写。
  ///
  /// 没有条目时退回教学示意盘。示意盘只保证本技巧在这块盘上真的成立，
  /// **不保证**连点提示会先报到它——`getHint` 从浅往深试，更浅的技巧常常先出面。
  /// 界面上那一档的说明因此只说「可复制盘面贴入对局」，不许再写成「连点提示可走到本技巧」。
  String get copyPuzzle =>
      TechniqueCatalog.practicePuzzles[id] ?? examplePuzzle;

  bool get copiesPracticeBoard => copyPuzzle != examplePuzzle;
}

/// 从易到难的教学目录，所有条目都配有真实盘面、完整说明与标记。
class TechniqueCatalog {
  static final List<TechniqueInfo> all = _build();

  /// 教学图走提示到不了本技巧时，改复制这些原题。
  static const practicePuzzles = <String, String>{
    'xwing':
        '083020090000800100029300008000098700070000060006740000300006980002005000010030540',
    'jellyfish':
        '004500700020800060060071400000000006006417200300000000007130090080006050003004100',
    'finned_xwing':
        '200050006010000090600801003007090600000703000900080002100000005060902010003060200',
    'finned_swordfish':
        '040280030010006007609070008000092000900000004000740000500020803400800010070035090',
    'finned_jellyfish':
        '005900000010804700900000001500300400203000805001005007100000004002708060000009200',
    'kite':
        '103070002000000040090005001020100503007000200405002060200800030050000000800020709',
    'empty_rect':
        '040062000900000020026300480000004870007000600052800000085001360030000008000530010',
    'w_wing':
        '200050006010000090600801003007090600000703000900080002100000005060902010003060200',
    'wxyz_wing':
        '300090002020104000000300700603500080870000014010007605002001000000905020900030006',
    'ur1':
        '240900001005074009000000080010020005030405060800010040020000000700340500400002078',
    // 连点提示第 13 手报唯一矩形 Type 3：c8 上例外候选和另一格凑成 {3,4,9} 三数组。
    // 原先那张（和 nice_loop 共用）走不到，更浅的技巧一路把结构拆完了。
    'ur3':
        '900050600000000002801320007000508400000760000000290060003000050060000001207400800',
    'nice_loop':
        '500007000200900800000000460020710005000506000600039040087000000005001009000800006',
    'grouped_aic':
        '100605009000000000053010840000951000000060000002080600607000905300807002009000100',
    'als_xz':
        '006000200900000004243000896000591000002080300400203001300000007000907000010408020',
    'als_xy':
        '850000031000070000000809000003000600970301052000020000100407006205000307000080000',
    'sue_de_coq':
        '000003500036405070100000060610309040000040000020706038070000009060504380008100000',
    'death_blossom':
        '004060000015830026060001300100006000206100050050000167589072600400610800601000000',
    'kraken':
        '502070430000400050000020700400502073000010000970603001008050000010004000059030807',
    'nishio':
        '300090002020104000000300700603500080870000014010007605002001000000905020900030006',
  };

  /// 提示/难度分析里出现的名字 → 教学目录里的规范名。
  ///
  /// 目录名跟着评审总表走。finder 现在也报规范名；这里再收一层旧称
  /// （英文原名、带括号的长名），保证按旧名字仍然查得到对应教学条目。
  static const _finderAliases = <String, String>{
    '摒除法（行/列/宫）': '摒除法',
    'Nice Loop / AIC 环': 'Nice Loop',
    'Death Blossom': '死亡绽放',
    'WALS': '弱待定数组',
    'MSLS': '网',
    'Simple Coloring': '染色法',
    'Forcing Chain': '分类强制链',
    'Forcing Net': '分类强制网',
    'Sue de Coq': '融合式待定数组',
    'BUG+1': '全双值坟墓+1',
    'BUG Type 2': '全双值坟墓 Type 2',
    'BUG Type 3': '全双值坟墓 Type 3',
    'BUG Type 4': '全双值坟墓 Type 4',
    'BUG+n': '全双值坟墓+n',
    '待定 BUG': '待定全双值坟墓',
    'Franken 鱼': '宫内鱼',
  };

  static TechniqueInfo? byName(String name) {
    final canonical = _finderAliases[name] ?? name;
    for (final item in all) {
      if (item.name == canonical) return item;
    }
    return null;
  }

  /// 目录按评审总表的「实现」列（从零落地的工程量）从小到大排。
  ///
  /// 每条的 [TechniqueInfo.rank] 就是那一列乘 100，再按解题难度加一位尾数拆平手，
  /// 所以 rank 既是排序键，也直接读得出「这条大概多难做」。
  static List<TechniqueInfo> _build() {
    final items = <TechniqueInfo>[
      ...basicTechniqueExamples(),
      ...fishTechniqueExamples(),
      ...fishVariantTechniqueExamples(),
      ...wingTechniqueExamples(),
      ...uniquenessTechniqueExamples(),
      ...extendedRectTechniqueExamples(),
      ...uniqueLoopTechniqueExamples(),
      ...bugTechniqueExamples(),
      ...pendingTechniqueExamples(),
      ...forcingPatternTechniqueExamples(),
      ...chainTechniqueExamples(),
      ...advancedChainTechniqueExamples(),
      ...advancedSetTechniqueExamples(),
    ];
    items.sort((a, b) => a.rank.compareTo(b.rank));
    return items;
  }
}
