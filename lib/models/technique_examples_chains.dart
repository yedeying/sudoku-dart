import 'package:flutter/material.dart';
import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_catalog.dart';

int _ck(int r, int c) => BoardMarkup.cellKey(r, c);
CandidateRef _cr(int r, int c, int n) => CandidateRef(r, c, n);
MarkupArrow _arrow(
  int r1,
  int c1,
  int n1,
  int r2,
  int c2,
  int n2,
  ArrowKind kind,
) =>
    MarkupArrow(from: _cr(r1, c1, n1), to: _cr(r2, c2, n2), kind: kind);

const _chainLegend = [
  TechniqueLegendItem(color: TeachingColors.start, label: '起点'),
  TechniqueLegendItem(color: TeachingColors.node, label: '中继格'),
  TechniqueLegendItem(color: TeachingColors.end, label: '终点'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

const _groupedLegend = [
  TechniqueLegendItem(color: TeachingColors.start, label: '单格节点'),
  TechniqueLegendItem(color: TeachingColors.end, label: '成组节点'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

const _alsLegend = [
  TechniqueLegendItem(color: TeachingColors.start, label: 'ALS A'),
  TechniqueLegendItem(color: TeachingColors.end, label: 'ALS B'),
  TechniqueLegendItem(color: TeachingColors.node, label: '支点/交接'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

const _forcingLegend = [
  TechniqueLegendItem(color: TeachingColors.start, label: '假设'),
  TechniqueLegendItem(color: TeachingColors.node, label: '推导中继'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '矛盾/删除'),
];

const _krakenLegend = [
  TechniqueLegendItem(color: TeachingColors.house, label: '基线与覆盖线'),
  TechniqueLegendItem(color: TeachingColors.pattern, label: '鱼身'),
  TechniqueLegendItem(color: TeachingColors.end, label: '鳍'),
  TechniqueLegendItem(color: TeachingColors.node, label: '鳍上推出的唯余'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

const _nishioLegend = [
  TechniqueLegendItem(color: TeachingColors.start, label: '假设'),
  TechniqueLegendItem(color: TeachingColors.node, label: '推导中继'),
  TechniqueLegendItem(color: TeachingColors.contradiction, label: '矛盾格（候选被排空）'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

/// 链类通用标记：起点涂 start（绿），终点涂 end（黄），中继格涂 node（蓝），
/// 被删除候选所在格涂 elimCell（浅黄）、候选本身涂 elimCand（红）。
BoardMarkup _chainMarkup({
  required List<int> start,
  required List<int> end,
  List<List<int>> nodes = const [],
  List<MarkupArrow> arrows = const [],
  List<List<int>> eliminated = const [],
}) {
  final cellColors = <int, Color>{
    _ck(start[0], start[1]): TeachingColors.start,
    _ck(end[0], end[1]): TeachingColors.end,
    for (final n in nodes) _ck(n[0], n[1]): TeachingColors.node,
  };
  for (final e in eliminated) {
    cellColors[_ck(e[0], e[1])] = TeachingColors.elimCell;
  }
  return BoardMarkup(
    cellColors: cellColors,
    candidateColors: {
      for (final a in arrows) a.from: TeachingColors.node,
      for (final a in arrows) a.to: TeachingColors.node,
      for (final e in eliminated)
        _cr(e[0], e[1], e[2]): TeachingColors.elimCand,
    },
    arrows: arrows,
  );
}

/// 区块链 专用：一端是单个格子（start，绿），另一端是一组格子（end，黄）。
BoardMarkup _groupedMarkup({
  required List<int> single,
  required List<List<int>> group,
  List<MarkupArrow> arrows = const [],
  List<List<int>> eliminated = const [],
}) {
  final cellColors = <int, Color>{
    _ck(single[0], single[1]): TeachingColors.start,
    for (final g in group) _ck(g[0], g[1]): TeachingColors.end,
  };
  for (final e in eliminated) {
    cellColors[_ck(e[0], e[1])] = TeachingColors.elimCell;
  }
  return BoardMarkup(
    cellColors: cellColors,
    candidateColors: {
      for (final a in arrows) a.from: TeachingColors.node,
      for (final a in arrows) a.to: TeachingColors.node,
      for (final e in eliminated)
        _cr(e[0], e[1], e[2]): TeachingColors.elimCand,
    },
    arrows: arrows,
  );
}

/// ALS 系列专用：ALS A 涂 start（绿），ALS B 涂 end（黄），
/// 额外的支点/第三个 ALS 涂 node（蓝），删除同 [_chainMarkup]。
BoardMarkup _alsMarkup({
  required List<List<int>> alsA,
  required List<List<int>> alsB,
  List<List<int>> pivot = const [],
  List<MarkupArrow> arrows = const [],
  List<List<int>> eliminated = const [],
}) {
  final cellColors = <int, Color>{
    for (final c in pivot) _ck(c[0], c[1]): TeachingColors.node,
    for (final c in alsA) _ck(c[0], c[1]): TeachingColors.start,
    for (final c in alsB) _ck(c[0], c[1]): TeachingColors.end,
  };
  for (final e in eliminated) {
    cellColors[_ck(e[0], e[1])] = TeachingColors.elimCell;
  }
  return BoardMarkup(
    cellColors: cellColors,
    candidateColors: {
      for (final a in arrows) a.from: TeachingColors.node,
      for (final a in arrows) a.to: TeachingColors.node,
      for (final e in eliminated)
        _cr(e[0], e[1], e[2]): TeachingColors.elimCand,
    },
    arrows: arrows,
  );
}

/// Kraken 专用：基线/覆盖线淡亮，鱼身涂 pattern，鳍涂 end，
/// 鳍上推出的唯余涂 node，删除涂 elimCand。
BoardMarkup _krakenMarkup({
  required int digit,
  required List<int> rows,
  required List<int> cols,
  required List<List<int>> pattern,
  required List<List<int>> fin,
  List<MarkupArrow> arrows = const [],
  List<List<int>> eliminated = const [],
}) {
  final cellColors = <int, Color>{
    for (final r in rows)
      for (var c = 0; c < 9; c++) _ck(r, c): TeachingColors.house,
    for (final c in cols)
      for (var r = 0; r < 9; r++) _ck(r, c): TeachingColors.house,
  };
  for (final c in pattern) {
    cellColors[_ck(c[0], c[1])] = TeachingColors.pattern;
  }
  for (final c in fin) {
    cellColors[_ck(c[0], c[1])] = TeachingColors.end;
  }
  for (final e in eliminated) {
    cellColors[_ck(e[0], e[1])] = TeachingColors.elimCell;
  }
  return BoardMarkup(
    cellColors: cellColors,
    candidateColors: {
      for (final a in arrows) a.from: TeachingColors.node,
      for (final a in arrows) a.to: TeachingColors.node,
      for (final c in pattern) _cr(c[0], c[1], digit): TeachingColors.node,
      for (final c in fin) _cr(c[0], c[1], digit): TeachingColors.end,
      for (final e in eliminated)
        _cr(e[0], e[1], e[2]): TeachingColors.elimCand,
    },
    arrows: arrows,
  );
}

/// Nishio / Forcing 专用：假设格涂 start（绿），推导路径上的格子涂 node（蓝），
/// 矛盾或最终删除的候选涂 elimCand（红），所在格涂 elimCell。
BoardMarkup _forcingMarkup({
  required List<int> assumption,
  List<List<int>> path = const [],
  List<MarkupArrow> arrows = const [],
  List<List<int>> eliminated = const [],
  List<int>? contradiction,
}) {
  // 先铺 elimCell，再让假设格/推导格/矛盾格覆盖上去：假设格即便和删除目标
  // 同格（如 Nishio 反证），也要保住 start 的绿色，不能被压成一样的高亮。
  final cellColors = <int, Color>{
    for (final e in eliminated) _ck(e[0], e[1]): TeachingColors.elimCell,
  };
  for (final p in path) {
    cellColors[_ck(p[0], p[1])] = TeachingColors.node;
  }
  cellColors[_ck(assumption[0], assumption[1])] = TeachingColors.start;
  // 矛盾格（假设推导后候选被排空的那一格）单独上色，
  // 不能和真正被删除的候选共用红色，否则会读成「这格的答案是它」。
  if (contradiction != null) {
    cellColors[_ck(contradiction[0], contradiction[1])] =
        TeachingColors.contradiction;
  }
  return BoardMarkup(
    cellColors: cellColors,
    candidateColors: {
      for (final a in arrows) a.from: TeachingColors.node,
      for (final a in arrows) a.to: TeachingColors.node,
      for (final e in eliminated)
        _cr(e[0], e[1], e[2]): TeachingColors.elimCand,
    },
    arrows: arrows,
  );
}

/// 链、ALS 与强制类技巧的十二个教学盘面。
///
/// XY-Chain、AIC、Nice Loop、区块链、ALS-XZ、ALS-XY-Wing 都是用脚本在
/// 候选图上做强弱交替深搜，从真实题库（expert/hard/medium/easy）里挖出的
/// 真实链条，逐格核对候选、强弱链归属单元（同格 / 同行 / 同列 / 同宫）与
/// 删除目标的可见关系。融合式待定数组、死亡绽放、Kraken Fish 同样用脚本在
/// 真实题库的候选表里找到满足结构定义的交集/花瓣/带鳍鱼接链，并逐条验证
/// 强链、ALS、限制公共数的可见关系。Nishio、分类强制链、分类强制网用
/// 单数排除的传播引擎在真实题库上跑出假设后的连锁填数，Nishio 一路推到
/// 某格无候选可填的矛盾，分类强制链/Net 则确认同一格的两三条出路都推出
/// 同一个结论——每个盘面都经过脚本重新验证候选与推导链，不是手造的示意图。
List<TechniqueInfo> chainTechniqueExamples() => [
      TechniqueInfo(
        id: 'xy_chain',
        name: 'XY-Chain',
        summary: '一串双值格靠强弱链交替相连，两端落在同一个数字上，删同时看到两端的它。',
        definition: 'XY-Chain 是全部由双值格组成的链：每一格恰好两个候选，格内两个候选'
            '自身就是一条强链（不是这个就是那个），相邻两格之间再靠同一个数字的强链或'
            '弱链首尾相连，链条一路交替下去。只要链的第一格和最后一格恰好共享同一个'
            '数字，且这两格都恰好靠强链连入链条，就能保证「链首为这个数字」或'
            '「链尾为这个数字」至少有一个成立，因此同时能看到链首和链尾的格子，'
            '这个数字都不可能出现，可以删除。',
        howToSpot: '先找一个双值格出发，顺着候选数字在行、列、宫之间找强链或弱链一路'
            '连下去，检查每一格是否都恰好是双值格，链首链尾是否共享同一个数字。',
        walkthrough: '本例中r1c8候选 {4, 6}，与r2c7候选 {5, 6} 因'
            '同宫的候选 6 相连；r2c7的另一候选 5，又与r9c7候选 '
            '{4, 5} 因同列的候选 5 相连。链首r1c8与链尾r9c7都'
            '共享候选 4：若链首不是 4，则它是 6，于是 r2c7 不能是 6、只能是 5，'
            '接着 r9c7 不能是 5、只能是 4——无论链首是不是 4，4 总会落在'
            '链首或链尾之一。因此同时看到这两格的 r1c7 不可能是 4，删除该处'
            '候选 4。\n'
            '4r1c8 = 6r1c8 - 6r2c7 = 5r2c7 - 5r9c7 = 4r9c7',
        caveats: '链上每一格都必须真的是双值格，缺一个都不能叫 XY-Chain；'
            '链首链尾必须共享同一个数字，且都要靠强链连入链条，否则「至少一真」'
            '的结论不成立。',
        rank: 552,
        examplePuzzle:
            '590000007040010083008034900001402000069000820000109300004670200980040030700000016',
        exampleMarkup: _chainMarkup(
          start: [0, 7],
          end: [8, 6],
          nodes: [
            [1, 6],
          ],
          arrows: [
            _arrow(0, 7, 4, 0, 7, 6, ArrowKind.strong),
            _arrow(0, 7, 6, 1, 6, 6, ArrowKind.weak),
            _arrow(1, 6, 6, 1, 6, 5, ArrowKind.strong),
            _arrow(1, 6, 5, 8, 6, 5, ArrowKind.weak),
            _arrow(8, 6, 5, 8, 6, 4, ArrowKind.strong),
          ],
          eliminated: [
            [0, 6, 4],
          ],
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'aic',
        name: '强弱交替链',
        summary: '候选点之间强弱交替连成一条开链，两端同一数字，删同时看到两端的候选。',
        definition: 'AIC（交替推理链，Alternating Inference Chain）不要求链上每一格都是'
            '双值格，只要求相邻候选点之间的连接是强链或弱链，并且严格交替：强、弱、'
            '强、弱……链的第一条和最后一条连接都必须是强链，这样链首候选点和链尾'
            '候选点（同一个数字）就至少有一个为真——因为一旦链首为假，强链会推出'
            '它相连的下一点为真，再由弱链、强链一路传递，最终推出链尾为真。因此同时'
            '能看到链首和链尾的格子，这个数字都不可能出现，可以删除。',
        howToSpot: '从任意一个候选点出发，按强链、弱链交替向外延伸，留意每一步连接'
            '所属的单元（同格、同行、同列或同宫），检查首尾两条连接是否都是强链。',
        walkthrough: '本例中r4c9候选 1 与r5c9候选 1 因c9只剩'
            '这两格能填 1 构成强链；r5c9再与r5c3因同一行还有别的'
            '候选 1 构成弱链；r5c3又与r6c3因c3只剩这两格能填 1 '
            '构成强链。链首r4c9与链尾r6c3都是候选 1，且首尾都是'
            '强链连入，因此两者至少有一个是 1。同时看到两端的 r6c7 不可能是 '
            '1，删除该处候选 1。\n'
            '1r4c9 = 1r5c9 - 1r5c3 = 1r6c3',
        caveats: '交替顺序不能乱，链首链尾必须都由强链连入链条；弱链只能保证'
            '「不同时为真」，不能单独用来判断链首链尾至少一真。',
        rank: 602,
        examplePuzzle:
            '200050006010000090600801003007090600000703000900080002100000005060902010003060200',
        exampleMarkup: _chainMarkup(
          start: [3, 8],
          end: [5, 2],
          nodes: [
            [4, 8],
            [4, 2],
          ],
          arrows: [
            _arrow(3, 8, 1, 4, 8, 1, ArrowKind.strong),
            _arrow(4, 8, 1, 4, 2, 1, ArrowKind.weak),
            _arrow(4, 2, 1, 5, 2, 1, ArrowKind.strong),
          ],
          eliminated: [
            [5, 6, 1],
          ],
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'nice_loop',
        name: 'Nice Loop',
        summary: '链绕一圈又连回起点附近，环上任意一段强-弱-强子链都能像 AIC 一样删。',
        definition: 'Nice Loop 是首尾相连成环的 AIC：链从某个候选点出发，强弱交替走完'
            '一圈后又通过一条连接回到出发点，整条环上的连接严格交替、连续不断。'
            '虽然环本身是一个整体，但环上任意截取一段「以强链开头、以强链结尾」的'
            '子链，都可以照搬普通 AIC 的结论——这一段子链两端的数字至少有一个为真，'
            '同时能看到这两端的格子就不能再是这个数字，可以删除；环的其它连接也可以'
            '各自截取出同样的子链来验证更多删除。',
        howToSpot: '找到强弱交替的链后，看它是否绕回了出发点附近的候选点，'
            '再从环上挑一段以强链起、以强链止的子链，检查是否有格子同时看到这段'
            '子链的两端。',
        walkthrough: '本例中 8r1c5 与 8r5c5 经强弱交替绕成一圈。'
            '取「以强链开头、以强链结尾」的这一段，两端的 8 至少有一处为真，'
            '同时看见两端的 8r3c5 可删。\n'
            '8r1c5 = 8r1c3 - 6r1c3 = 6r2c3 - 6r2c5 = 4r2c5 - 4r5c5 = 8r5c5 - 8r1c5',
        caveats: '环上每一条连接都要单独核实是强链还是弱链，不能想当然认为绕回去'
            '就一定成立；用来删除的子链两端仍必须都由强链连入，弱链收尾不能直接删。'
            '这一盘更浅的技巧会先出面，连点提示随后报到这一手。',
        rank: 604,
        examplePuzzle:
            '500007000200900850000000460020710605000506000650239740087000004065071289002800076',
        exampleMarkup: _chainMarkup(
          start: [0, 4],
          end: [4, 4],
          nodes: [
            [0, 2],
            [1, 2],
            [1, 4],
          ],
          arrows: [
            _arrow(0, 4, 8, 0, 2, 8, ArrowKind.strong),
            _arrow(0, 2, 8, 0, 2, 6, ArrowKind.weak),
            _arrow(0, 2, 6, 1, 2, 6, ArrowKind.strong),
            _arrow(1, 2, 6, 1, 4, 6, ArrowKind.weak),
            _arrow(1, 4, 6, 1, 4, 4, ArrowKind.strong),
            _arrow(1, 4, 4, 4, 4, 4, ArrowKind.weak),
            _arrow(4, 4, 4, 4, 4, 8, ArrowKind.strong),
            _arrow(4, 4, 8, 0, 4, 8, ArrowKind.weak),
          ],
          eliminated: [
            [2, 4, 8],
          ],
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'grouped_aic',
        name: '区块链',
        summary: '链的一个节点可以是同宫里的一组格子，配合另一端单格构成强链再删除。',
        definition: '区块链 里链上的节点不必是单独一格，可以是同一个宫、同一行或'
            '同一列里的一组格子——只要这组格子恰好都在同一个宫内，就可以把它们当成'
            '一个整体节点参与强链。例如某个数字在一列上只剩三格能填，其中两格恰好同'
            '在一个宫内，就可以把这两格捆成一个组，和列上第三格构成强链：组和第三格'
            '至少有一个是这个数字。凡是能同时看到「组的所在宫」和「第三格」的格子，'
            '这个数字都不可能出现，可以删除。',
        howToSpot: '先找一个数字在某条线上恰好剩三格的候选，看是否有两格恰好同宫，'
            '把这两格捆成一组，再看是否有格子同时能看到这个组所在的宫和线上剩下的'
            '那一格。',
        walkthrough: '本例中数字 7 在 r2 上，右上宫的 {7r2c7, 7r2c8, 7r2c9} '
            '捆成一组，与 7r2c5 经强弱交替相连。两端的 7 至少有一处为真，'
            '同时看见两端的 7r2c4 可删。\n'
            '{7r2c7, 7r2c8, 7r2c9} = 7r2c4 - 7r1c5 = 7r2c5',
        caveats: '组内的格子必须真的同在一个宫里，不能跨宫勉强拼凑；删除目标要能同时'
            '看到组的整体（同宫即可，不必看到组内每一格分别所在的行列）和单独节点。'
            '这一盘更浅的技巧会先出面，连点提示随后报到这一手。',
        rank: 701,
        examplePuzzle:
            '100605009000008000753219846000951000001062000502080600607100905315897462009506100',
        exampleMarkup: _groupedMarkup(
          single: [1, 4],
          group: [
            [1, 6],
            [1, 7],
            [1, 8],
          ],
          arrows: [
            _arrow(1, 6, 7, 1, 3, 7, ArrowKind.strong),
            _arrow(1, 7, 7, 1, 3, 7, ArrowKind.strong),
            _arrow(1, 8, 7, 1, 3, 7, ArrowKind.strong),
            _arrow(1, 3, 7, 0, 4, 7, ArrowKind.weak),
            _arrow(1, 4, 7, 0, 4, 7, ArrowKind.weak),
            _arrow(0, 4, 7, 1, 4, 7, ArrowKind.strong),
          ],
          eliminated: [
            [1, 3, 7],
          ],
        ),
        legend: _groupedLegend,
      ),
      TechniqueInfo(
        id: 'als_xz',
        name: 'ALS-XZ',
        summary: '两个待定数组靠限制公共数字 X 相连，再删两边都含的另一个数字 Z。',
        definition: '待定数组（ALS）指同一行、列或宫里 N 个空格恰好只剩 N+1 个候选'
            '数字。ALS-XZ 用两个互不重叠的 ALS：如果它们共享数字 X，且 X 在两个 ALS '
            '里出现的格子彼此都能互相看到（限制公共候选），那么 X 最终只会落在其中'
            '一个 ALS 里——填了 X 的那个 ALS 会用掉一个候选名额，迫使另一个 ALS 里剩下'
            'N 个候选正好填满 N 个格子，成为「真正」的锁定集。如果两个 ALS 还共享'
            '另一个数字 Z，那么无论 X 落在哪个 ALS，Z 都必然会出现在某个 ALS 里，'
            '因此同时能看到两个 ALS 里所有 Z 候选的格子，Z 都不可能出现，可以删除。',
        howToSpot: '先在两个不重叠的区域各找一个待定数组，看它们是否共享两个数字：'
            '一个作限制公共候选 X（两边的 X 格必须互相可见），另一个作 Z，'
            '再看谁能同时看到两个 ALS 里所有的 Z。',
        walkthrough: '本例中 r1c4 单独构成候选 {3, 8} 的 ALS A，'
            'r2c4、r3c4、r5c4、r7c4 构成 ALS B。两边以 8 为限制公共候选：'
            '无论 8 落在哪一侧，Z=3 都会出现在某个 ALS 里，'
            '因此同时看见两边所有 3 的 3r2c5 可删。',
        caveats: '两个 ALS 的格子不能重叠；限制公共候选 X 要求两边所有含 X 的格子'
            '互相可见，只是共享数字不满足这一条时不能当作 X，只能退回普通候选重合。'
            '这一盘更浅的技巧会先出面，连点提示随后报到这一手。',
        rank: 652,
        examplePuzzle:
            '076049210901000004243005896030591002102084300400203001300000007000907008010408020',
        exampleMarkup: _alsMarkup(
          alsA: [
            [0, 3],
          ],
          alsB: [
            [1, 3],
            [2, 3],
            [4, 3],
            [6, 3],
          ],
          arrows: [
            _arrow(0, 3, 8, 1, 3, 8, ArrowKind.strong),
          ],
          eliminated: [
            [1, 4, 3],
          ],
        ),
        legend: _alsLegend,
      ),
      TechniqueInfo(
        id: 'als_xy',
        name: 'ALS-XY-Wing',
        summary: '一个支点 ALS 用两个数字分别连两个翼 ALS，删两翼共有的第三个数字。',
        definition: 'ALS-XY-Wing 是 XY-Wing 的 ALS 版本：支点 ALS 里有两个数字 X、Y，'
            '分别和两个翼 ALS 构成限制公共候选——X 与翼 A 里的 X 格互相可见，Y 与翼'
            'B 里的 Y 格互相可见，且两个翼 ALS 还共享另一个数字 Z。支点最终会用掉 X '
            '或 Y 中的一个名额：用掉 X 时，翼 A 必须填满剩下的候选（包含 Z）；用掉 Y 时，'
            '翼 B 必须填满剩下的候选（也包含 Z）——无论哪种情况，Z 都会落在某个翼 ALS '
            '里，因此同时能看到两个翼 ALS 里所有 Z 候选的格子，Z 都不可能出现，'
            '可以删除。',
        howToSpot: '先找一个待定数组当支点，看它是否能用两个不同的数字，各自和另'
            '一个待定数组构成限制公共候选，再看这两个翼 ALS 是否还共享第三个数字。',
        walkthrough: '本例中 r4c5, r4c6 组成候选 {1, 4, 7} 的支点 ALS，它用候选 1 '
            '连到r5c5与r6c4组成的候选 {1, 5, 7} 翼 A，又用候选 4 '
            '连到r4c9与r8c9组成的候选 {4, 5, 7} 翼 B。两个翼 ALS '
            '还共享候选 5：支点填 1 时，翼 A 必须用掉 5、7；支点填 4 时，翼 B 必须用掉 5、7。'
            '无论哪种情况，5 都会落在某个翼 ALS 里，因此同时看到两翼所有候选 5 的'
            'r8c4不可能是 5，删除该处候选 5。',
        caveats: '支点连两翼要用两个不同的数字，且各自都要满足限制公共候选的可见'
            '条件；两个翼 ALS 必须真的共享第三个数字，缺了这一条不能算 XY-Wing 结构。',
        rank: 706,
        examplePuzzle:
            '604000053000400620000020091250900800009203506030068900000000000482090000300040009',
        exampleMarkup: _alsMarkup(
          pivot: [
            [3, 4],
            [3, 5],
          ],
          alsA: [
            [4, 4],
            [5, 3],
          ],
          alsB: [
            [3, 8],
            [7, 8],
          ],
          arrows: [
            _arrow(3, 4, 1, 5, 3, 1, ArrowKind.strong),
            _arrow(3, 5, 4, 3, 8, 4, ArrowKind.strong),
            _arrow(5, 3, 5, 7, 3, 5, ArrowKind.weak),
            _arrow(7, 8, 5, 7, 3, 5, ArrowKind.weak),
          ],
          eliminated: [
            [7, 3, 5],
          ],
        ),
        legend: _alsLegend,
      ),
      TechniqueInfo(
        id: 'sue_de_coq',
        name: '融合待定数组',
        summary: '宫与线的交叉格将候选数拆分为两组，分别与宫内、线上的待定数组构成零秩锁定。',
        definition: '融合待定数组（Sue de Coq，简称 SDC）发生在一个宫与一条线（行或列）的交叉区域：'
            '若交叉格的候选数可被划分为两个互不重叠的子集，分别与交叉处以外的宫内待定数组（ALS）、线上待定数组（ALS）'
            '构成总格数等于总数字数的零秩锁定，则宫内其余格可删去第一组与宫内 ALS 的候选数，线上其余格可删去第二组与线上 ALS 的候选数。',
        howToSpot: '先找一个宫与一行（或列）的交叉处，数一数交叉格候选总数是否比'
            '格数多 2 个以上，再看能不能把候选拆成两堆，分别在宫内、线上找到正好'
            '覆盖的待定数组。',
        walkthrough: '本例中 r1c8、r1c9 是右上宫与 r1 的交叉格，'
            '把候选拆成 1、2 与 4、9。宫内 r2c9 消化 1、2，线上 r1c2 消化 4、9。'
            '因此宫内别处的 2（2r2c7、2r3c7）和线上别处的 9、4（9r1c1、4r1c3）都可删。',
        caveats: '两堆候选必须不重叠、合起来正好等于交叉格的全部候选；宫内、线上'
            '找到的待定数组也不能占用交叉格本身，覆盖的候选要恰好和分到的那一堆'
            '完全一致。'
            '这一盘更浅的技巧会先出面，连点提示随后报到这一手。',
        rank: 603,
        examplePuzzle:
            '000003500036405070150900063610389040080241000429756138070000009060504380008100000',
        exampleMarkup: _alsMarkup(
          alsA: [
            [1, 8],
          ],
          alsB: [
            [0, 1],
          ],
          pivot: [
            [0, 7],
            [0, 8],
          ],
          eliminated: [
            [1, 6, 2],
            [2, 6, 2],
            [0, 0, 9],
            [0, 2, 4],
          ],
        ),
        legend: _alsLegend,
      ),
      TechniqueInfo(
        id: 'death_blossom',
        name: '死亡绽放',
        summary: '一个格子的每个候选都各连到一个待定数组，几个花瓣汇出同一个删除。',
        definition: '死亡绽放以一个「花心」格子出发：花心有几个候选'
            '数字，为其中每一个候选各找一个待定数组（花瓣），要求花心能看到花瓣里'
            '所有含这个候选的格子。花心最终会填某一个候选，对应的花瓣就必须去掉这个候选'
            '排除掉，转而用完剩下的候选——如果所有花瓣（对应花心的每一个候选）在'
            '排除后都会共同挤出同一个数字 Z，那么无论花心最终填哪个候选，Z 都会'
            '落在某个花瓣里，因此同时能看到所有花瓣里 Z 候选的格子，Z 都不可能'
            '出现，可以删除。',
        howToSpot: '先找一个候选不算多的花心格子，为它的每个候选分别找一个能被花心'
            '看到的待定数组，再看这些花瓣排除掉花心对应候选之后，是否都会挤出'
            '同一个数字。',
        walkthrough: '本例中r7c2是花心，候选 {3, 5, 9}。候选 3 连到r7'
            'c6（候选 {1, 3}）这个花瓣；候选 5 连到 r8c1 与 r9c3 '
            '（候选 {1, 5, 9}）这个花瓣；候选 9 连到 r7c4（候选 {1, 9}）'
            '这个花瓣。花心填 3、5 或 9 中的任意一个，对应花瓣排除这个候选后都会'
            '挤出候选 1。因此同时看到这三个花瓣里候选 1 所在格子的r8c5'
            '不可能是 1，删除该处候选 1。',
        caveats: '花心必须能看到每个花瓣里所有含对应候选的格子，缺一个可见关系'
            '整条推理就不成立；共同挤出的数字必须真的出现在每一个花瓣里，'
            '漏掉一个花瓣就不能保证「无论如何都会落在某个花瓣」。',
        rank: 705,
        examplePuzzle:
            '000809000043000870020000010300020009000308000010000020607000402084205690200704001',
        exampleMarkup: _forcingMarkup(
          assumption: [6, 1],
          path: [
            [6, 5],
            [7, 0],
            [8, 2],
            [6, 3],
          ],
          arrows: [
            _arrow(6, 1, 3, 6, 5, 3, ArrowKind.weak),
            _arrow(6, 1, 5, 8, 2, 5, ArrowKind.weak),
            _arrow(6, 1, 9, 6, 3, 9, ArrowKind.weak),
          ],
          eliminated: [
            [7, 4, 1],
          ],
        ),
        legend: _forcingLegend,
      ),
      TechniqueInfo(
        id: 'kraken',
        name: 'Kraken Fish',
        summary: '带鳍鱼删不掉的覆盖候选，每一枚鳍再接一条短唯余链，两种情形都指向同一处删除。',
        definition: 'Kraken Fish 从一条几乎成形的鱼出发，常见是带鳍 X-Wing 或'
            ' Swordfish。鳍全为假时鱼成立，覆盖线上鱼身以外的同名候选没位置可待。'
            '普通带鳍鱼还要求删除目标看得见全部鳍；目标看不到某枚鳍时，这一手就停住了。'
            'Kraken 补上另一支：假设那枚鳍为真，用唯一余数往下推，若也能把同一个'
            '候选拿掉，两种情形就汇到同一处删除。',
        howToSpot: '先找差一两个鳍才成的 X-Wing 或 Swordfish，看覆盖线上有没有'
            '看不到全部鳍的同名候选。对每一枚它看不见的鳍，假设该格填这个数字，'
            '只用唯一余数推几步，看这个候选会不会消失。',
        walkthrough: '本例中数字 1 在 r1、r2 上几乎构成 X-Wing，覆盖列是 c1 和 c6，'
            '多出来的鳍是 r1c4 与 r2c7。覆盖列上的 1r7c6 看不到这两枚鳍，'
            '普通带鳍鱼删不掉它。若两枚鳍都为假，X-Wing 成立，c1、c6 上鱼身以外的 1 '
            '都没位置。若 1r1c4 为真，唯一余数依次推出 2r9c4、6r9c1、1r9c6，'
            '1r7c6 也被排除。若 1r2c7 为真，则推出 1r3c1、1r7c8、2r8c8，'
            '同样去掉 1r7c6。无论鳍真假，这个候选都要删除。',
        caveats: '看得见全部鳍的删除是普通带鳍鱼，不要改叫 Kraken。'
            '鳍上的推导必须是真实的唯一余数，不能跳步；链太长就不是认形，而是把整盘推完。'
            '这一盘更浅的技巧会先出面，连点提示随后报到这一手。',
        rank: 751,
        examplePuzzle:
            '502070430030400052004325700401502073020010504975643281048050000010004005059030847',
        exampleMarkup: _krakenMarkup(
          digit: 1,
          rows: [0, 1],
          cols: [0, 5],
          pattern: [
            [0, 5],
            [1, 0],
            [1, 5],
          ],
          fin: [
            [0, 3],
            [1, 6],
          ],
          arrows: [
            _arrow(0, 3, 1, 8, 3, 2, ArrowKind.weak),
            _arrow(8, 3, 2, 8, 0, 6, ArrowKind.weak),
            _arrow(8, 0, 6, 8, 5, 1, ArrowKind.weak),
            _arrow(8, 5, 1, 6, 5, 1, ArrowKind.weak),
            _arrow(1, 6, 1, 2, 0, 1, ArrowKind.weak),
            _arrow(2, 0, 1, 6, 7, 1, ArrowKind.weak),
            _arrow(6, 7, 1, 7, 7, 2, ArrowKind.weak),
            _arrow(7, 7, 2, 6, 5, 1, ArrowKind.weak),
          ],
          eliminated: [
            [6, 5, 1],
          ],
        ),
        legend: _krakenLegend,
      ),
      TechniqueInfo(
        id: 'nishio',
        name: 'Nishio',
        summary: '假设某格填某个候选，若能一路推出某格无候选可填的矛盾，则删这个候选。',
        definition: 'Nishio 是最直接的试错法：先假设某个格子填某个候选数字，然后照常'
            '用唯一余数、区块排除等基础方法一路往下推。如果推到某一步，发现某个'
            '格子的候选被推空了（找不到任何数字可填），就说明最初的假设错了——'
            '这个候选数字必须从最初那格删除。Nishio 不要求推出具体是谁填了什么，'
            '只要能推出「某格无解」这一个矛盾就足够了。',
        howToSpot: '挑一个候选不多的格子，任选其中一个候选先假设成立，'
            '按基础方法一路推导填数，留意每一步是否让某个格子的候选被排除干净。',
        walkthrough: '本例中假设 2r5c5 为真。唯一余数依次推出 '
            '6r5c4、2r3c6、8r9c6、6r1c6、4r7c4、8r6c4、4r6c5，'
            '再往下走到 3r7c2 时，r7c9 候选被排空，出现矛盾。'
            '因此最初的假设不成立，删除 2r5c5。',
        caveats: '每一步推导都要依据真实的基础规则（唯一余数、区块排除等），'
            '不能凭空跳步；矛盾必须是「某格候选被排空」，只是推出一个不喜欢的结果'
            '不算矛盾。'
            '这一盘更浅的技巧会先出面，连点提示随后报到这一手。',
        rank: 553,
        examplePuzzle:
            '300790002020104000090300700643519287875003914219007635002001000000905020900030006',
        exampleMarkup: _forcingMarkup(
          assumption: [4, 4],
          path: [
            [4, 3],
            [2, 5],
            [8, 5],
            [0, 5],
            [6, 3],
            [5, 3],
            [5, 4],
            [8, 1],
            [0, 1],
            [6, 0],
            [1, 0],
            [1, 4],
            [1, 6],
            [1, 8],
            [1, 7],
            [1, 2],
            [2, 4],
            [2, 7],
            [0, 7],
            [0, 6],
            [0, 2],
            [2, 0],
            [2, 2],
            [2, 8],
            [6, 4],
            [6, 1],
          ],
          arrows: [
            _arrow(4, 4, 2, 4, 3, 6, ArrowKind.weak),
            _arrow(4, 3, 6, 2, 5, 2, ArrowKind.weak),
            _arrow(2, 5, 2, 8, 5, 8, ArrowKind.weak),
            _arrow(8, 5, 8, 0, 5, 6, ArrowKind.weak),
            _arrow(0, 5, 6, 6, 3, 4, ArrowKind.weak),
            _arrow(6, 3, 4, 5, 3, 8, ArrowKind.weak),
            _arrow(5, 3, 8, 5, 4, 4, ArrowKind.weak),
            _arrow(5, 4, 4, 8, 1, 5, ArrowKind.weak),
            _arrow(8, 1, 5, 0, 1, 8, ArrowKind.weak),
            _arrow(0, 1, 8, 6, 0, 7, ArrowKind.weak),
            _arrow(6, 0, 7, 1, 0, 5, ArrowKind.weak),
            _arrow(1, 0, 5, 1, 4, 8, ArrowKind.weak),
            _arrow(1, 4, 8, 1, 6, 3, ArrowKind.weak),
            _arrow(1, 6, 3, 1, 8, 9, ArrowKind.weak),
            _arrow(1, 8, 9, 1, 7, 6, ArrowKind.weak),
            _arrow(1, 7, 6, 1, 2, 7, ArrowKind.weak),
            _arrow(1, 2, 7, 2, 4, 5, ArrowKind.weak),
            _arrow(2, 4, 5, 2, 7, 4, ArrowKind.weak),
            _arrow(2, 7, 4, 0, 7, 5, ArrowKind.weak),
            _arrow(0, 7, 5, 0, 6, 1, ArrowKind.weak),
            _arrow(0, 6, 1, 0, 2, 4, ArrowKind.weak),
            _arrow(0, 2, 4, 2, 0, 1, ArrowKind.weak),
            _arrow(2, 0, 1, 2, 2, 6, ArrowKind.weak),
            _arrow(2, 2, 6, 2, 8, 8, ArrowKind.weak),
            _arrow(2, 8, 8, 6, 4, 6, ArrowKind.weak),
            _arrow(6, 4, 6, 6, 1, 3, ArrowKind.weak),
          ],
          contradiction: [6, 8],
          eliminated: [
            [4, 4, 2],
          ],
        ),
        legend: _nishioLegend,
      ),
      TechniqueInfo(
        id: 'forcing_chain',
        name: '分类强制链',
        summary: '某格的每一个候选出发都能一路推出同一个结论，这个结论就必然成立。',
        definition: '分类强制链从某个格子的每一个候选分别出发，各自照常用唯一'
            '余数、区块排除往下推导，形成多条独立的推导路径。如果每一条路径'
            '（对应这个格子的每一个候选）最终都推出同一个格子填同一个数字，'
            '那么不管这个格子实际填的是哪个候选，这个共同的结论都会成立——'
            '因此可以直接把这个结论当作已经确定的填数或删除。',
        howToSpot: '挑一个候选不多的格子，让每个候选分别往下推导，'
            '看是否存在某个格子在所有推导路径里都只能填同一个数字。',
        walkthrough: '本例中 r4c2 候选 {6, 7}。假设它是 6：唯一余数推出 r6c2 '
            '是 7、r5c5 是 7、r5c9 是 6、r6c5 是 '
            '6，接着 r9c2 是 4、r1c4 是 4、r9c4 是 6。'
            '假设它是 7：同样推出 r6c2 是 6、r5c5 是 6、r5c9 '
            '是 7、r6c5 是 7，接着 r9c2 还是 4、r1c4 还是'
            ' 4、r9c4还是 6。两条路径都推出r9c2必须是 4，'
            '因此r9c2直接填 4，候选 6、7 都要删除。',
        caveats: '两条（或更多）路径必须各自独立地严格依据基础规则推导，'
            '不能相互借用对方的中间结论；共同结论必须是所有路径都推出的，'
            '只有部分路径推出不能算数。',
        rank: 654,
        examplePuzzle:
            '030050980000791000005800700304189500851204390209305008002508600000900000503010809',
        exampleMarkup: _chainMarkup(
          start: [3, 1],
          end: [8, 1],
          nodes: [
            [5, 1],
            [4, 4],
            [4, 8],
            [5, 4],
          ],
          arrows: [
            _arrow(3, 1, 6, 5, 1, 7, ArrowKind.weak),
            _arrow(3, 1, 7, 5, 1, 6, ArrowKind.weak),
            _arrow(5, 1, 7, 4, 4, 7, ArrowKind.weak),
            _arrow(5, 1, 6, 4, 4, 6, ArrowKind.weak),
            _arrow(4, 4, 7, 8, 1, 4, ArrowKind.weak),
            _arrow(4, 4, 6, 8, 1, 4, ArrowKind.weak),
          ],
          eliminated: [
            [8, 1, 6],
            [8, 1, 7],
            [0, 3, 6],
            [8, 3, 4],
          ],
        ),
        legend: _forcingLegend,
      ),
      TechniqueInfo(
        id: 'forcing_net',
        name: '分类强制网',
        summary: '某格三条（或更多）出路组成一张网，一起传播后仍推出同一个结论。',
        definition: '分类强制网是分类强制链的加强版：某个格子有三个（或更多）'
            '候选，为每一个候选分别展开推导网络，网络内部可以有多步唯一余数、区块'
            '排除交织。只要每一张网最终都汇出同一个格子填同一个数字，'
            '这个结论就和候选数目无关、必然成立，可以直接确定这个填数，'
            '其余候选随之删除。',
        howToSpot: '挑一个候选数偏多的格子，让每个候选分别展开推导，'
            '哪怕某条路径要走更多步，只要最终都能找到同一个格子只能填同一个数字'
            '即可。',
        walkthrough: '本例中r3c2候选 {1, 7, 9}。假设它是 1：唯一余数很快'
            '推出r3c9是 9、r2c8是 1、r3c1是 7，'
            '接着r5c3成为本行剩下候选 1 的唯一格，必须是 1。假设它是 7：'
            '推出r3c1是 9、r3c9是 1、r2c2是 1，'
            'r5c3同样只能填 1。假设它是 9：推出r3c1是 7、'
            'r3c9是 1、r2c2是 1、r4c8是 1，'
            'r5c3仍然只能填 1。三条网络都汇到r5c3必须是 1，'
            '因此直接填 1，候选 5、7、8 都要删除。',
        caveats: '每一张网都要各自独立推导，中间步骤多也没关系，但不能跳过依据；'
            '必须所有候选对应的网络都汇出同一个结论，只要有一条网络推出不同结果，'
            '整条分类强制网就不成立。',
        rank: 801,
        examplePuzzle:
            '024610007006070402003824560000200800300060024002001000069002100240130600130006240',
        exampleMarkup: _chainMarkup(
          start: [2, 1],
          end: [4, 2],
          nodes: [
            [2, 8],
            [2, 0],
            [1, 1],
          ],
          arrows: [
            _arrow(2, 1, 1, 4, 2, 1, ArrowKind.weak),
            _arrow(2, 1, 7, 4, 2, 1, ArrowKind.weak),
            _arrow(2, 1, 9, 4, 2, 1, ArrowKind.weak),
          ],
          eliminated: [
            [4, 2, 5],
            [4, 2, 7],
            [4, 2, 8],
          ],
        ),
        legend: _forcingLegend,
      ),
      TechniqueInfo(
        id: 'template_delete',
        name: '图案叠加删数',
        summary: '枚举单个数字在盘面上所有合法的 9 格落位图案，不出现在任何图案中的候选数直接删除。',
        definition: '图案叠加删数（Template Delete）与图案叠加填数（Template Set）合称图案叠加（Templates）：'
            '对于某一个确定的数字 d，它在 9×9 盘面上的最终解必然构成每行、每列、每宫各占一格的 9 格落位图案（互不攻击的九车图案）。'
            '结合盘面已填数字和剩余候选格，将数字 d 当前仍合法的所有 9 格图案全部枚举并叠加在一起：'
            '若某个候选格在所有合法图案中都从不出现（出现次数为 0），则该格绝不可能填入 d，可直接删去（图案叠加删数）；'
            '若某个候选格在所有合法图案中百分之百出现，则该格可直接填入 d（图案叠加填数）。',
        howToSpot: '当某个数字剩余候选位置较少但常规鱼类难以直接看出时，按逐行每宫各取一格的方式尝试铺放该数字，找出永远无法凑齐 9 格的孤立候选点。',
        walkthrough: '本例观察数字 4 在盘面上的全部合法 9 格落位图案：将所有合法图案叠加后，'
            '发现 r8c9 虽然表面上仍有候选 4，但一旦在 r8c9 填入 4，其余行与宫就无法同时各放置一个 4；'
            '即 4r8c9 在所有合法图案中均不出现，因此可直接删去 r8c9 的候选 4。',
        caveats: '图案叠加本质是对单数字落点的穷举交集/并集检验，实战中通常作为高阶鱼类与单数字链的兜底验证手段。',
        rank: 753,
        examplePuzzle:
            '098061300361009008007384090980010700136078520702000810013847900870690030009100087',
        exampleMarkup: BoardMarkup(
          cellColors: {
            _ck(3, 2): TeachingColors.start,
            _ck(7, 2): TeachingColors.start,
            _ck(3, 7): TeachingColors.node,
            _ck(3, 8): TeachingColors.node,
            _ck(4, 8): TeachingColors.node,
            _ck(5, 8): TeachingColors.node,
            _ck(7, 8): TeachingColors.elimCell,
          },
          candidateColors: {
            _cr(7, 8, 4): TeachingColors.elimCand,
          },
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'als_xz_double',
        name: '双强链待定数组',
        summary: '两个待定数组同时拥有两个限制公共候选，形成零秩闭环，锁定各自内部候选并向外大范围删数。',
        definition: '双强链待定数组（Doubly Linked ALS-XZ）是待定数组（ALS-XZ）的强力升级形态：'
            '当两个互不重叠的待定数组 A 与 B 之间同时存在两个限制公共候选 X1 与 X2（即两边的 X1 格彼此全可见，两边的 X2 格也彼此全可见）时，'
            'X1 与 X2 不可能同时落在同一个 ALS 内（否则另一个 ALS 将同时失去两个候选名额而出现格数大于候选数的矛盾）。'
            '因此 X1 与 X2 必然一边分一个，从而使 A 与 B 剩下的所有非公共候选都变成各自 ALS 内部的锁定真数！'
            '这带来两类强力删数：① 盘面外同时看见 A、B 所有 X1（或 X2）的格可删去 X1（或 X2）；'
            '② 盘面外只要同时看见 A 内部某非 RCC 数字的所有格（无需再看 B），即可直接删去该数字（对 B 同理）。',
        howToSpot: '在寻找 ALS-XZ 时，若发现两个 ALS 的公共候选里有不止一个数字满足“两边所有同名候选互相可见”，立即检查双强链待定数组。',
        walkthrough: '本例中 r1c4 构成候选 {3, 8} 的 ALS A，c4 上的其余格构成 ALS B，两边同时以两个公共候选形成双向受限锁定，'
            '不仅能删去两侧公共受限候选共同可见格的候选，还能直接将各自 ALS 内的剩余候选当作锁定数组向外删数（如删去 3r2c5）。',
        caveats: '必须确认两个限制公共候选 X1、X2 各自都满足“A 中所有该数与 B 中所有该数两两互相可见”，缺一不可。',
        rank: 656,
        examplePuzzle:
            '076049200901000004243005896030591002102084300400203001300000007000907008010408020',
        exampleMarkup: _alsMarkup(
          alsA: [
            [0, 3],
          ],
          alsB: [
            [1, 3],
            [2, 3],
            [4, 3],
            [6, 3],
          ],
          arrows: [
            _arrow(0, 3, 8, 1, 3, 8, ArrowKind.strong),
            _arrow(0, 3, 3, 1, 3, 3, ArrowKind.strong),
          ],
          eliminated: [
            [1, 4, 3],
          ],
        ),
        legend: _alsLegend,
      ),
      TechniqueInfo(
        id: 'als_w_wing',
        name: '待定数组・W-Wing',
        summary: '两个共享候选 X 与 Z 的待定数组通过外部一条 X 的共轭强链桥接，删去两侧 Z 的共同可见格。',
        definition: '待定数组・W-Wing（ALS W-Wing）是将 W-Wing 中的两个双值格推广为两个待定数组（ALS）：'
            '设有两个互不重叠的待定数组 A 与 B，它们都含有候选数 X 与 Z；'
            '虽然 A 与 B 中的 X 不能直接互相看见（不构成直接 RCC），但盘面上存在一条关于数字 X 的共轭强链（e1 = e2），'
            '其中一端 e1 能看见 A 中所有的 X，另一端 e2 能看见 B 中所有的 X。'
            '由于强链两端 e1、e2 必有一真，A 与 B 中的 X 至少有一侧会被全部排除，被迫变成锁定集并填入 Z；'
            '因此 Z 至少会在 A 或 B 的某一侧为真，同时看见 A 与 B 中所有 Z 的外部单元格即可删去候选 Z。',
        howToSpot: '找两个都含候选 X 和 Z 的 ALS（比如一个双值格和一个三值兩格 ALS），再用数字 X 的一条同行/列/宫共轭强链把它们两端连起来。',
        walkthrough: '本例中 ALS A 与 ALS B 均含有候选 4 与 7，数字 7 在 r6 上的共轭强链 7r6c6 = 7r6c9 两端分别看见两侧 ALS 中的所有 7，'
            '构成待定数组・W-Wing，从而逼出至少一侧必含 4，删去同时看见两侧所有 4 的 r4c4、r4c5、r4c6 中的候选 4。',
        caveats: '强链的一端必须看见对应 ALS 内“全部”含 X 的格子，若有哪怕一格看不见，就无法把该侧 ALS 的 X 完全排空。',
        rank: 655,
        examplePuzzle:
            '630000275821975643547362981052000096018690532960520810170856029285039160096200058',
        exampleMarkup: _alsMarkup(
          alsA: [
            [4, 5],
          ],
          alsB: [
            [3, 6],
            [3, 3],
          ],
          pivot: [
            [5, 5],
            [5, 8],
          ],
          arrows: [
            _arrow(4, 5, 7, 5, 5, 7, ArrowKind.weak),
            _arrow(5, 5, 7, 5, 8, 7, ArrowKind.strong),
            _arrow(5, 8, 7, 3, 6, 7, ArrowKind.weak),
          ],
          eliminated: [
            [3, 4, 4],
            [3, 5, 4],
          ],
        ),
        legend: _alsLegend,
      ),
      TechniqueInfo(
        id: 'region_forcing_chain',
        name: '区域强制链',
        summary: '某区域内某数字仅有两三个候选位置，从每个位置出发分别推导均得出同一结论，则该结论必成立。',
        definition: '区域强制链（Region Forcing Chain）与按格分类的分类强制链（Cell Forcing Chain）互为对偶：'
            '选定某一行、某一列或某一宫，其中数字 d 只剩下 2 个（或 3 个）候选格可填。'
            '由于该区域内必然有一格填入 d，我们从这几个候选位置分别出发，用唯一余数、排除等基础逻辑独立往下推导；'
            '如果每一个分支最终都推出同一个单元格填入同一个数字（或同一个候选被排除），那么不管 d 最终落在该区域的哪一格，该公共结论都必然成立。',
        howToSpot: '寻找某行、列或宫内只剩 2~3 个位置的数字 d，分别假设 d 填在这些位置上，观察各分支是否汇合到同一个填数或删数结论。',
        walkthrough: '本例观察 c2 中数字 6 的候选位置，仅能落在 r4c2 与 r6c2 两格。'
            '分支一：假设 r4c2 填 6，顺着唯一余数推导可得 r9c2 填 4；'
            '分支二：假设 r6c2 填 6，顺着唯一余数推导同样可得 r9c2 填 4。'
            '两个区域分支汇合于同一结论，因此 r9c2 必填入 4（删去其余候选 6、7）。',
        caveats: '必须把该区域内数字 d 的所有候选位置全部纳入分支，漏掉任何一个可能位置都会导致推理不完备。',
        rank: 754,
        examplePuzzle:
            '030050980000791000005800700304189500851204390209305008002508600000900000503010800',
        exampleMarkup: _chainMarkup(
          start: [3, 1],
          end: [8, 1],
          nodes: [
            [5, 1],
            [4, 4],
          ],
          arrows: [
            _arrow(3, 1, 6, 5, 1, 7, ArrowKind.weak),
            _arrow(5, 1, 7, 4, 4, 7, ArrowKind.weak),
            _arrow(4, 4, 7, 8, 1, 4, ArrowKind.weak),
            _arrow(5, 1, 6, 4, 4, 6, ArrowKind.weak),
            _arrow(4, 4, 6, 8, 1, 4, ArrowKind.weak),
          ],
          eliminated: [
            [8, 1, 6],
            [8, 1, 7],
          ],
        ),
        legend: _forcingLegend,
      ),
    ];
