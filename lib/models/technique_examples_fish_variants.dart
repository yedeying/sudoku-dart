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
        name: '刺身鱼',
        summary: '带鳍鱼再缺一个覆盖顶点，去鳍后鱼就散了。',
        definition: '刺身鱼（Sashimi Fish）是带鳍鱼的退化版：把鳍去掉以后，某条基线'
            '在覆盖线上只剩一个候选，鱼本身已经不是完整的 X-Wing 或 Swordfish 了。'
            '道理和带鳍鱼完全一样——鳍为假时鱼成立，鳍为真时鳍看得见的地方也塌，'
            '所以两种情况都删得掉的，正是同时看得见鳍和覆盖线的那些候选。'
            '区别只在于「去鳍以后还算不算一条完整的鱼」。'
            '刺身 X-Wing 的删除和摩天楼相同，提示会先报摩天楼；'
            '单独作为刺身提示的，是 Swordfish、Jellyfish 这两档。',
        howToSpot: '按带鳍鱼扫，但允许某条基线在覆盖线上只占一个顶点；'
            '再看多出来的那个候选，是不是和空掉的覆盖顶点落在同一个宫里。',
        walkthrough: '本例观察数字 3，基线取 r2、r6、r7，覆盖列取 c3、c7、c9。'
            'r6 的 3 落在 c7、c9，r7 的 3 也落在 c7、c9，两条都规规矩矩踩在覆盖上；'
            'r2 却只在 c3 上有一个 3，另外多出一个 3r2c8——'
            'r2c7 和 r2c9 这两个覆盖顶点是空的。'
            '去掉 3r2c8 这个鳍，r2 在覆盖里只剩一个顶点，Swordfish 就撑不起来了，'
            '这才叫刺身，而不是普通带鳍。\n'
            '鳍 3r2c8 和空掉的 r2c7、r2c9 同在右上宫，'
            '所以能删的只有这个宫里、又踩在覆盖列上的 3：3r1c7 和 3r1c9。'
            '同宫的 3r1c8 不在任何覆盖列上，删不着。',
        caveats: '刺身 X-Wing 的删除常常和摩天楼完全一样，不要为了区分名称而重复提示。'
            '本例特意取了刺身 Swordfish，两条删除凑不出任何一条同数字多宝鱼的删除超集，'
            '区块摒除也删不到这些候选。'
            '正因为如此，刺身在 Swordfish、Jellyfish 规格上才有独立价值。',
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
        name: '双生鱼',
        summary: '同一条鱼身配两套覆盖，等于连报两次。',
        definition: '双生鱼（Siamese Fish）指两条同型的带鳍或刺身鱼叠在一起：'
            '基线完全一样，覆盖线差一条，于是各自多出来的那个候选当鳍，'
            '配出两套不同的删除。有的软件会把两套覆盖合成一条展示，'
            '求解上并没有新步骤：先按第一套覆盖做一次，再按第二套做一次，结果相同。'
            '最简单的双生刺身 X-Wing 甚至就等于摩天楼。',
        howToSpot: '找到一条带鳍鱼之后，接着数基线上的候选一共覆盖几列（几行）。'
            '如果比基线条数正好多一条，那么每去掉一列都得到一条鱼，两条共用同一块鱼身。',
        walkthrough: '本例观察数字 6，基线是 r1 和 r9。r1 的 6 落在 c5、c8，'
            'r9 的 6 落在 c5、c9——两条基线一共覆盖 c5、c8、c9 三列，'
            '比基线条数多一条，正是双生的入口。\n'
            '取覆盖 c5、c9：r1 在覆盖里只剩 c5 一个顶点，6r1c8 成了鳍，'
            'r1c9 那个覆盖顶点是空的。鳍和空顶点同在右上宫，'
            '所以删这个宫里踩在 c9 上的 6：6r2c9 和 6r3c9。\n'
            '换成覆盖 c5、c8：这回轮到 r9 只剩 c5 一个顶点，6r9c9 成了鳍，'
            'r9c8 空着。鳍和空顶点同在右下宫，删的是 6r8c8。\n'
            '两条鱼共用 r1、r9 这块鱼身，鳍一个在上一个在下，删出来的是两组不同的候选，'
            '这就是双生。',
        caveats: '双生只是展示上的合并，别当成比单条带鳍鱼更强的技巧；'
            '两个鳍要各自检查同宫条件，不能混着用。'
            '本例这两条刺身 X-Wing 的删除都能被同数字的某条多宝鱼包住，'
            '也就是说单看删除，它们并没有超出摩天楼。',
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
        name: 'Mutant 鱼',
        summary: '基线和覆盖都可以混行、列、宫。',
        definition: 'Mutant 鱼比 Franken 鱼更自由：基线集合和覆盖集合都可以同时混用行、列、宫，'
            '只要基线两两不共格、基线上的候选全被覆盖集合覆盖，'
            '覆盖里鱼身之外的同名候选就能删。'
            '道理和普通鱼一字不差：基线条数个落点要分进同样条数的覆盖线，'
            '每条覆盖正好分到一个，所以覆盖上多出来的候选没有位置可待。'
            '难处不在道理，而在于基线和覆盖该取哪些区域，没有形状上的线索，'
            '只能枚举全部行、列、宫的组合。',
        howToSpot: '先看普通鱼和 Franken 鱼；只有行、列、宫混用才能覆盖时，才考虑 Mutant。'
            '这一步只能枚举区域组合，没有更简便的识别方法。',
        walkthrough: '本例观察数字 9，基线取一行一列：r6 和 c2。'
            'r6 的 9 落在 c3、c8、c9，c2 的 9 落在 r4、r5；'
            '两条基线交在 r6c2，而那一格是已知数 3，所以基线不共格。\n'
            '覆盖取两个宫：左中宫和右中宫。r6c3 和 c2 上的两个 9 都在左中宫里，'
            'r6c8、r6c9 都在右中宫里，五个候选一个不漏地被两个宫覆盖。'
            '基线两条、覆盖两条，条数相同，鱼成立。\n'
            '于是这两个宫里鱼身之外的 9 就没位置了——右中宫的 9r4c8 可以删掉。'
            '基线一行一列、覆盖两个宫，行、列、宫全用上了，这正是 Mutant 的样子。',
        caveats: '当前提示只包含 Franken 鱼（一线加一宫、覆盖恰好两条）。'
            'Mutant 鱼仅作教学说明：判定本身成立，但只能靠枚举区域组合，'
            '没有单独的识别方法，因此不纳入提示。',
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
