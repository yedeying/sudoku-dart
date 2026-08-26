import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_catalog.dart';
import 'technique_examples_teaching_support.dart';
import 'technique_structure.dart';

const _cannibalLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '行基线格'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '宫基线格'),
  TechniqueLegendItem(color: TeachingColors.elimCell, label: '结论落点'),
  TechniqueLegendItem(color: TeachingColors.node, label: '鱼身候选'),
  TechniqueLegendItem(color: TeachingColors.end, label: '被自己吃掉的候选'),
];

const _exocetLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '基格'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '目标格'),
  TechniqueLegendItem(color: TeachingColors.elimCell, label: '伴随格'),
  TechniqueLegendItem(color: TeachingColors.node, label: '基格数字'),
  TechniqueLegendItem(color: TeachingColors.end, label: '目标格上要删的候选'),
];

const _walsLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '成员数字锁进的格'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '多出来的那一格'),
  TechniqueLegendItem(color: TeachingColors.node, label: '成员数字候选'),
  TechniqueLegendItem(color: TeachingColors.end, label: '两支都删掉的候选'),
];

const _rankZeroLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '结构格'),
  TechniqueLegendItem(color: TeachingColors.elimCell, label: '删除落点'),
  TechniqueLegendItem(color: TeachingColors.node, label: '结构候选'),
  TechniqueLegendItem(color: TeachingColors.end, label: '被删的候选'),
];

const _burrLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '数组格'),
  TechniqueLegendItem(color: TeachingColors.elimCell, label: '两支共同的落点'),
  TechniqueLegendItem(color: TeachingColors.node, label: '底数候选'),
  TechniqueLegendItem(color: TeachingColors.end, label: '毛刺与被删候选'),
];

