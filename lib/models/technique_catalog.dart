import 'package:flutter/material.dart';
import 'board_markup.dart';
import 'technique_examples_basic.dart';
import 'technique_examples_chains.dart';
import 'technique_examples_fish.dart';
import 'technique_examples_wings.dart';

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
  });

  /// 贴进对局后连点提示，能走到本技巧的原题。
  /// 上图仍是结构示意；两者不同时复制这一串。
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
    'bug1':
        '040062000900000020026300480000004870007000600052800000085001360030000008000530010',
    'ur1':
        '240900001005074009000000080010020005030405060800010040020000000700340500400002078',
    'ur3':
        '500007000200900800000000460020710005000506000600039040087000000005001009000800006',
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
        '000000000001837400004902500040000090508000207200070006700000004030020010005060300',
    'kraken':
        '006000200900000004243000896000591000002080300400203001300000007000907000010408020',
    'nishio':
        '300090002020104000000300700603500080870000014010007605002001000000905020900030006',
  };

  static TechniqueInfo? byName(String name) {
    for (final item in all) {
      if (item.name == name) return item;
    }
    return null;
  }

  static List<TechniqueInfo> _build() {
    final items = <TechniqueInfo>[
      ...basicTechniqueExamples(),
      ...fishTechniqueExamples(),
      ...wingTechniqueExamples(),
      ...chainTechniqueExamples(),
    ];
    return items;
  }
}
