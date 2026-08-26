import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_catalog.dart';
import 'technique_examples_teaching_support.dart';
import 'technique_structure.dart';

/// 唯一环 1–4 的教学盘面。
///
/// 六格偶环的几何：三行取同一宫带、三列各取一个宫柱，环上相邻两格总是同行或同列，
/// 每一行、每一列、每一宫都恰好占环上两格。满足这些条件时，
/// 环上两个底数可以沿环交替换一遍而盘外毫无变化，所以解不唯一。
///
/// 每个盘面都按几何构造后用求解器确认过唯一解，结构声明里的额外候选是穷尽列出的；
/// 测试会独立复核环的每个房屋是不是恰好占两格、六格是不是都含底数对、
/// 除底数之外还剩什么，以及正文里的结论跟唯一解合不合。
List<TechniqueInfo> uniqueLoopTechniqueExamples() => [
      TechniqueInfo(
        id: 'ul1',
        name: '唯一环 1',
        summary: '六格偶环里一格多出候选，那一格就填它。',
        definition: '唯一环（Unique Loop）是把唯一矩形的四角拉长成六格及以上的偶环：'
            '环上相邻两格同行或同列，每一行、每一列、每一宫都正好占环上两格，'
            '于是两个底数可以沿着环交替换一遍，得到另一种合法排法。'
            '类型 1 是最直接的用法——环上只有一格比底数多出一个候选，'
            '其余格子都只剩底数，那个多出来的候选必须为真，否则整个环就成了死结。',
        howToSpot: '按底数对搜偶环：从一个只剩两个候选的格子出发，'
            '沿同行、同列交替走，看能不能六步走回原点，且每个房屋都只占两格。',
        walkthrough: '本例的环是 r3c7 → r3c8 → r5c8 → r5c9 → r7c9 → r7c7 → 回到 r3c7，'
            '六格都含底数对 `{3,7}`。r3、r5、r7 各占两格，c7、c8、c9 各占两格，'
            '右上、右中、右下三个宫也各占两格，所以 3 和 7 可以沿环交替对调。'
            'r7c7 是 `{2,3,7}`，比底数多出一个 2，其余五格恰好只剩 `{3,7}`。'
            '假设 2r7c7 为假，环上就只剩底数，交替对调会造出第二个解，'
            '所以 2r7c7 必须为真，r7c7 就填 2。',
        caveats: '偶环必须每个房屋都恰好占两格，占一格或占四格都不是唯一环，'
            '搜环时最容易在这一步出错。',
        rank: 551,
        examplePuzzle:
            '300009050208700490000865002704021009082094100900000604890006040400970005000450910',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [2, 6],
            [2, 7],
            [4, 7],
            [4, 8],
            [6, 8],
          ],
          targets: const [
            [6, 6],
          ],
          nodes: const [
            [2, 6, 3],
            [2, 6, 7],
            [2, 7, 3],
            [2, 7, 7],
            [4, 7, 3],
            [4, 7, 7],
            [4, 8, 3],
            [4, 8, 7],
            [6, 8, 3],
            [6, 8, 7],
            [6, 6, 3],
            [6, 6, 7],
          ],
          keys: const [
            [6, 6, 2],
          ],
          weakLinks: const [
            [2, 6, 2, 7, 3],
            [2, 7, 4, 7, 7],
            [4, 7, 4, 8, 3],
            [4, 8, 6, 8, 7],
            [6, 8, 6, 6, 3],
            [6, 6, 2, 6, 7],
          ],
        ),
        legend: [...structureLegend, targetLegendItem],
        structure: const TeachingStructure(
          family: TeachingFamily.uniqueLoop,
          claim: TeachingClaim.type1,
          baseDigits: {3, 7},
          cells: [
            CellRef(2, 6),
            CellRef(2, 7),
            CellRef(4, 7),
            CellRef(4, 8),
            CellRef(6, 8),
            CellRef(6, 6),
          ],
          extras: [CandidateRef(6, 6, 2)],
          conclusionTrue: [CandidateRef(6, 6, 2)],
        ),
      ),
      TechniqueInfo(
        id: 'ul2',
        name: '唯一环 2',
        summary: '环上两格多出同一个数字，删共同可见处。',
        definition: '唯一环类型 2 对应唯一矩形 2：环上恰好有两格除底数之外都多出同一个额外数字 c，'
            '其余格子只剩底数。这两格不可能都把 c 去掉，否则整个环只剩底数，'
            '两个底数沿环交替对调就会造出第二个解。'
            '所以 c 至少在这两格之一为真，同时看得见这两格的位置上，c 可以删。'
            '几何比矩形长，但用法一字不改。',
        howToSpot: '搜到偶环后先数额外候选：'
            '只有两格带额外候选、而且带的是同一个数字，就走类型 2。',
        walkthrough: '本例的环是 r3c7 → r3c8 → r5c8 → r5c9 → r7c9 → r7c7 → 回到 r3c7，'
            '六格都含底数对 `{5,6}`。额外候选恰好两个，而且都是 4：'
            'r3c7 是 `{4,5,6}`、r3c8 是 `{4,5,6}`，其余四格只剩 `{5,6}`。'
            '如果 4r3c7、4r3c8 同时为假，环上就只剩底数，5 和 6 沿环交替对调'
            '会造出第二个解。所以 4 至少落在这两格之一；'
            '同时看得见 r3c7 与 r3c8 的位置——r3 上的 r3c9 和右上宫里的 r1c7——都能删 4。',
        caveats: '两格多出来的必须是同一个数字；数字不同就得改走类型 3 的虚拟格，'
            '不能当成一般的裸对处理。删除范围只算同时看得见这两格的位置。',
        rank: 580,
        examplePuzzle:
            '750300028308240900201080000006700831040900000005000709403192080002000390000403172',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [2, 6],
            [2, 7],
            [4, 7],
            [4, 8],
            [6, 8],
            [6, 6],
          ],
          targets: const [
            [0, 6],
            [2, 8],
          ],
          nodes: const [
            [2, 6, 5],
            [2, 6, 6],
            [2, 7, 5],
            [2, 7, 6],
            [4, 7, 5],
            [4, 7, 6],
            [4, 8, 5],
            [4, 8, 6],
            [6, 8, 5],
            [6, 8, 6],
            [6, 6, 5],
            [6, 6, 6],
          ],
          keys: const [
            [2, 6, 4],
            [2, 7, 4],
          ],
          weakLinks: const [
            [2, 6, 2, 7, 4],
            [2, 7, 4, 7, 5],
            [4, 7, 4, 8, 6],
            [4, 8, 6, 8, 5],
            [6, 8, 6, 6, 6],
            [6, 6, 2, 6, 5],
          ],
        ),
        legend: [...structureLegend, targetLegendItem],
        structure: const TeachingStructure(
          family: TeachingFamily.uniqueLoop,
          claim: TeachingClaim.type2,
          baseDigits: {5, 6},
          cells: [
            CellRef(2, 6),
            CellRef(2, 7),
            CellRef(4, 7),
            CellRef(4, 8),
            CellRef(6, 8),
            CellRef(6, 6),
          ],
          extras: [CandidateRef(2, 6, 4), CandidateRef(2, 7, 4)],
          conclusionFalse: [CandidateRef(0, 6, 4), CandidateRef(2, 8, 4)],
        ),
      ),
      TechniqueInfo(
        id: 'ul4',
        name: '唯一环 4',
        summary: '环上底数之一成强链，删另一底数。',
        definition: '唯一环类型 4 对应唯一矩形 4（锁定型）：环上恰好两格带额外候选，而且这两格'
            '同在一个房屋里；如果某个底数在这个房屋里只剩环上这两格，它就形成强链。'
            '这个底数一定落在这两格之一，那另一格就只能去填自己多出来的候选，'
            '于是两格各自都只剩「这个底数」和「自己的额外候选」两种可能，'
            '另一个底数就可以从这两格删掉。判定顺序是先搜偶环，再在环经过的房屋里找底数强链。',
        howToSpot: '搜到偶环后，逐个底数数它在环经过的每一行、每一列、每一宫里的落点，'
            '看有没有哪个底数正好被锁在带额外候选的那两格上。',
        walkthrough: '本例的环是 r1c3 → r1c4 → r3c4 → r3c7 → r2c7 → r2c3 → 回到 r1c3，'
            '六格都含底数对 `{5,8}`。带额外候选的恰好是 c7 上的两格：'
            'r3c7 是 `{5,6,8}`、多出一个 6，r2c7 是 `{4,5,8}`、多出一个 4，'
            '所以 6r3c7 与 4r2c7 不可能同时为假。'
            '再看 c7：这一列里 5 只出现在 r3c7 和 r2c7，是一条强链。'
            '若 5 落在 r3c7，则 r3c7 不是 6，只好由 r2c7 填 4；'
            '若 5 落在 r2c7，则 r2c7 不是 4，只好由 r3c7 填 6。'
            '两种情形下 r3c7 只能是 5 或 6、r2c7 只能是 5 或 4，'
            '所以另一个底数 8 可以从这两格删掉。',
        caveats: '强链必须按当前候选现算；'
            '也别把「环上两格」和「区域里只剩两格」搞混，后者才是强链。',
        rank: 581,
        examplePuzzle:
            '600094723090763001473010009759000000002000190000000005807001950041250006500907008',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [0, 2],
            [0, 3],
            [2, 3],
            [1, 2],
          ],
          targets: const [
            [2, 6],
            [1, 6],
          ],
          nodes: const [
            [0, 2, 5],
            [0, 2, 8],
            [0, 3, 5],
            [0, 3, 8],
            [2, 3, 5],
            [2, 3, 8],
            [2, 6, 5],
            [1, 6, 5],
            [1, 2, 5],
            [1, 2, 8],
          ],
          keys: const [
            [2, 6, 6],
            [1, 6, 4],
          ],
          strongLinks: const [
            [2, 6, 1, 6, 5],
          ],
          weakLinks: const [
            [0, 2, 0, 3, 5],
            [0, 3, 2, 3, 8],
            [1, 2, 0, 2, 8],
          ],
        ),
        legend: const [
          TechniqueLegendItem(color: TeachingColors.pattern, label: '环上格'),
          TechniqueLegendItem(
              color: TeachingColors.elimCell, label: '带额外候选、结论落点'),
          TechniqueLegendItem(color: TeachingColors.node, label: '底数候选'),
          TechniqueLegendItem(color: TeachingColors.end, label: '多出来的候选'),
        ],
        structure: const TeachingStructure(
          family: TeachingFamily.uniqueLoop,
          claim: TeachingClaim.type4,
          baseDigits: {5, 8},
          lockDigit: 5,
          lockHouses: [15],
          cells: [
            CellRef(0, 2),
            CellRef(0, 3),
            CellRef(2, 3),
            CellRef(2, 6),
            CellRef(1, 6),
            CellRef(1, 2),
          ],
          extras: [CandidateRef(2, 6, 6), CandidateRef(1, 6, 4)],
          conclusionFalse: [CandidateRef(2, 6, 8), CandidateRef(1, 6, 8)],
        ),
      ),
      TechniqueInfo(
        id: 'ul3',
        name: '唯一环 3',
        summary: '环上两格的多余候选合成虚拟格，和同房屋的格子配数组。',
        definition: '唯一环类型 3 对应唯一矩形 3：环上有两格除底数之外还各带额外候选，'
            '而且这两格同处一个房屋。'
            '环不可能整条都只填底数，所以这两格里至少有一个要填自己的额外候选——'
            '把它们合起来当成一个「虚拟格」，虚拟格的候选就是那些额外数字。'
            '虚拟格算一格，再和同房屋其它格子配成数组：'
            'k 个格子（含虚拟格）锁住 k 个数字，这几个数字在这个房屋别处就能删。'
            '虚拟格背后是完整性约束，绝不能把额外候选拆开当裸对硬删。'
            '这一型的工作量最接近唯一矩形 3。',
        howToSpot: '搜到偶环后找只有两格带额外候选、而且这两格同房屋的情形，'
            '把两格的额外候选并成一格，再在这个房屋里找能配成数组的格子。',
        walkthrough: '本例的环是 r7c2 → r7c7 → r9c7 → r9c4 → r8c4 → r8c2 → 回到 r7c2，'
            '六格都含底数对 `{2,4}`：'
            'r7、r8、r9 各占两格，c2、c4、c7 各占两格，左下宫、中下宫、右下宫也各占两格。'
            '额外候选只有两个，都在 c4 上：r8c4 是 `{1,2,4}`，多出 1；'
            'r9c4 是 `{2,4,6}`，多出 6。'
            '把这两格合成一个候选为 `{1,6}` 的虚拟格；c4 上的 r1c4 恰好是 `{1,6}`，'
            '虚拟格加上它就是两格锁两个数字的裸数对，'
            '于是 1 和 6 在 c4 别处都能删：r2c4 的 1、r5c4 的 6。',
        caveats: '虚拟格只能整体参与数组；'
            '配数组的格子必须和虚拟格同处一个房屋，格数和锁住的数字个数也要正好相等。',
        rank: 600,
        examplePuzzle:
            '092008540650000000000500900060905000230004000000310050000700081000080760010000030',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [6, 1],
            [6, 6],
            [8, 6],
            [8, 3],
            [7, 3],
            [7, 1],
          ],
          cover: const [
            [0, 3],
          ],
          targets: const [
            [1, 3],
            [4, 3],
          ],
          nodes: const [
            [6, 1, 2],
            [6, 1, 4],
            [6, 6, 2],
            [6, 6, 4],
            [8, 6, 2],
            [8, 6, 4],
            [8, 3, 2],
            [8, 3, 4],
            [7, 3, 2],
            [7, 3, 4],
            [7, 1, 2],
            [7, 1, 4],
            [0, 3, 1],
            [0, 3, 6],
          ],
          keys: const [
            [7, 3, 1],
            [8, 3, 6],
          ],
          weakLinks: const [
            [6, 1, 6, 6, 2],
            [6, 6, 8, 6, 4],
            [8, 6, 8, 3, 2],
            [8, 3, 7, 3, 4],
            [7, 3, 7, 1, 2],
            [7, 1, 6, 1, 4],
            [7, 3, 0, 3, 1],
            [8, 3, 0, 3, 6],
          ],
        ),
        legend: [
          ...structureLegend,
          const TechniqueLegendItem(
              color: TeachingColors.cover, label: '配数组的格子'),
          targetLegendItem,
        ],
        structure: const TeachingStructure(
          family: TeachingFamily.uniqueLoop,
          claim: TeachingClaim.type3,
          baseDigits: {2, 4},
          cells: [
            CellRef(6, 1),
            CellRef(6, 6),
            CellRef(8, 6),
            CellRef(8, 3),
            CellRef(7, 3),
            CellRef(7, 1),
          ],
          extras: [CandidateRef(7, 3, 1), CandidateRef(8, 3, 6)],
          subsetCells: [CellRef(0, 3)],
          subsetDigits: {1, 6},
          conclusionFalse: [
            CandidateRef(1, 3, 1),
            CandidateRef(4, 3, 6),
          ],
        ),
      ),
    ];
