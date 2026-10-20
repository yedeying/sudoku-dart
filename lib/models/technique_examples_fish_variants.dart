import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_catalog.dart';
import 'technique_examples_teaching_support.dart';
import 'technique_structure.dart';

const _finnedFishLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '基线格'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '鳍与缺掉的覆盖顶点'),
  TechniqueLegendItem(color: TeachingColors.elimCell, label: '结论落点'),
  TechniqueLegendItem(color: TeachingColors.node, label: '鱼身候选'),
  TechniqueLegendItem(color: TeachingColors.end, label: '鳍候选'),
];

const _mutantLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '行基线格'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '列基线格'),
  TechniqueLegendItem(color: TeachingColors.elimCell, label: '结论落点'),
  TechniqueLegendItem(color: TeachingColors.node, label: '基线候选'),
];

const _turbotLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '链上四格'),
  TechniqueLegendItem(color: TeachingColors.elimCell, label: '结论落点'),
  TechniqueLegendItem(color: TeachingColors.node, label: '链中间的两个节点'),
  TechniqueLegendItem(color: TeachingColors.end, label: '链两端'),
];

/// 鱼类里还没有独立报法的四条：多宝鱼、刺身鱼、双生鱼、Mutant 鱼。
///
/// 四个盘面都是从随机完整解挖出来的唯一解题目，再用脚本按各自的几何条件筛出来，
/// 而且都过了同一道门槛：删除结论不能是区块摒除顺手就删得到的，
/// 免得图画得热闹、删的却是初学第三课的东西。
/// 每条的基线、覆盖、鳍、缺掉的覆盖顶点、算出来的删除都写进了
/// [TechniqueInfo.structure]，由 `teaching_structure_test` 拿盘面重算一遍再逐条对齐。
List<TechniqueInfo> fishVariantTechniqueExamples() => [
      TechniqueInfo(
        id: 'turbot',
        name: '多宝鱼',
        summary: '同数字强-弱-强，两端共同可见处可删。',
        definition: '多宝鱼（Turbot Fish）是只用一个数字的最短交替推理链：一条强链、'
            '一条弱链、再一条强链，三段接成一串。两条强链的远端不可能同时为假，'
            '所以同时看得见这两个远端的格子里，这个数字可以删掉。'
            '摩天楼、双线风筝、空矩形都是它的固定几何写法——强链一横一竖、'
            '或者其中一段落在宫里——本质上是同一招。',
        howToSpot: '锁定一个数字，先找该数字在某个区域里只剩两个候选的强链，'
            '再看强链的一端能不能顺着同区域的弱链，接上另一条同数字强链。'
            '强链的区域不限于行和列，宫里只剩两个候选时同样算。',
        walkthrough: '本例观察数字 4。r6 里 4 只落在 c2 和 c8，是一条强链；'
            'b9 里 4 只落在 r8c8 和 r9c8，也是一条强链。'
            '中间的 4r6c8 与 4r8c8 同在 c8，构成弱链，'
            '于是串成 4r6c2 = 4r6c8 − 4r8c8 = 4r9c8。'
            '两端 4r6c2 与 4r9c8 不可能同时为假，'
            '而 r9c2 同时看得见这两格（同 c2、同 r9），所以 4r9c2 可以删掉。',
        caveats: '本例的三段走的是「行强链—列弱链—宫强链」，'
            '既不是摩天楼（两条同向线强链）也不是双线风筝（一行一列在宫里拐弯），'
            '空矩形要求宫里的候选摆成一行加一列的十字，这里 b9 的两个 4 同在 c8，'
            '也对不上。把四个节点能构成的行、列、宫组合都核对一遍，'
            '没有一种读法落回这三个已命名特例。\n'
            '代价是：b9 的 4 既然锁在 c8 上，区块摒除也能同时删掉 c8 上宫外的 4，'
            '其中就包括链上的 4r6c8。不带成组节点的一般多宝鱼几乎总是这样'
            '——真正只有它做得到的收获，要到节点是一组格子的 Grouped Turbot 才出得来。',
        rank: 301,
        examplePuzzle:
            '000096504000423067600010020002000000700040001301005702090034076070000200000170309',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [5, 1],
            [5, 7],
            [7, 7],
            [8, 7],
          ],
          targets: const [
            [8, 1],
          ],
          nodes: const [
            [5, 7, 4],
            [7, 7, 4],
          ],
          keys: const [
            [5, 1, 4],
            [8, 7, 4],
          ],
          strongLinks: const [
            [5, 1, 5, 7, 4],
            [7, 7, 8, 7, 4],
          ],
          weakLinks: const [
            [5, 7, 7, 7, 4],
          ],
        ),
        legend: _turbotLegend,
        structure: const TeachingStructure(
          family: TeachingFamily.turbot,
          claim: TeachingClaim.elimination,
          fishDigit: 4,
          chain: [
            ChainSegment(
              from: CandidateRef(5, 1, 4),
              to: CandidateRef(5, 7, 4),
              strong: true,
              house: 5,
            ),
            ChainSegment(
              from: CandidateRef(5, 7, 4),
              to: CandidateRef(7, 7, 4),
              strong: false,
              house: 16,
            ),
            ChainSegment(
              from: CandidateRef(7, 7, 4),
              to: CandidateRef(8, 7, 4),
              strong: true,
              house: 26,
            ),
          ],
          generalizedTurbot: true,
          beyondLocked: true,
          conclusionFalse: [CandidateRef(8, 1, 4)],
        ),
      ),
      TechniqueInfo(
        id: 'sashimi',
        name: '退化鱼',
        summary: '鳍鱼中某条定义域在删除域上只剩一个交点，去掉鱼鳍后鱼结构退化。',
        definition: '退化鱼（Sashimi Fish，又称刺身鱼）是鳍鱼的退化形态：将鱼鳍去掉后，某条定义域'
            '在删除域上仅剩一个候选数，鱼本体已不足以构成完整的非退化鱼。'
            '删数原理与普通鳍鱼完全一致——鱼鳍为假时鱼结构成立，鱼鳍为真时其可见格直接排除，'
            '因此两种情况都能删去的正是同时看见鱼鳍且位于删除域上的同数字候选数。'
            '退化 X-Wing 的删数效果与摩天楼相同，提示会优先报出摩天楼；'
            '单独作为退化鱼报出的主要是三阶（Swordfish）与四阶（Jellyfish）规格。',
        howToSpot: '按鳍鱼观察定义域与删除域，但允许某条定义域在删除域上仅占一个交点；'
            '再确认多出的鱼鳍与空缺的删除域交点位于同一个宫内。',
        walkthrough: '本例观察数字 3，定义域取 r2、r6、r7，删除域取 c3、c7、c9。'
            'r6 与 r7 的 3 均落在 c7、c9；'
            'r2 在删除域上仅剩 r2c3 一个候选数，另多出鱼鳍 3r2c8——'
            'r2c7 与 r2c9 两个删除域交点为空。'
            '若去掉鱼鳍 3r2c8，r2 在删除域内只剩一个交点，三阶鱼随之退化，因此属于退化鱼。\n'
            '鱼鳍 3r2c8 与空缺的 r2c7、r2c9 同在 b3，'
            '因此可删去 b3 内位于删除域列上的 3：3r1c7 与 3r1c9。',
        caveats: '退化 X-Wing 的删数往往与摩天楼或双线风筝等价；'
            '本例取三阶退化 Swordfish，其删数无法由单条多宝鱼或区块排除直接得出。',
        rank: 380,
        examplePuzzle:
            '908007000000208704000350000807532000230019080000080050100004090300060870700000001',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [1, 2],
            [5, 6],
            [5, 8],
            [6, 6],
            [6, 8],
          ],
          cover: const [
            [1, 6],
            [1, 7],
            [1, 8],
          ],
          targets: const [
            [0, 6],
            [0, 8],
          ],
          nodes: const [
            [1, 2, 3],
            [5, 6, 3],
            [5, 8, 3],
            [6, 6, 3],
            [6, 8, 3],
          ],
          keys: const [
            [1, 7, 3],
          ],
          weakLinks: const [
            [1, 7, 1, 2, 3],
            [5, 6, 6, 6, 3],
            [5, 8, 6, 8, 3],
          ],
        ),
        legend: _finnedFishLegend,
        structure: const TeachingStructure(
          family: TeachingFamily.fish,
          claim: TeachingClaim.elimination,
          fishes: [
            FishSpec(
              digit: 3,
              baseHouses: [FishHouse.r(1), FishHouse.r(5), FishHouse.r(6)],
              coverHouses: [FishHouse.c(2), FishHouse.c(6), FishHouse.c(8)],
              fins: [CandidateRef(1, 7, 3)],
              coverDeficits: [CellRef(1, 6), CellRef(1, 8)],
              eliminations: [CandidateRef(0, 6, 3), CandidateRef(0, 8, 3)],
              sashimi: true,
              beyondTurbot: true,
              beyondLocked: true,
            ),
          ],
          conclusionFalse: [CandidateRef(0, 6, 3), CandidateRef(0, 8, 3)],
        ),
      ),
      TechniqueInfo(
        id: 'siamese_fish',
        name: '孪生鱼',
        summary: '共用同一定义域的两条鳍鱼或退化鱼叠加，同时产生两组删数。',
        definition: '孪生鱼（Siamese Fish，又称双生鱼）指两条同阶的鳍鱼或退化鱼叠加在一起：'
            '定义域完全相同，删除域相差一条线，各自将多出的候选数作为鱼鳍，'
            '从而分别导出两组不同的删数。本质上它等于对同一定义域连用两次鳍鱼推理。',
        howToSpot: '找到一条鳍鱼后，检查定义域上的候选数一共分布在几列（或几行）。'
            '若比定义域条数多出一条，且分别去掉其中一列都能构成合法的鳍鱼或退化鱼，即为孪生鱼。',
        walkthrough: '本例观察数字 6，定义域取 r1 与 r9。r1 的 6 落在 c5、c8，'
            'r9 的 6 落在 c5、c9——两条定义域共涉及 c5、c8、c9 三列。\n'
            '第一套删除域取 c5、c9：6r1c8 作为鱼鳍，与空缺交点 r1c9 同在 b3，'
            '可删去 b3 内位于 c9 上的 6r2c9 与 6r3c9。\n'
            '第二套删除域取 c5、c8：6r9c9 作为鱼鳍，与空缺交点 r9c8 同在 b9，'
            '可删去 6r8c8。\n'
            '两条退化鱼共用 r1、r9 定义域，合并展示了两组不同的删数，即为孪生鱼。',
        caveats: '孪生鱼是两条同定义域鳍鱼的合并展示；两条鱼各自的鱼鳍与删除域必须分别满足同宫条件，不可混用。',
        rank: 401,
        examplePuzzle:
            '018200704000080000700000800009376052002000380500840610600000070004037500007500040',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [0, 4],
            [8, 4],
          ],
          cover: const [
            [0, 7],
            [0, 8],
            [8, 7],
            [8, 8],
          ],
          targets: const [
            [1, 8],
            [2, 8],
            [7, 7],
          ],
          nodes: const [
            [0, 4, 6],
            [8, 4, 6],
          ],
          keys: const [
            [0, 7, 6],
            [8, 8, 6],
          ],
          weakLinks: const [
            [0, 4, 8, 4, 6],
            [0, 4, 0, 7, 6],
            [8, 4, 8, 8, 6],
          ],
        ),
        legend: _finnedFishLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.siameseFish,
          claim: TeachingClaim.elimination,
          fishes: [
            FishSpec(
              digit: 6,
              baseHouses: [FishHouse.r(0), FishHouse.r(8)],
              coverHouses: [FishHouse.c(4), FishHouse.c(8)],
              fins: [CandidateRef(0, 7, 6)],
              coverDeficits: [CellRef(0, 8)],
              eliminations: [CandidateRef(1, 8, 6), CandidateRef(2, 8, 6)],
              sashimi: true,
              beyondLocked: true,
            ),
            FishSpec(
              digit: 6,
              baseHouses: [FishHouse.r(0), FishHouse.r(8)],
              coverHouses: [FishHouse.c(4), FishHouse.c(7)],
              fins: [CandidateRef(8, 8, 6)],
              coverDeficits: [CellRef(8, 7)],
              eliminations: [CandidateRef(7, 7, 6)],
              sashimi: true,
              beyondLocked: true,
            ),
          ],
          conclusionFalse: [
            CandidateRef(1, 8, 6),
            CandidateRef(2, 8, 6),
            CandidateRef(7, 7, 6),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'mutant_fish',
        name: '交叉鱼',
        summary: '定义域与删除域均可混用行、列、宫的广义鱼结构。',
        definition: '交叉鱼（Mutant Fish）比宫内鱼（Franken Fish）更加自由：定义域集合与删除域集合都可以同时混用行、列、宫，'
            '只要各定义域两两不共享鱼身候选格，且定义域内的全部目标候选数均被同阶数量的删除域覆盖，'
            '那么删除域中鱼身以外的同数字候选数即可删去。',
        howToSpot: '先排查标准鱼与宫内鱼；当只有行、列、宫同时混用才能使定义域与删除域数量相等时，即构成交叉鱼。',
        walkthrough: '本例观察数字 9，定义域取一行一列：r6 与 c2。'
            'r6 的 9 落在 c3、c8、c9，c2 的 9 落在 r4、r5；'
            '两条定义域交点 r6c2 为已知数 3，互不共格。\n'
            '删除域取两个宫：b4 与 b6。r6c3 与 c2 上的两个 9 均位于 b4，'
            'r6c8、r6c9 均位于 b6，五个鱼身候选数被两个删除域宫完全覆盖。\n'
            '因此这两个宫内鱼身以外的 9r4c8 可以删去。'
            '定义域同时使用行与列、删除域使用宫，正是交叉鱼的典型形态。',
        caveats: '当前求解器已内置宫内鱼扫描；交叉鱼因区域组合无固定方向约束，作为高阶理论教学展示。',
        rank: 800,
        examplePuzzle:
            '900504600506008020000000915005086201108000054020315000001009000040850060870040000',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [5, 2],
            [5, 7],
            [5, 8],
          ],
          cover: const [
            [3, 1],
            [4, 1],
          ],
          targets: const [
            [3, 7],
          ],
          nodes: const [
            [5, 2, 9],
            [5, 7, 9],
            [5, 8, 9],
            [3, 1, 9],
            [4, 1, 9],
          ],
          weakLinks: const [
            [5, 2, 5, 7, 9],
            [5, 7, 5, 8, 9],
            [3, 1, 4, 1, 9],
          ],
        ),
        legend: _mutantLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.fish,
          claim: TeachingClaim.elimination,
          fishes: [
            FishSpec(
              digit: 9,
              baseHouses: [FishHouse.r(5), FishHouse.c(1)],
              coverHouses: [FishHouse.b(3), FishHouse.b(5)],
              eliminations: [CandidateRef(3, 7, 9)],
              mutant: true,
              beyondTurbot: true,
              beyondLocked: true,
            ),
          ],
          conclusionFalse: [CandidateRef(3, 7, 9)],
        ),
      ),
    ];
