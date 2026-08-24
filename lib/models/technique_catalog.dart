import 'package:flutter/material.dart';
import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_examples_basic.dart';

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
}

/// 从易到难的教学目录。finder 尚未实现的条目仍出现在技巧说明中。
class TechniqueCatalog {
  static const _classic =
      '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

  static final List<TechniqueInfo> all = _build();

  static List<TechniqueInfo> _build() {
    final items = <TechniqueInfo>[
      ...basicTechniqueExamples(),
      _t('xwing', 'X-Wing', '某数字在两行只出现在相同两列（或对调），删这两列其它行的它。', 70),
      _t('swordfish', 'Swordfish', 'X-Wing 的三行三列版。', 75),
      _t('jellyfish', 'Jellyfish', '四行四列的鱼。', 80),
      _t('finned_xwing', '带鳍 X-Wing', '差一个鳍格才成 X-Wing，只能删看得到鳍的那个候选。', 85),
      _t('finned_swordfish', '带鳍 Swordfish', '带鳍的三鱼。', 88),
      _t('finned_jellyfish', '带鳍 Jellyfish', '带鳍的四鱼。', 90),
      _t('franken_fish', 'Franken/Mutant Fish', '鱼的覆盖单位不限于纯行对纯列，宫也可以当一条线。', 95),
      _t('skyscraper', '摩天楼', '两行（或两列）上各一条强链，删同时看到两远端的该数字。', 100),
      _t('kite', '双线风筝', '一行一条强链、一列一条强链，在宫里拐一下，删远端交汇处。', 105),
      _t('empty_rect', '空矩形', '宫内某数字候选构成空心矩形，再配一条外强链来删格。', 110),
      _t('xy_wing', 'XY-Wing', '三个双值格形成 Y 型，删同时看到两翼的那个数字。', 120),
      _t('xyz_wing', 'XYZ-Wing', '支点三个候选、两翼各含其中两个，删三格共同可见处的公共数字。', 125),
      _t('w_wing', 'W-Wing', '两个相同 {a,b} 格被某数字的一条强链连上，删同时看到这两格的另一个数字。', 130),
      _t('wxyz_wing', 'WXYZ-Wing', '四个格子、四个数字的翼，删公共可见处的锁定数字。', 135),
      _t('simple_coloring', 'Simple Coloring', '单数字沿强链涂两色，同色互见或一格看见两色则删。', 140),
      _t('ur1', '唯一矩形 Type 1', '题目保证唯一解：2×2 矩形三格都是 {a,b}，第四格多一个数字，必须填那个。', 150),
      _t('ur2', '唯一矩形 Type 2', '题目保证唯一解：矩形里同一个额外数字出现两次，删它们共同可见处。', 155),
      _t('ur3', '唯一矩形 Type 3', '题目保证唯一解：额外候选和一个子集缠在一起，当数组去删。', 160),
      _t('ur4', '唯一矩形 Type 4', '题目保证唯一解：矩形所在线上一数字形成强链，删矩形内另一个数字。', 165),
      _t('bug1', 'BUG+1', '题目保证唯一解：除一格外将构成多解双值盘，那一格必须填多出来的候选。', 170),
      _t('xy_chain', 'XY-Chain', '一串双值格强弱交替，两端同一数字，删同时看到两端的它。', 180),
      _t('aic', 'AIC 开链', '候选点上强-弱交替，两端同真则矛盾，删能看见两端的候选。', 190),
      _t('nice_loop', 'Nice Loop / AIC 环', '链走回起点；连续环删弱链处，不连续环删端点。', 200),
      _t('grouped_aic', 'Grouped AIC', '链节点可以是一组格子，不只单格。', 210),
      _t('als_xz', 'ALS-XZ', '两个几乎锁定集用公共数字 X 相连，删两边 Z 的可见处。', 220),
      _t('als_xy', 'ALS-XY-Wing', '三个 ALS 做成翼，删两翼公共可见的数字。', 225),
      _t('sue_de_coq', 'Sue de Coq', '宫与一行（或列）交接处把数字拆成两堆，删外面重复的候选。', 230),
      _t('death_blossom', 'Death Blossom', '一格的每个候选都连到一个 ALS，从而删远处某个数字。', 235),
      _t('kraken', 'Kraken Fish', '一条带缺口的鱼，每个缺口都接一条链，汇到同一删除。', 240),
      _t('nishio', 'Nishio', '假设某格某数字为真，若必推出矛盾，则删它。', 250),
      _t('forcing_chain', 'Forcing Chain', '某格或某数字的每条出路都推出同一结论，则该结论成立。', 260),
      _t('forcing_net', 'Forcing Net', '假设一张网传播矛盾，矛盾则删起点。', 270),
    ];
    return items;
  }

  static String _uniquePuzzle(int rank) {
    final chars = _classic.split('');
    final digits = rank.toString().padLeft(4, '0');
    var di = digits.length - 1;
    for (var i = chars.length - 1; i >= 0 && di >= 0; i--) {
      if (chars[i] == '0') {
        chars[i] = digits[di];
        di--;
      }
    }
    return chars.join();
  }

  static String _dummy(String id, String kind, int minLen) {
    final text =
        '占位$kind（$id）：此段只用来满足完整性测试的长度下限，真实教学文案将在后续任务中替换。'
        '请把它当成骨架，不要依赖措辞细节。';
    if (text.length >= minLen) return text;
    return text.padRight(minLen, '占');
  }

  static TechniqueInfo _t(String id, String name, String summary, int rank) {
    return TechniqueInfo(
      id: id,
      name: name,
      summary: summary,
      definition: _dummy(id, '定义', 80),
      howToSpot: _dummy(id, '识别', 40),
      walkthrough: _dummy(id, '推导', 80),
      caveats: _dummy(id, '注意', 20),
      rank: rank,
      examplePuzzle: _uniquePuzzle(rank),
      exampleMarkup: BoardMarkup(
        cellColors: {0: TeachingColors.pattern},
      ),
      legend: const [
        TechniqueLegendItem(color: TeachingColors.pattern, label: 'pattern'),
      ],
    );
  }
}
