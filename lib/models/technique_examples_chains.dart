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
      for (final e in eliminated)
        _cr(e[0], e[1], e[2]): TeachingColors.elimCand,
    },
    arrows: arrows,
  );
}

/// Grouped AIC 专用：一端是单个格子（start，绿），另一端是一组格子（end，黄）。
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
      for (final e in eliminated)
        _cr(e[0], e[1], e[2]): TeachingColors.elimCand,
    },
    arrows: arrows,
  );
}

/// 链、ALS 与强制类技巧的十二个教学盘面。
///
/// XY-Chain、AIC、Nice Loop、Grouped AIC、ALS-XZ、ALS-XY-Wing 都是用脚本在
/// 候选图上做强弱交替深搜，从真实题库（expert/hard/medium/easy）里挖出的
/// 真实链条，逐格核对候选、强弱链归属单元（同格 / 同行 / 同列 / 同宫）与
/// 删除目标的可见关系。Sue de Coq、Death Blossom、Kraken Fish 同样用脚本在
/// 真实题库的候选表里找到满足结构定义的交集/花瓣/带缺口的鱼，并逐条验证
/// 强链、ALS、限制公共数的可见关系。Nishio、Forcing Chain、Forcing Net 用
/// 单数排除的传播引擎在真实题库上跑出假设后的连锁填数，Nishio 一路推到
/// 某格无候选可填的矛盾，Forcing Chain/Net 则确认同一格的两三条出路都推出
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
        name: 'AIC 开链',
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
        walkthrough: '本例中数字 2 在r7c6与r2c6因c6只剩这两格'
            '能填 2 构成强链，r2c6再与r2c4因同一行还有别的候选 2 '
            '构成弱链，r2c4又与r9c4因c4只剩这两格能填 2 构成'
            '强链，r9c4最终再通过同宫的弱链绕回r7c6，形成一个环。'
            '取「强-弱-强」这一段子链，两端r7c6与r9c4至少有一个'
            '是 2，因此同时看到这两端的 r9c5 不可能是 2，删除该处候选 2。\n'
            '2r7c6 = 2r2c6 - 2r2c4 = 2r9c4 - 2r7c6',
        caveats: '环上每一条连接都要单独核实是强链还是弱链，不能想当然认为绕回去'
            '就一定成立；用来删除的子链两端仍必须都由强链连入，弱链收尾不能直接删。',
        rank: 604,
        examplePuzzle:
            '020900000048000031000063020009407003003080200400105600030570000250000180000006050',
        exampleMarkup: _chainMarkup(
          start: [6, 5],
          end: [8, 3],
          nodes: [
            [1, 5],
            [1, 3],
          ],
          arrows: [
            _arrow(6, 5, 2, 1, 5, 2, ArrowKind.strong),
            _arrow(1, 5, 2, 1, 3, 2, ArrowKind.weak),
            _arrow(1, 3, 2, 8, 3, 2, ArrowKind.strong),
            _arrow(8, 3, 2, 6, 5, 2, ArrowKind.weak),
          ],
          eliminated: [
            [8, 4, 2],
          ],
        ),
        legend: _chainLegend,
      ),
      TechniqueInfo(
        id: 'grouped_aic',
        name: 'Grouped AIC',
        summary: '链的一个节点可以是同宫里的一组格子，配合另一端单格构成强链再删除。',
        definition: 'Grouped AIC 里链上的节点不必是单独一格，可以是同一个宫、同一行或'
            '同一列里的一组格子——只要这组格子恰好都在同一个宫内，就可以把它们当成'
            '一个整体节点参与强链。例如某个数字在一列上只剩三格能填，其中两格恰好同'
            '在一个宫内，就可以把这两格捆成一个组，和列上第三格构成强链：组和第三格'
            '至少有一个是这个数字。凡是能同时看到「组的所在宫」和「第三格」的格子，'
            '这个数字都不可能出现，可以删除。',
        howToSpot: '先找一个数字在某条线上恰好剩三格的候选，看是否有两格恰好同宫，'
            '把这两格捆成一组，再看是否有格子同时能看到这个组所在的宫和线上剩下的'
            '那一格。',
        walkthrough: '本例中数字 2 在c2上只剩r7,r8,r9c2能填，其中r8'
            'c2与r9c2同在左下宫，捆成一组；r7c2则单独构成'
            '另一个节点。列上只剩这三格能填 2，所以「这一组」和「r7c2」'
            '至少有一个是 2。左下宫里r7,r8,r9c1都能同时看到这个组（同宫）'
            '和 r7c2（r7c1 还同行），因此这三格都不可能是 2，'
            '删除这三处候选 2。\n'
            '{2r8c2, 2r9c2} = 2r7c2',
        caveats: '组内的格子必须真的同在一个宫里，不能跨宫勉强拼凑；删除目标要能同时'
            '看到组的整体（同宫即可，不必看到组内每一格分别所在的行列）和单独节点。',
        rank: 701,
        examplePuzzle:
            '302090000080000000407056000030007069040601050670400030000360501000000090000010706',
        exampleMarkup: _groupedMarkup(
          single: [6, 1],
          group: [
            [7, 1],
            [8, 1],
          ],
          arrows: [
            _arrow(6, 1, 2, 7, 1, 2, ArrowKind.strong),
            _arrow(6, 1, 2, 8, 1, 2, ArrowKind.strong),
          ],
          eliminated: [
            [6, 0, 2],
            [7, 0, 2],
            [8, 0, 2],
          ],
        ),
        legend: _groupedLegend,
      ),
      TechniqueInfo(
        id: 'als_xz',
        name: 'ALS-XZ',
        summary: '两个几乎锁定集靠限制公共数字 X 相连，再删两边都含的另一个数字 Z。',
        definition: '几乎锁定集（ALS）指同一行、列或宫里 N 个空格恰好只剩 N+1 个候选'
            '数字。ALS-XZ 用两个互不重叠的 ALS：如果它们共享数字 X，且 X 在两个 ALS '
            '里出现的格子彼此都能互相看到（限制公共候选），那么 X 最终只会落在其中'
            '一个 ALS 里——填了 X 的那个 ALS 会用掉一个候选名额，迫使另一个 ALS 里剩下'
            'N 个候选正好填满 N 个格子，成为「真正」的锁定集。如果两个 ALS 还共享'
            '另一个数字 Z，那么无论 X 落在哪个 ALS，Z 都必然会出现在某个 ALS 里，'
            '因此同时能看到两个 ALS 里所有 Z 候选的格子，Z 都不可能出现，可以删除。',
        howToSpot: '先在两个不重叠的区域各找一个几乎锁定集，看它们是否共享两个数字：'
            '一个作限制公共候选 X（两边的 X 格必须互相可见），另一个作 Z，'
            '再看谁能同时看到两个 ALS 里所有的 Z。',
        walkthrough: '本例中 r4c2, r4c3 组成候选 {1, 7, 9} 的 ALS A，r5c1、'
            'r5c2 与 r6c2 组成候选 {1, 6, 7, 8} 的 ALS B。两者共享候选 7 与 1：'
            'A 里唯一的候选 7 落在 r4c2，B 里唯一的候选 7 落在 r5c2，'
            '两格同列，互相可见，7 可以作限制公共候选 X。无论 7 最终填在 A 还是'
            'B，另一边都会成为真正的锁定集，候选 1 必然落在其中。因此同时看到 A、'
            'B 里所有候选 1 的r6c3不可能是 1，删除该处候选 1。',
        caveats: '两个 ALS 的格子不能重叠；限制公共候选 X 要求两边所有含 X 的格子'
            '互相可见，只是共享数字不满足这一条时不能当作 X，只能退回普通候选重合。',
        rank: 652,
        examplePuzzle:
            '703008000020570003090003070300806504005040000200000789040000067002050008907000300',
        exampleMarkup: _alsMarkup(
          alsA: [
            [3, 1],
            [3, 2],
          ],
          alsB: [
            [4, 0],
            [4, 1],
            [5, 1],
          ],
          arrows: [
            _arrow(3, 1, 7, 4, 1, 7, ArrowKind.strong),
            _arrow(3, 2, 1, 5, 2, 1, ArrowKind.weak),
            _arrow(5, 1, 1, 5, 2, 1, ArrowKind.weak),
          ],
          eliminated: [
            [5, 2, 1],
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
        howToSpot: '先找一个几乎锁定集当支点，看它是否能用两个不同的数字，各自和另'
            '一个几乎锁定集构成限制公共候选，再看这两个翼 ALS 是否还共享第三个数字。',
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
        name: 'Sue de Coq',
        summary: '宫与一行（或列）交接处的格子把数字拆成两堆，分别配给宫、行各自消化。',
        definition: 'Sue de Coq 发生在一个宫和一条线（行或列）的交叉处：交叉处有几个'
            '空格，候选数字总数比格数多至少 2 个。如果能把这些候选拆成两堆，'
            '一堆能在宫内（交叉处以外的宫内格子）找到一个几乎锁定集正好覆盖，'
            '另一堆能在线上（交叉处以外的线上格子）找到另一个几乎锁定集正好覆盖，'
            '那么交叉处的格子加上宫内那个 ALS 合起来正好用完第一堆数字，'
            '交叉处的格子加上线上那个 ALS 合起来正好用完第二堆数字——这意味着'
            '第一堆数字不会再出现在宫内其它格子里，第二堆数字也不会再出现在线上'
            '其它格子里，都可以删除。',
        howToSpot: '先找一个宫与一行（或列）的交叉处，数一数交叉格候选总数是否比'
            '格数多 2 个以上，再看能不能把候选拆成两堆，分别在宫内、线上找到正好'
            '覆盖的几乎锁定集。',
        walkthrough: '本例中r2c6与r3c6是中上宫与c6的交叉格，'
            '候选合起来是 {1, 2, 4, 9}。把 {2, 4} 分给宫：r2c4候选正好是 '
            '{2, 4}，覆盖这一堆；把 {1, 9} 分给列：r4c6候选正好是 {1, 9}，'
            '覆盖另一堆。因此候选 2、4 不会再出现在这个宫的其它格子里，r3c4 '
            '的候选 2、4 都要删除；候选 1、9 也不会再出现在 c6 的其它格子里，'
            'r5c6的候选 9、r8c6的候选 1 都要删除。',
        caveats: '两堆候选必须不重叠、合起来正好等于交叉格的全部候选；宫内、线上'
            '找到的几乎锁定集也不能占用交叉格本身，覆盖的候选要恰好和分到的那一堆'
            '完全一致。',
        rank: 603,
        examplePuzzle:
            '970306042805000109000050000207000304010020080400738001000905000000000000100847003',
        exampleMarkup: _alsMarkup(
          alsA: [
            [1, 3],
          ],
          alsB: [
            [3, 5],
          ],
          pivot: [
            [1, 5],
            [2, 5],
          ],
          eliminated: [
            [2, 3, 2],
            [2, 3, 4],
            [4, 5, 9],
            [7, 5, 1],
          ],
        ),
        legend: _alsLegend,
      ),
      TechniqueInfo(
        id: 'death_blossom',
        name: 'Death Blossom',
        summary: '一个格子的每个候选都各连到一个几乎锁定集，几个花瓣汇出同一个删除。',
        definition: 'Death Blossom（死亡花蕾）以一个「花心」格子出发：花心有几个候选'
            '数字，为其中每一个候选各找一个几乎锁定集（花瓣），要求花心能看到花瓣里'
            '所有含这个候选的格子。花心最终会填某一个候选，对应的花瓣就必须去掉这个候选'
            '排除掉，转而用完剩下的候选——如果所有花瓣（对应花心的每一个候选）在'
            '排除后都会共同挤出同一个数字 Z，那么无论花心最终填哪个候选，Z 都会'
            '落在某个花瓣里，因此同时能看到所有花瓣里 Z 候选的格子，Z 都不可能'
            '出现，可以删除。',
        howToSpot: '先找一个候选不算多的花心格子，为它的每个候选分别找一个能被花心'
            '看到的几乎锁定集，再看这些花瓣排除掉花心对应候选之后，是否都会挤出'
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
        summary: '一条带缺口的鱼（强链），缺口那一端接一条推导链，两端汇到同一个删除。',
        definition: 'Kraken Fish 是鱼类技巧和链的结合：某个数字在一行（或列）上只剩'
            '两格能填，构成一条强链。强链的一端能直接看到删除目标，另一端不能直接'
            '看到，但假设它成立之后，靠单元格排除、唯一余数一路推导下去，'
            '最终也能推出删除目标不能是这个数字。因为强链两端至少有一个为真，'
            '两条路径（一条直接看到、一条靠链推导）都指向同一个结论，所以这个'
            '结论必然成立，可以删除。',
        howToSpot: '先找一个数字在某条线上只剩两格能填的强链，看删除目标能不能被'
            '其中一端直接看到；如果只有一端能直接看到，就从另一端出发用唯一余数'
            '往下推，看是否也能推到同一个删除目标。',
        walkthrough: '本例中数字 2 在r7只剩c4和c9能填，构成强链。'
            '若r7c4是 2，它与r4c4同列，直接让r4c4'
            '不能是 2；若r7c9是 2，则r2c8成为r2剩下候选 2 '
            '的唯一格、必须是 2，接着r2c6成为剩下候选 9 的唯一格、必须是 '
            '9，最终r4c4成为r4剩下候选 6 的唯一格、必须是 6。两条路径'
            '都推出 r4c4 不能是 2，因此删除该处候选 2。',
        caveats: '强链必须是真正的强链（该数字恰好只剩两格）；靠链推导的一端每一步'
            '都要写清楚依据哪条唯一余数或哪个区域，不能跳步，否则结论不可靠。',
        rank: 751,
        examplePuzzle:
            '083020090000800100029300008000098700070000060006740000300006980002005000010030540',
        exampleMarkup: _forcingMarkup(
          assumption: [6, 8],
          path: [
            [6, 3],
            [1, 7],
            [1, 5],
          ],
          arrows: [
            _arrow(6, 3, 2, 3, 3, 2, ArrowKind.strong),
            _arrow(6, 8, 2, 1, 7, 2, ArrowKind.weak),
            _arrow(1, 7, 2, 1, 5, 9, ArrowKind.weak),
            _arrow(1, 5, 9, 3, 3, 6, ArrowKind.weak),
          ],
          eliminated: [
            [3, 3, 2],
          ],
        ),
        legend: _forcingLegend,
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
        walkthrough: '本例中r3c4候选 {3, 8}，假设它是 3。3 从c4排除后，'
            '陆续用唯一余数推出 r3c1 是 5、r7c8 是 6、r8c3 '
            '是 2，接着 r3c9 是 6、r7c9 是 7、r8c8 是 9，'
            '再推出r8c1是 1。这时r8已经填了 1、9，r8c3又'
            '填了 2，加上假设本身占掉列上的 3，r8c4原本候选 {1, 2, 3} 被'
            '连续排除后一个不剩，出现矛盾。因此最初的假设错误，r3c4的'
            '候选 3 必须删除，只能填 8。',
        caveats: '每一步推导都要依据真实的基础规则（唯一余数、区块排除等），'
            '不能凭空跳步；矛盾必须是「某格候选被排空」，只是推出一个不喜欢的结果'
            '不算矛盾。',
        rank: 553,
        examplePuzzle:
            '000600309306700010001004720900500000010000070000006001053900100070005804809007000',
        exampleMarkup: _forcingMarkup(
          assumption: [2, 3],
          path: [
            [2, 0],
            [6, 7],
            [7, 2],
            [2, 8],
            [6, 8],
            [7, 7],
            [7, 0],
          ],
          contradiction: [7, 3],
          eliminated: [
            [2, 3, 3],
          ],
        ),
        legend: _nishioLegend,
      ),
      TechniqueInfo(
        id: 'forcing_chain',
        name: 'Forcing Chain',
        summary: '某格的每一个候选出发都能一路推出同一个结论，这个结论就必然成立。',
        definition: 'Forcing Chain 从某个格子的每一个候选分别出发，各自照常用唯一'
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
        name: 'Forcing Net',
        summary: '某格三条（或更多）出路组成一张网，一起传播后仍推出同一个结论。',
        definition: 'Forcing Net 是 Forcing Chain 的加强版：某个格子有三个（或更多）'
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
            '整条 Forcing Net 就不成立。',
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
    ];
