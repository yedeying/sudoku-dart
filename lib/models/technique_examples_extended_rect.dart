import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_catalog.dart';
import 'technique_examples_teaching_support.dart';
import 'technique_structure.dart';

/// 扩展矩形 1–4 的教学盘面。
///
/// 六格扩展矩形的几何是固定的：两条同向的线各取同一个宫柱（或宫带）里的三格，
/// 六格恰好落在两个宫里，而且每一格都含同一组三个底数。
/// 满足这些条件时，两条线上的三个底数可以整块换一种排法而盘外毫无变化，
/// 于是解不唯一——这就是它的致命性来源。
///
/// 每个盘面都是先按几何把结构挖出来、再用求解器确认唯一解筛出来的，
/// 结构声明里的额外候选是穷尽列出的，测试会拿盘面复核一遍：
/// 六格是不是真的都含底数、除底数之外还剩什么、结论跟唯一解合不合。
List<TechniqueInfo> extendedRectTechniqueExamples() => [
      TechniqueInfo(
        id: 'er1',
        name: '扩展矩形 1',
        summary: '六格致命形多出一个候选，那一格就填它。',
        definition: '扩展矩形（Extended Rectangle）把唯一矩形的两行两列撑成两条线各三格，'
            '一共六格，落在两个宫里，六格都含同一组三个底数。'
            '这种结构可以把两条线上的底数整块换一种排法而盘外毫无变化，所以是致命形。'
            '类型 1 是最直接的用法：六格里只有一格比底数多出一个候选，'
            '其余五格都只剩底数，那多出来的候选必须为真，否则整块对调就会造出第二个解。',
        howToSpot: '找两条同向的线，各取同一个宫柱（或宫带）里的三格，'
            '看这六格是不是都含同一组底数，只有一格多出候选。',
        walkthrough: '本例的六格是 c6 上的 r1c6、r2c6、r3c6 和 c8 上的 r1c8、r2c8、r3c8，'
            '分别落在中上宫和右上宫这两个宫里，六格都含底数 `{2,4,6}`。'
            '前五格恰好只剩 `{2,4,6}`，只有 r3c8 多出一个 5。'
            '假设 5r3c8 为假，那六格就只剩底数，2、4、6 在 c6 和 c8 上就能整块换一种排法，'
            '盘外看不出任何差别，题目会有两个解。所以 5r3c8 必须为真，r3c8 就填 5。',
        caveats: '六格必须严格落在两个宫里、而且每一格都含全部三个底数，'
            '少一格或者哪一格缺了底数，整块对调就走不通，结论也不成立。',
        rank: 453,
        examplePuzzle:
            '050300000000950107000810003089001000020080070006007800002039080070120395908600701',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [0, 5],
            [1, 5],
            [2, 5],
            [0, 7],
            [1, 7],
          ],
          targets: const [
            [2, 7],
          ],
          nodes: const [
            [0, 5, 2],
            [0, 5, 4],
            [0, 5, 6],
            [1, 5, 2],
            [1, 5, 4],
            [1, 5, 6],
            [2, 5, 2],
            [2, 5, 4],
            [2, 5, 6],
            [0, 7, 2],
            [0, 7, 4],
            [0, 7, 6],
            [1, 7, 2],
            [1, 7, 4],
            [1, 7, 6],
            [2, 7, 2],
            [2, 7, 4],
            [2, 7, 6],
          ],
          keys: const [
            [2, 7, 5],
          ],
          weakLinks: const [
            [0, 5, 0, 7, 2],
            [1, 5, 1, 7, 4],
            [2, 5, 2, 7, 6],
          ],
        ),
        legend: [...structureLegend, targetLegendItem],
        structure: const TeachingStructure(
          family: TeachingFamily.extendedRect,
          claim: TeachingClaim.type1,
          baseDigits: {2, 4, 6},
          cells: [
            CellRef(0, 5),
            CellRef(1, 5),
            CellRef(2, 5),
            CellRef(0, 7),
            CellRef(1, 7),
            CellRef(2, 7),
          ],
          extras: [CandidateRef(2, 7, 5)],
          boxSpan: 2,
          conclusionTrue: [CandidateRef(2, 7, 5)],
        ),
      ),
      TechniqueInfo(
        id: 'er2',
        name: '扩展矩形 2',
        summary: '同侧两格多出同一个数字，删共同可见处。',
        definition: '扩展矩形类型 2 对应唯一矩形 2：六格结构里有两格除了底数之外都多出同一个'
            '额外数字 c，其余四格只剩底数。这两格不可能都把 c 去掉——'
            '否则六格只剩底数，两条线上的底数整块对调就多出一个解。'
            '所以 c 至少在这两格之一为真，同时看得见这两格的位置上，c 可以删。'
            '用法和唯一矩形 2 一模一样，只是几何从四格换成六格。',
        howToSpot: '认出六格扩展矩形之后，数一数额外候选：'
            '如果只有两格多出候选、而且多出来的是同一个数字，就走类型 2。',
        walkthrough: '本例的六格是 c3 上的 r7c3、r8c3、r9c3 和 c5 上的 r7c5、r8c5、r9c5，'
            '落在左下宫和中下宫两个宫里，六格都含底数 `{3,6,8}`。'
            '额外候选只有两个，而且都是 7：r7c5 是 `{3,6,7,8}`、r9c5 是 `{3,6,7,8}`。'
            '如果 7r7c5 与 7r9c5 同时为假，六格就只剩 `{3,6,8}`，两条线可以整块对调。'
            '所以 7 至少落在这两格之一，凡是同时看得见 r7c5 与 r9c5 的位置都能删 7：'
            'c5 上的 r3c5、r6c5，以及中下宫里同排的 r9c4。',
        caveats: '两格多出来的必须是同一个数字，多出两个不同数字就得改走类型 3 的虚拟格；'
            '删除范围只算「同时」看得见这两格的位置，只看得见一格的不算。',
        rank: 480,
        examplePuzzle:
            '207304581061090003504000900080900007079050824600000300150402090000501700020009015',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [6, 2],
            [7, 2],
            [8, 2],
            [6, 4],
            [7, 4],
            [8, 4],
          ],
          targets: const [
            [2, 4],
            [5, 4],
            [8, 3],
          ],
          nodes: const [
            [6, 2, 3],
            [6, 2, 6],
            [6, 2, 8],
            [7, 2, 3],
            [7, 2, 6],
            [7, 2, 8],
            [8, 2, 3],
            [8, 2, 6],
            [8, 2, 8],
            [6, 4, 3],
            [6, 4, 6],
            [6, 4, 8],
            [7, 4, 3],
            [7, 4, 6],
            [7, 4, 8],
            [8, 4, 3],
            [8, 4, 6],
            [8, 4, 8],
          ],
          keys: const [
            [6, 4, 7],
            [8, 4, 7],
          ],
          weakLinks: const [
            [6, 4, 8, 4, 7],
            [6, 2, 6, 4, 3],
            [7, 2, 7, 4, 6],
          ],
        ),
        legend: [...structureLegend, targetLegendItem],
        structure: const TeachingStructure(
          family: TeachingFamily.extendedRect,
          claim: TeachingClaim.type2,
          baseDigits: {3, 6, 8},
          cells: [
            CellRef(6, 2),
            CellRef(7, 2),
            CellRef(8, 2),
            CellRef(6, 4),
            CellRef(7, 4),
            CellRef(8, 4),
          ],
          extras: [CandidateRef(6, 4, 7), CandidateRef(8, 4, 7)],
          boxSpan: 2,
          conclusionFalse: [
            CandidateRef(2, 4, 7),
            CandidateRef(5, 4, 7),
            CandidateRef(8, 3, 7),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'er4',
        name: '扩展矩形 4',
        summary: '底数之一被锁在垂直房屋的两格上，删这两格的其它底数。',
        definition: '扩展矩形类型 4 对应唯一矩形 4（锁定型）。'
            '六格结构横着看是三条「垂直房屋」，每条上各有两格；'
            '类型 4 要的就是某个底数在其中一条垂直房屋里只剩结构上的这两格，'
            '也就是形成一条强链。'
            '这个底数既然一定落在这两格之一，'
            '那另外两个底数如果还完整留在同样这两格上，六格就凑成了可以整块对调的死结，'
            '所以这两格上除强链底数以外的底数都能删。'
            '注意强链只可能出现在只占两格的垂直房屋上——'
            '结构自己那两条三格线上，底数本来就要在三格里各占一次，锁不出强链。',
        howToSpot: '认出六格几何后，只看那三条各占两格的垂直房屋：'
            '逐个底数数它在这条房屋里的落点，看有没有哪个底数只剩结构的那两格。',
        walkthrough: '本例的六格是 c2 上的 r1c2、r2c2、r3c2 和 c8 上的 r1c8、r2c8、r3c8，'
            '落在左上宫和右上宫两个宫里，六格都含底数 `{4,6,9}`。'
            '三条垂直房屋是 r1、r2、r3，各占两格。'
            '额外候选只在 r3 这条上：r3c2 多出 3，r3c8 多出 1。'
            '现在数 4 在 r3 上的落点——只剩 r3c2 与 r3c8，这就是一条强链，'
            '底数 4 一定落在这两格之一。'
            '假设 9r3c2 为真：r3c8 只能是 4，剩下四格里 6、9 又只能各归一列，'
            '六格正好凑成三个底数的一种排法，整块对调就有第二个解。'
            '同样的话对 6r3c2、9r3c8、6r3c8 都成立，'
            '所以这四个候选都能删——r3c2 只剩 `{3,4}`，r3c8 只剩 `{1,4}`。',
        caveats: '强链要按当前候选现算；'
            '而且别把结构自己的三格线当成可以锁的房屋，那条线上底数各占一次，锁不出强链。',
        rank: 502,
        examplePuzzle:
            '001030000805100003000500200128000000000040070004000580072001004900004600400200150',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [0, 1],
            [1, 1],
            [0, 7],
            [1, 7],
          ],
          targets: const [
            [2, 1],
            [2, 7],
          ],
          nodes: const [
            [0, 1, 4],
            [0, 1, 6],
            [0, 1, 9],
            [1, 1, 4],
            [1, 1, 6],
            [1, 1, 9],
            [2, 1, 4],
            [2, 1, 6],
            [2, 1, 9],
            [0, 7, 4],
            [0, 7, 6],
            [0, 7, 9],
            [1, 7, 4],
            [1, 7, 6],
            [1, 7, 9],
            [2, 7, 4],
            [2, 7, 6],
            [2, 7, 9],
          ],
          keys: const [
            [2, 1, 3],
            [2, 7, 1],
          ],
          strongLinks: const [
            [2, 1, 2, 7, 4],
          ],
          weakLinks: const [
            [0, 1, 0, 7, 6],
            [1, 1, 1, 7, 4],
          ],
        ),
        legend: [...structureLegend, targetLegendItem],
        structure: const TeachingStructure(
          family: TeachingFamily.extendedRect,
          claim: TeachingClaim.type4,
          baseDigits: {4, 6, 9},
          cells: [
            CellRef(0, 1),
            CellRef(1, 1),
            CellRef(2, 1),
            CellRef(0, 7),
            CellRef(1, 7),
            CellRef(2, 7),
          ],
          extras: [CandidateRef(2, 1, 3), CandidateRef(2, 7, 1)],
          lockDigit: 4,
          lockHouses: [2],
          boxSpan: 2,
          conclusionFalse: [
            CandidateRef(2, 1, 9),
            CandidateRef(2, 7, 9),
            CandidateRef(2, 1, 6),
            CandidateRef(2, 7, 6),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'er3',
        name: '扩展矩形 3',
        summary: '两格的多余候选合成虚拟格，和同房屋的格子配数组。',
        definition: '扩展矩形类型 3 对应唯一矩形 3：六格里有两格除底数之外还各带额外候选，'
            '而且这两格同处一个房屋。'
            '六格不可能都只填底数，所以这两格里至少有一个要填自己的额外候选——'
            '把它们合起来看成一个「虚拟格」，虚拟格的候选就是那些额外数字。'
            '虚拟格算一格，再拿它和同房屋其它格子配成数组：'
            'k 个格子（含虚拟格）锁住 k 个数字，这几个数字在这个房屋别处就能删。'
            '这里的关键是虚拟格代表的是完整性约束，不能拆开当普通裸对用。'
            '要留意几何：带额外候选的两格必须真的同房屋，'
            '在 2×3 的扩展矩形里只有落在同一条三格线（或同一个宫）上才行。',
        howToSpot: '认出六格几何后，找出只有两格带额外候选、而且这两格同房屋的情形，'
            '把它们的额外候选并起来当一格，再在这个房屋里找能配成数组的格子。',
        walkthrough: '本例的六格是 r2c4、r2c5、r2c6 和 r4c4、r4c5、r4c6，'
            '落在中上宫和中中宫两个宫里，六格都含底数 `{2,7,9}`。'
            '额外候选都在 r4 这条线上：r4c5 是 `{1,2,7,9}`，多出 1；'
            'r4c6 是 `{2,5,7,9}`，多出 5；其余四格只剩 `{2,7,9}`。'
            '这两格同在 r4 上，合成一个候选为 `{1,5}` 的虚拟格。'
            'r4 上的 r4c1 恰好也是 `{1,5}`，虚拟格加上它就是两格锁两个数字的裸数对，'
            '于是 1 和 5 在 r4 别处都能删：r4c7 的 1、r4c8 的 1。'
            '（r4 上再没有别的格子含 5，所以这一步只删得到 1。）',
        caveats: '虚拟格只能整体参与数组，绝不能把额外候选拆开当裸对用；'
            '配数组的格子必须和虚拟格同处一个房屋，'
            '数组的格数和锁住的数字个数也要正好相等。',
        rank: 550,
        examplePuzzle:
            '000100000050000803300546002068000004200004000070300650906050280000001700000000005',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [1, 3],
            [1, 4],
            [1, 5],
            [3, 3],
            [3, 4],
            [3, 5],
          ],
          cover: const [
            [3, 0],
          ],
          targets: const [
            [3, 6],
            [3, 7],
          ],
          nodes: const [
            [1, 3, 2],
            [1, 3, 7],
            [1, 3, 9],
            [1, 4, 2],
            [1, 4, 7],
            [1, 4, 9],
            [1, 5, 2],
            [1, 5, 7],
            [1, 5, 9],
            [3, 3, 2],
            [3, 3, 7],
            [3, 3, 9],
            [3, 4, 2],
            [3, 4, 7],
            [3, 4, 9],
            [3, 5, 2],
            [3, 5, 7],
            [3, 5, 9],
            [3, 0, 1],
            [3, 0, 5],
          ],
          keys: const [
            [3, 4, 1],
            [3, 5, 5],
          ],
          weakLinks: const [
            [3, 4, 3, 0, 1],
            [3, 5, 3, 0, 5],
            [1, 3, 3, 3, 2],
          ],
        ),
        legend: [
          ...structureLegend,
          const TechniqueLegendItem(
              color: TeachingColors.cover, label: '配数组的格子'),
          targetLegendItem,
        ],
        structure: const TeachingStructure(
          family: TeachingFamily.extendedRect,
          claim: TeachingClaim.type3,
          baseDigits: {2, 7, 9},
          cells: [
            CellRef(1, 3),
            CellRef(1, 4),
            CellRef(1, 5),
            CellRef(3, 3),
            CellRef(3, 4),
            CellRef(3, 5),
          ],
          extras: [CandidateRef(3, 4, 1), CandidateRef(3, 5, 5)],
          subsetCells: [CellRef(3, 0)],
          subsetDigits: {1, 5},
          boxSpan: 2,
          conclusionFalse: [
            CandidateRef(3, 6, 1),
            CandidateRef(3, 7, 1),
          ],
        ),
      ),
    ];