/// 数组/锁定集一侧：自噬、WALS、毛刺数组、DDS、MSLS、飞鱼导弹。
/// 毛刺数组和 DDS 已经接进 `getHint`；其余仍是教学专属。
///
/// 盘面都是随机完整解挖出来的唯一解题目，再用脚本筛出对应的结构。
/// 要靠假设往下推的那两条（WALS、毛刺数组）另加一道筛子：盘面先被唯余摒除推到停，
/// 拿推停的局面当教学盘。这样教学页画出来的候选就是推理用的候选，
/// 盘面上也没有现成的基础招式可走，读者跟得上每一支。
///
/// 这六条引擎都还报不出来，但六条的结构与删除都写进了
/// [TechniqueInfo.structure]，由 `teaching_structure_test` 拿盘面重算后逐条对齐，
/// 所以图上都标了删除落点。
List<TechniqueInfo> advancedSetTechniqueExamples() => [
      TechniqueInfo(
        id: 'cannibalism',
        name: '自噬',
        summary: '修饰：结构算出来的删除落到结构自己身上。',
        definition: '自噬（Cannibalism）不是一个独立图形，而是挂在别的技巧上的修饰词：'
            '鱼、宫线分离子集、待定数组这些结构算出删除之后，'
            '被删的候选正好落在结构自己身上——鱼身上、交叉内部、或者数组格里面。'
            '结论照样成立，只是读图的时候容易犯迷糊，'
            '以为「参与结构的候选不该被删」。工程上不必另写一套穷尽，'
            '现有扫描报完删除之后，过一遍「删除目标是否属于结构」就能挂上这个标签。',
        howToSpot: '任何结构报出删除以后，把删除目标的坐标和结构本体的格子集合比一遍，'
            '两边有交集就是自噬，不必另找图形。'
            '鱼上最容易碰到：两条覆盖线交在一起，而交叉处正好是鱼身上的一格。',
        walkthrough: '本例是一条盯数字 7 的 Franken Swordfish。'
            '基线取 r3、r6 和右下宫：r3 的 7 落在 c1、c2，r6 的 7 落在 c1、c8，'
            '右下宫的 7 落在 r7c8、r9c8；三条基线两两不共格。'
            '覆盖取 c1、c8 和左上宫，六个候选一个不漏地被盖住，条数也对得上，鱼成立。\n'
            '于是三个落点分别占掉 c1、c8、左上宫各一个位置，'
            '覆盖上鱼身之外的 7 就都没地方待了——7r5c1 是常规的那一种删除。\n'
            '关键在 r3c1：它既在覆盖列 c1 上，又在覆盖宫左上宫里，'
            '一格压住了两条覆盖线。如果 r3c1 真填 7，这两条覆盖线就都被它一个人占了，'
            '剩下两个落点只剩一条覆盖线可分，抽屉不够，矛盾。'
            '所以 7r3c1 也能删——而它本来就是基线 r3 上的鱼身候选。'
            '这就是自噬：鱼把自己身上的一个候选吃掉了。',
        caveats: '自噬只是标签，不改变原结构的判定；'
            '别因为删除落在结构里就以为结论无效，也别反过来拿它当独立技巧报。'
            '真正要小心的是前提：只有基线两两不共格，'
            '「落点个数 = 基线条数 = 覆盖条数」这套抽屉计数才成立，'
            '压住两条覆盖线的那一格才删得掉。覆盖允许重叠，基线不允许。',
        rank: 451,
        examplePuzzle:
            '009040007000070000001000930006007305000006028020800409060009100007003040000000800',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [2, 1],
            [5, 0],
            [5, 7],
          ],
          cover: const [
            [6, 7],
            [8, 7],
          ],
          targets: const [
            [2, 0],
            [4, 0],
          ],
          nodes: const [
            [2, 1, 7],
            [5, 0, 7],
            [5, 7, 7],
            [6, 7, 7],
            [8, 7, 7],
          ],
          keys: const [
            [2, 0, 7],
          ],
          weakLinks: const [
            [2, 0, 2, 1, 7],
            [2, 0, 5, 0, 7],
            [5, 0, 5, 7, 7],
            [5, 7, 6, 7, 7],
            [6, 7, 8, 7, 7],
          ],
        ),
        legend: _cannibalLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.fish,
          claim: TeachingClaim.elimination,
          fishes: [
            FishSpec(
              digit: 7,
              baseHouses: [FishHouse.r(2), FishHouse.r(5), FishHouse.b(8)],
              coverHouses: [FishHouse.c(0), FishHouse.c(7), FishHouse.b(0)],
              eliminations: [CandidateRef(2, 0, 7), CandidateRef(4, 0, 7)],
              cannibal: true,
              beyondTurbot: true,
              beyondLocked: true,
            ),
          ],
          conclusionFalse: [CandidateRef(2, 0, 7), CandidateRef(4, 0, 7)],
        ),
      ),
      TechniqueInfo(
        id: 'wals',
        name: 'WALS',
        summary: '弱待定数组：隐性一侧的待定数组，差一格才锁死。',
        definition: '中文术语表里的 WALS 是「弱待定数组」，指隐性一侧的待定数组'
            '（Almost Hidden Set）：一个房屋里挑 N 个数字，'
            '它们在这个房屋里的落点合起来恰好 N+1 格。'
            '要是只有 N 格，那就是现成的隐性数组，当场能删；'
            '多出一格，就差一步，于是分成互斥的两支——'
            '多出来那一格填的是这 N 个数字之一，还是不是。'
            '两支各自往下推，都删掉的候选就是这一页的收获。\n'
            '它和显性一侧的 ALS 是对偶的：ALS 数「N 格上的候选并集有 N+1 个数字」，'
            'WALS 数「N 个数字在一个房屋里占了 N+1 格」。'
            '另外有人拿 WALS 指 ALS-W-Wing——两朵候选相同的 ALS 靠一条强链相连——'
            '那是显性一侧的东西，和这里讲的不是一回事；'
            '本仓库的 W-Wing、ALS-XZ、ALS-XY-Wing 已经覆盖了那一路。',
        howToSpot: '在一个房屋里挑几个还没填的数字，把它们的候选位置并起来数格数：'
            '数字个数 + 1 就是弱待定数组。'
            '再检查任何真子集都不能已经凑成隐性数组（那一步先做更省事），'
            '而且这几格上的候选并集要大到撑不成一朵 ALS——'
            '不然这张图按显性数组也读得通，说不清「弱」在哪里。',
        walkthrough: '这张盘面上唯余、摒除都已经用尽。盯 c7 上的 1 和 5 这两个数字：'
            'c7 里 1 的落点是 r2c7、r8c7；5 的落点是 r3c7、r8c7。'
            '两个数字的落点并起来是 r2c7、r3c7、r8c7 三格——'
            '两个数字占三格，正好多出一格，这就是弱待定数组。'
            '而且单看 1 有两个落点、单看 5 也有两个落点，'
            '任何真子集都不是隐性唯一解，没有更省事的一步可走。\n'
            '三格的候选是 r2c7 `{1,3,4,6}`、r3c7 `{3,4,5,6}`、r8c7 `{1,3,5,8}`，'
            '并集有 `{1,3,4,5,6,8}` 六个数字。三格六数离 ALS（三格四数）差得远，'
            '所以这张图只能从隐性一侧读——这正是「弱」的意思。\n'
            '从多出来的 r2c7 分两支。'
            '甲支：r2c7 填的是 1 或 5。那 r2c7 上的 3、4、6 都得去掉；'
            '4 一走，c7 里的 4 就只剩 r3c7，于是 r3c7=4，'
            '接着 r3 里的 5 只剩 r3c8（r3c8=5），r8 里的 5 只剩 r8c7（r8c7=5），'
            'r8 里的 1 只剩 r8c9（r8c9=1）。\n'
            '乙支：r2c7 填的不是 1 也不是 5。那 1、5 就锁进 r3c7 与 r8c7 两格，'
            '这两格上别的候选统统让位：r3c7 只剩 5，r8c7 只剩 `{1,5}`；'
            '于是 r3c7=5，r8c7=1。\n'
            '两支对照着看：r3c7 甲支填 4、乙支填 5，所以 3r3c7 和 6r3c7 两支都没了；'
            'r8c7 甲支填 5、乙支填 1，所以 3r8c7 和 8r8c7 两支都没了。'
            '这四个候选可以删，结论是 r3c7 只能填 4 或 5、r8c7 只能填 1 或 5。'
            '（答案里 r2c7=6、r3c7=4、r8c7=5，走的正是甲支。）',
        caveats: '弱待定数组只在「N 个数字恰好占 N+1 格」时成立，'
            '多一格少一格都不算；而且任何真子集都不能已经是隐性数组，'
            '否则先做那一步更直接。'
            '两支的推理也必须都走得通：哪一支当场矛盾，'
            '那就说明另一支直接成立，用不着按弱待定数组讲。'
            '最后别把它和 ALS-W-Wing 混着说——那一说是显性一侧的两朵 ALS 加一条强链。',
        rank: 653,
        examplePuzzle:
            '123050789050709020709120000200305090005097214000200005501002000642900000078501042',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [2, 6],
            [7, 6],
          ],
          cover: const [
            [1, 6],
          ],
          nodes: const [
            [1, 6, 1],
            [2, 6, 5],
            [7, 6, 1],
            [7, 6, 5],
          ],
          keys: const [
            [2, 6, 3],
            [2, 6, 6],
            [7, 6, 3],
            [7, 6, 8],
          ],
          weakLinks: const [
            [1, 6, 7, 6, 1],
            [2, 6, 7, 6, 5],
          ],
        ),
        legend: _walsLegend,
        teachingOnly: false,
        structure: const TeachingStructure(
          family: TeachingFamily.almostHiddenSet,
          claim: TeachingClaim.elimination,
          baseDigits: {1, 5},
          lockHouses: [15],
          cells: [
            CellRef(1, 6),
            CellRef(2, 6),
            CellRef(7, 6),
          ],
          splitCell: CellRef(1, 6),
          replayBudget: 4,
          conclusionFalse: [
            CandidateRef(2, 6, 3),
            CandidateRef(2, 6, 6),
            CandidateRef(7, 6, 3),
            CandidateRef(7, 6, 8),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'burr_array',
        name: '毛刺数组',
        summary: '数组多出一块毛刺，把毛刺当链节点用。',
        definition: '毛刺数组（Almost Locked Set with a burr）说的是一个数组多出一小块「毛刺」：'
            '几个格子本来锁住 N 个数字，偏偏多挂了一个额外候选，'
            '于是「数组成立」和「毛刺为真」构成一对互斥的出路。'
            '和普通数组不同，这里不把数组一次删完，而是把毛刺当成交替推理链上的节点，'
            '让它接着往外走。鱼的鳍其实就是毛刺用在鱼身上的特例。'
            '本仓库把「毛刺为真」那一支读到唯余摒除推不动为止，'
            '所以它的力度和强制链同级，提示顺序排在 Kraken 之后而不是 ALS-XZ 之前。',
        howToSpot: '在一个房屋里找 N 格恰好锁 N+1 个数字的待定数组，'
            '再看多出来的那个数字是不是只落在其中一格上——那一格就是毛刺格。'
            '毛刺格自己得还剩三个以上候选，否则「有毛刺还是没毛刺」在那一格上'
            '只是个双值格，谈不上毛刺。'
            '接着分两支算：毛刺为假时数组锁死能删什么，毛刺为真时顺着唯余摒除能删什么，'
            '两支的交集就是收获。',
        walkthrough: '这张盘面上唯余、摒除都已经用尽，接着看 r7 上的三格：'
            'r7c1 `{2,5}`、r7c6 `{2,4,5}`、r7c8 `{4,5,7}`。'
            '三格并集是 `{2,4,5,7}` 四个数字，三格四数，是一朵待定数组。'
            '其中 7 只出现在 r7c8 上——它就是毛刺。'
            '去掉毛刺，剩下的 `{2,4,5}` 正好是三个数字配三个格子。'
            '而 r7c8 还剩三个候选，去掉 7 之后仍有真正的选择，毛刺立得住；'
            '把 r7c8 整格拿掉，r7c1 与 r7c6 的并集还有 `{2,4,5}` 三个数字，'
            '两格装不下三个数字，所以剩下的部分也不是现成的显性数组。\n'
            '两支这样走。甲支：毛刺为假，也就是 r7c8 不填 7。'
            '那么 `{2,4,5}` 被这三格锁死，r7 上别处的这些数字都得让位：'
            '2r7c2、5r7c2、2r7c3、5r7c3、2r7c7、4r7c7、5r7c7 一共七个候选。\n'
            '乙支：毛刺为真，r7c8=7。顺着推：b9 里的 4 本来只在 r7c7、r7c8 两格，'
            'r7c8 被 7 占住，于是 r7c7=4；接着 c7 里的 2 只剩 r9c7，于是 r9c7=2。'
            '这一支只在 r7c7 上动手，把 2r7c7、5r7c7 删掉了，'
            '但 4r7c7 反而被填成了真。\n'
            '取交集：只有 2r7c7 与 5r7c7 两支都删得掉。'
            '甲支多删的那五个（r7c2、r7c3 上的，以及 4r7c7）都不能算——'
            '4r7c7 更是反例，甲支说它假、乙支说它真。'
            '这就是「把毛刺当推理节点」的意思：不是把数组一次删完，'
            '而是让两条出路各自往下推，再取共同部分。'
            '结论是 r7c7 只能填 4 或 7。（答案里 r7c7 填的是 7。）',
        caveats: '毛刺只能有一块：多出两个以上额外候选就不再是毛刺数组，'
            '得回到普通的待定数组处理。'
            '把毛刺格拿掉之后，剩下的格子也不能已经自己锁住自己的数字——'
            '那是个现成的显性数组，毛刺根本没参与推理。'
            '最要紧的是别只画一张数组的图就收工：'
            '不交代两支各推出什么、交集是哪几个，这一页得不出任何结论。'
            '也别把甲支单独删掉的那一串当成结论——本例的 4r7c7 就是反例。',
        rank: 702,
        examplePuzzle:
            '609301007130007002700000013403006801000078364800003025000630009900700138304819006',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [6, 0],
            [6, 5],
            [6, 7],
          ],
          targets: const [
            [6, 6],
          ],
          nodes: const [
            [6, 0, 2],
            [6, 0, 5],
            [6, 5, 2],
            [6, 5, 4],
            [6, 5, 5],
            [6, 7, 4],
            [6, 7, 5],
          ],
          keys: const [
            [6, 7, 7],
            [6, 6, 2],
            [6, 6, 5],
          ],
          weakLinks: const [
            [6, 0, 6, 5, 2],
            [6, 5, 6, 7, 4],
            [6, 0, 6, 7, 5],
          ],
        ),
        legend: _burrLegend,
        structure: const TeachingStructure(
          family: TeachingFamily.burredSubset,
          claim: TeachingClaim.elimination,
          baseDigits: {2, 4, 5},
          lockHouses: [6],
          cells: [
            CellRef(6, 0),
            CellRef(6, 5),
            CellRef(6, 7),
          ],
          burr: CandidateRef(6, 7, 7),
          replayBudget: 3,
          conclusionFalse: [CandidateRef(6, 6, 2), CandidateRef(6, 6, 5)],
        ),
      ),
      TechniqueInfo(
        id: 'dds',
        name: 'DDS',
        summary: '分离子集推到三个及以上区域。',
        definition: 'DDS（Distributed Disjoint Subsets，分布式互斥数组）是 Sue de Coq 的推广。'
            'Sue de Coq 只在一个宫和一条线交叉处把数字拆成两堆互不相交的锁定集；'
            'DDS 把这件事摊到三个以上的区域：挑 N 个格子，'
            '它们的候选并集恰好 N 个数字，而且每个数字在这 N 格里的落点'
            '都被某一条房屋整个装下——这条房屋就是这个数字的「片」。\n'
            'N 个格子各要填一个数，每个数字的片最多消化一格，'
            'N 格配 N 片，正好一格一片，谁也匀不出来。'
            '所以每一片里、结构之外的那个数字统统可以删。'
            '这套计数就是 rank 0；片数至少三条，'
            '否则一两条房屋装得下的那些情形已经由显性/隐性数组和 Sue de Coq 讲过了。',
        howToSpot: '挑几个跨区域的空格，先数「格数 = 候选并集的数字个数」；'
            '再对每个数字看它在这几格里的落点能不能被一条房屋整个装下。'
            '两条都成立就是 DDS。'
            '还要防两种冒充：全部格子落在同一个房屋里（那是显性数组），'
            '以及存在两条房屋就能装下每个数字的落点（那是 Sue de Coq 那一档）。',
        walkthrough: '本例挑六格：c1 上的 r2c1 `{1,5}`、r5c1 `{1,5,8}`、r7c1 `{4,5,8}`，'
            '还有 r8 上的 r8c2 `{4,9}`、r8c3 `{2,4,9}`、r8c6 `{2,9}`。'
            '六格的候选并集是 `{1,2,4,5,8,9}`，正好六个数字。\n'
            '再看每个数字的片：1 落在 r2c1、r5c1，两格都在 c1；'
            '5 落在 r2c1、r5c1、r7c1，也都在 c1；8 落在 r5c1、r7c1，仍在 c1。'
            '4 落在 r7c1、r8c2、r8c3——这三格同在左下宫。'
            '9 落在 r8c2、r8c3、r8c6，同在 r8；2 落在 r8c3、r8c6，也在 r8。'
            '于是六个数字分到三条房屋上：c1 装 1、5、8，左下宫装 4，r8 装 9、2。'
            '六格六片，rank 0。'
            '这三条房屋换不成两条——4 那一片必须跨到左下宫，'
            '而 1、5、8 又只能待在 c1 里，所以它确实分布在三个区域上。\n'
            '结论就是把每一片里结构之外的同名候选清掉：'
            'c1 上 r4c1 的 1、5、8 全删（它是 c1 里唯一的其它空格），'
            '左下宫里 r7c3、r9c2、r9c3 上的 4 也都删。'
            '（顺带核对一下：答案里这六格填 5、1、8、9、4、2，六个数字一个不重。）',
        caveats: '片与片不能共用格子，每个数字也必须严格落在自己那一片里——'
            '算错一处就会删掉真数，比一般技巧危险得多。'
            '还有两条容易忽略的退化：某个数字在结构里只落在一格上时，'
            '那一格其实是被这个数字直接占住的，是换个说法的摒除法；'
            '而如果两条房屋就装得下每个数字的落点，'
            '这个图形骨子里是 Sue de Coq，不该按「分布到三个以上区域」讲。',
        rank: 750,
        examplePuzzle:
            '900000600020080094683000000000000000000794000200006039010070020300860500700301000',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [1, 0],
            [4, 0],
            [6, 0],
            [7, 1],
            [7, 2],
            [7, 5],
          ],
          targets: const [
            [3, 0],
            [6, 2],
            [8, 1],
            [8, 2],
          ],
          nodes: const [
            [1, 0, 1],
            [1, 0, 5],
            [4, 0, 1],
            [4, 0, 5],
            [4, 0, 8],
            [6, 0, 4],
            [6, 0, 5],
            [6, 0, 8],
            [7, 1, 4],
            [7, 1, 9],
            [7, 2, 2],
            [7, 2, 4],
            [7, 2, 9],
            [7, 5, 2],
            [7, 5, 9],
          ],
          keys: const [
            [3, 0, 1],
            [3, 0, 5],
            [3, 0, 8],
            [6, 2, 4],
            [8, 1, 4],
            [8, 2, 4],
          ],
          weakLinks: const [
            [1, 0, 4, 0, 1],
            [4, 0, 6, 0, 8],
            [6, 0, 7, 1, 4],
            [7, 1, 7, 2, 9],
            [7, 2, 7, 5, 2],
          ],
        ),
        legend: _rankZeroLegend,
        teachingOnly: false,
        structure: const TeachingStructure(
          family: TeachingFamily.distributedDisjointSubset,
          claim: TeachingClaim.elimination,
          lockedDigitCount: 6,
          cells: [
            CellRef(1, 0),
            CellRef(4, 0),
            CellRef(6, 0),
            CellRef(7, 1),
            CellRef(7, 2),
            CellRef(7, 5),
          ],
          // c1 装 1、5、8；左下宫装 4；r8 装 9、2。
          sectorLinks: [
            SectorLink(1, [9]),
            SectorLink(5, [9]),
            SectorLink(8, [9]),
            SectorLink(4, [24]),
            SectorLink(9, [7]),
            SectorLink(2, [7]),
          ],
          conclusionFalse: [
            CandidateRef(3, 0, 1),
            CandidateRef(3, 0, 5),
            CandidateRef(3, 0, 8),
            CandidateRef(6, 2, 4),
            CandidateRef(8, 1, 4),
            CandidateRef(8, 2, 4),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'msls',
        name: 'MSLS',
        summary: '多区域锁定集的一般形，没有独立判定。',
        definition:
            'MSLS（Multi-Sector Locked Sets，多区域锁定集）是 Sue de Coq 和 DDS 的更一般形。'
            '挑一批格子，再给每个数字配上「装得下它在结构里全部落点」的房屋，'
            '每条房屋算一条链接。DDS 要求每个数字只占一条链接，'
            'MSLS 放开了这一条：一个数字可以占两条房屋、算两条链接。\n'
            '道理还是数链接。每个结构格要填一个数，那个「数字 + 房屋」的组合就是一条链接；'
            '两个格子不可能用同一条链接（同房屋同数字只能有一个）。'
            '所以格子到链接是单射，链接条数又和格数相等，于是成了双射——'
            '每条链接都被用掉一次。链接被用掉，就意味着这个数字在那条房屋里落在结构格上，'
            '于是那条房屋里结构之外的同名候选全都可以删。'
            '这就是 rank 0。\n'
            '难处在于「挑哪些格子、配哪些房屋」没有任何形状上的线索，'
            '只能靠通用覆盖搜索一遍遍试，所以评审把它的可行性判成「否」：'
            '它没有独立于通用覆盖搜索的判定，本仓库只作教学收录。',
        howToSpot: '先看 Sue de Coq 和 DDS 这些有固定形状的特例，它们才有得找。'
            '真要认 MSLS，就逐个数字配房屋、把链接条数和格数摆在一起数，'
            '相等才算 rank 0；顺手检查每个结构格的每个候选都被某条链接盖住，'
            '漏一个单射就断了。',
        walkthrough: '本例挑六格：r7 上的 r7c4 `{3,7}`、r7c5 `{7,9}`、r7c6 `{3,7,9}`，'
            '还有 c8 上的 r2c8 `{5,9}`、r8c8 `{8,9}`、r9c8 `{8,9}`。'
            '六格里只出现五个数字——`{3,5,7,8,9}`，比格数少一个，'
            '所以光靠「格数 = 数字数」是配不平的，这正是 DDS 做不到、MSLS 才能做的地方。\n'
            '逐个数字配房屋：3 落在 r7c4、r7c6，一条 r7 就够；'
            '7 落在 r7c4、r7c5、r7c6，也是一条 r7；'
            '8 落在 r8c8、r9c8，一条 c8；5 只落在 r2c8，一条 r2。'
            '9 最特别：它落在 r7c5、r7c6、r2c8、r8c8、r9c8 上，'
            '一条房屋装不下，得用 r7 加 c8 两条——它自己就占了两条链接。\n'
            '数一数：r7 的 3、r7 的 7、r7 的 9、c8 的 9、r2 的 5、c8 的 8，'
            '一共六条链接，正好等于六格，rank 0 成立。'
            '所用的区域是 r7、c8、r2 三片，够得上「多区域」。\n'
            '于是每条链接都被用掉一次，各自把房屋里结构之外的同名候选清掉：'
            'r2 上 5 只能在 r2c8，所以 5r2c5、5r2c6、5r2c7 都删；'
            'c8 上的 8 只在 r8c8、r9c8，所以 8r1c8、8r4c8 删；'
            '9 在 r7 与 c8 上也都被结构占住，所以 9r7c1、9r1c8、9r6c8 删；'
            'r7 上的 3 同理，删掉 3r7c1。'
            '（答案里这六格填 3、9、7、5、9、8，和上面的链接一一对得上。）',
        caveats: 'MSLS 只作教学收录，不进提示搜索顺序：它没有独立判定，'
            '找它就是在跑通用覆盖搜索。'
            '平衡条件算错就会删掉真数，比一般技巧危险得多——'
            '尤其要盯住「每个结构格的每个候选都得被某条链接盖住」这一条，'
            '漏掉一个，那一格就能跳出结构，整套计数立刻失效。'
            '另外别把每个数字只占一条房屋的图形当 MSLS 讲，那种正好是 DDS。',
        rank: 850,
        examplePuzzle:
            '000000000813000002090100670000900000400501030700038000058000146000002705007000200',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [6, 3],
            [6, 4],
            [6, 5],
            [1, 7],
            [7, 7],
            [8, 7],
          ],
          targets: const [
            [1, 4],
            [1, 5],
            [1, 6],
            [6, 0],
            [0, 7],
            [3, 7],
            [5, 7],
          ],
          nodes: const [
            [6, 3, 3],
            [6, 3, 7],
            [6, 4, 7],
            [6, 4, 9],
            [6, 5, 3],
            [6, 5, 7],
            [6, 5, 9],
            [1, 7, 5],
            [1, 7, 9],
            [7, 7, 8],
            [7, 7, 9],
            [8, 7, 8],
            [8, 7, 9],
          ],
          keys: const [
            [1, 4, 5],
            [1, 5, 5],
            [1, 6, 5],
            [6, 0, 3],
            [6, 0, 9],
            [0, 7, 8],
            [0, 7, 9],
            [3, 7, 8],
            [5, 7, 9],
          ],
          // 9 占两条房屋，所以 r7 与 c8 上各画一段，不跨房屋连线。
          weakLinks: const [
            [6, 3, 6, 5, 3],
            [6, 4, 6, 5, 7],
            [6, 4, 6, 5, 9],
            [1, 7, 7, 7, 9],
            [7, 7, 8, 7, 8],
          ],
        ),
        legend: _rankZeroLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.multiSectorLockedSet,
          claim: TeachingClaim.elimination,
          cells: [
            CellRef(6, 3),
            CellRef(6, 4),
            CellRef(6, 5),
            CellRef(1, 7),
            CellRef(7, 7),
            CellRef(8, 7),
          ],
          // 9 一个数字吃掉 r7 与 c8 两条房屋，这是 MSLS 比 DDS 一般的地方。
          sectorLinks: [
            SectorLink(3, [6]),
            SectorLink(7, [6]),
            SectorLink(9, [6, 16]),
            SectorLink(5, [1]),
            SectorLink(8, [16]),
          ],
          conclusionFalse: [
            CandidateRef(1, 4, 5),
            CandidateRef(1, 5, 5),
            CandidateRef(1, 6, 5),
            CandidateRef(6, 0, 3),
            CandidateRef(6, 0, 9),
            CandidateRef(0, 7, 8),
            CandidateRef(0, 7, 9),
            CandidateRef(3, 7, 8),
            CandidateRef(5, 7, 9),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'exocet',
        name: '飞鱼导弹',
        summary: 'Exocet：两个基格锁数字，目标格受镜像约束。',
        definition: '飞鱼导弹（Exocet）在同一带里取两个同宫同线的基格，'
            '它们的候选并集就是基格数字，通常 3 到 4 个。'
            '同一带另外两个宫里各取一对「对象格」——同一条交叉线上的两个非基线格，'
            '其中一格带基格数字（目标格），另一格一个基格数字都不带（伴随格，给定数也算）。'
            '三条交叉线是两个目标格所在的那两条，加上基格宫里基格没占的那一条。'
            '交叉线伸出带外的那部分叫 S 格。\n'
            'Junior Exocet（JE）的判定条件是：每个基格数字在 S 格上的全部出现'
            '（候选、给定数都算）都能被不超过两条房屋盖住。'
            '这时结论成立——两个目标格必须分别落到两个基格数字上，'
            '于是目标格上不属于基格数字集的候选统统可以删。\n'
            'Junior、Senior、Weak、Double、Locked Member 都是同一套约束下的变体，'
            '约束本身是固定的、可以判定的，只是变体多、工程量大，所以可行性是「是」。',
        howToSpot: '在一条带里找同宫同线的两个空基格，看候选并集是不是三四个数字；'
            '再到另外两宫里找对象格对：一格带基格数字、另一格一个都不带。'
            '最后数覆盖线——每个基格数字在 S 格上的出现都要被两条房屋兜住。'
            '这一步最容易漏，漏了删除就不成立。',
        walkthrough: '本例是 Ruud top50000 第 12235 题的开局。'
            '基格取中中宫里同在 r5 的 r5c4 `{2,5}` 与 r5c6 `{2,6}`，'
            '并集是 `{2,5,6}` 三个数字。\n'
            '带是 r4–r6。左中宫里取 c3 这一对：r4c3 已经填了 7，'
            '一个基格数字都不带，是伴随格；r6c3 `{1,2,5,6,9}` 带着基格数字，是目标格。'
            '右中宫里取 c7 这一对：r6c7 填的是 8，同样一个基格数字都没有，是伴随格；'
            'r4c7 `{2,4,5,6}` 是目标格。'
            '于是三条交叉线是 c3、c7，加上基格宫里空着的 c5。\n'
            '数覆盖线。S 格就是 c3、c5、c7 在 r1–r3 与 r7–r9 上的那些格子。'
            '2 在 S 格上出现于 r1c5、r1c7、r8c3、r8c5——r1 与 r8 两条行就盖住了；'
            '5 出现于 r1c3、r1c7、r8c5、r8c7——同样是 r1 与 r8；'
            '6 出现于 r2c5、r2c7、r9c3、r9c7——r2 与 r9 两条。'
            '三个基格数字都只需两条覆盖线，JE 条件满足。\n'
            '道理是这样：设基格里真填的两个数是 A、B。'
            '三条交叉线各要放一个 A，一共三个。'
            '这三个 A 落不到基格看得见的逃逸格上，也落不到伴随格上（按定义那里没有基格数字），'
            '所以只能待在目标格或 S 格里。'
            '而 S 格上的 A 全被两条覆盖线盖住，两条线最多放下两个 A，'
            '于是至少有一个 A 落在目标格上。B 同理。'
            '两个目标格互不相同，只好一个装 A、一个装 B。\n'
            '既然目标格只能填基格数字，它们身上别的候选就都能删：'
            'r6c3 上删 1 和 9，r4c7 上删 4。'
            '（答案里 r6c3=5、r4c7=2，正是两个不同的基格数字。）\n'
            '镜像格在这里只标出来备用：r6c3 的镜像是 r4c8、r4c9，'
            'r4c7 的镜像是 r6c1、r6c2——都是「贴着对面那个目标格」的两格。'
            '镜像格还能推出更多删除，本页不展开。',
        caveats: '基格必须同宫同线；两个目标格必须在同一带的另外两宫、'
            '各占不同的交叉线、而且都不在基线上（不然它们看得见基格）。'
            '伴随格「一个基格数字都不带」这一条要把给定数也算进去，'
            '漏算就等于允许一对对象格装下两个基格数字，整套推理塌掉。'
            '覆盖线最多两条也必须逐个数字核对。\n'
            '本页只下「目标格上删非基格候选」这一条结论。'
            '镜像格那一路的规则（Bird 的 Rule 6 到 Rule 9）在文献里还有争议——'
            '照字面实现会删出错的候选，'
            '本例的盘面正是当年被拿来说明这一点的那一题，所以这里不用它下结论。'
            'Senior、Weak、Double、Locked Member 各变体也都还没实现。',
        rank: 900,
        examplePuzzle:
            '060000009020005000008070100007003000830010097000400800004080900000600010500000020',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [4, 3],
            [4, 5],
          ],
          cover: const [
            [5, 2],
            [3, 6],
          ],
          targets: const [
            [3, 2],
            [5, 6],
          ],
          nodes: const [
            [4, 3, 2],
            [4, 3, 5],
            [4, 5, 2],
            [4, 5, 6],
            [5, 2, 2],
            [5, 2, 5],
            [5, 2, 6],
            [3, 6, 2],
            [3, 6, 5],
            [3, 6, 6],
          ],
          keys: const [
            [5, 2, 1],
            [5, 2, 9],
            [3, 6, 4],
          ],
          weakLinks: const [
            [4, 3, 4, 5, 2],
          ],
        ),
        legend: _exocetLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.exocet,
          claim: TeachingClaim.elimination,
          baseDigits: {2, 5, 6},
          exocet: ExocetSpec(
            baseCells: [CellRef(4, 3), CellRef(4, 5)],
            targets: [CellRef(5, 2), CellRef(3, 6)],
            companions: [CellRef(3, 2), CellRef(5, 6)],
            mirrors: [
              [CellRef(3, 7), CellRef(3, 8)],
              [CellRef(5, 0), CellRef(5, 1)],
            ],
            // c3、c5、c7。
            crossLines: [11, 13, 15],
            coverLines: [
              SectorLink(2, [0, 7]),
              SectorLink(5, [0, 7]),
              SectorLink(6, [1, 8]),
            ],
            eliminations: [
              CandidateRef(5, 2, 1),
              CandidateRef(5, 2, 9),
              CandidateRef(3, 6, 4),
            ],
          ),
          conclusionFalse: [
            CandidateRef(5, 2, 1),
            CandidateRef(5, 2, 9),
            CandidateRef(3, 6, 4),
          ],
        ),
      ),
    ];
