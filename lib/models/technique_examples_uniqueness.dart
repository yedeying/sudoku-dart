import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_catalog.dart';
import 'technique_examples_teaching_support.dart';
import 'technique_structure.dart';

/// 唯一矩形家族里另外五条：不完整唯一矩形、可规避矩形、隐性唯一矩形、探长、淑芬。
/// 前三条已经接进 `getHint`，探长和淑芬还只有教学页。
///
/// 五个盘面都是按几何反过来造的：先挑一个完整解，再按「这一格的候选必须恰好是这些」
/// 把多余的给定数挖掉，最后用求解器确认唯一解。每条都带 [TechniqueInfo.structure]，
/// 测试会独立复核几何、额外候选是否穷尽、结构是否真的可以整组换一种填法，
/// 以及页面上的结论跟唯一解合不合。
List<TechniqueInfo> uniquenessTechniqueExamples() => [
      TechniqueInfo(
        id: 'incomplete_ur',
        name: '不完整唯一矩形',
        summary: '四角不必都还留着底数对，删过的候选不算堵死。',
        definition: '不完整唯一矩形（Incomplete Unique Rectangle）和标准唯一矩形是同一个矩形：'
            '两行两列四个角，落在两个宫里，底数是同一对 `{a,b}`。'
            '致命性的来龙去脉只跟「整块对调后的排法有没有违反题目规则」有关，'
            '所以真正的条件是：没有任何**给定数**挡住某个角填某个底数。'
            '之前几步推出来的删除并不算挡路——那是在「题目唯一解」这个前提下推出来的结论，'
            '而整块对调造出来的第二个解只需要不跟给定数冲突。'
            '现有类型 1–4 都要求四角当下都完整留着底数对，'
            '会漏掉那些先前已经删掉过一个底数的盘面。',
        howToSpot: '先按老办法找四角同宫成对的矩形，再把「某个角已经少了一个底数」的情况也放进来；'
            '关键是逐个角检查它的行、列、宫里有没有给定数挡住底数，'
            '而不是看候选表当下还剩什么。',
        walkthrough: '本例的矩形是 r5c2、r5c5、r6c2、r6c5，四角落在左中宫和中中宫两个宫里，'
            '底数对是 `{5,6}`。现在 r5c2、r5c5 干净地只剩 `{5,6}`，'
            'r6c2 多出 1、r6c5 多出 2。四角不可能都只填 5、6：'
            '那样把两行的 5、6 整块对调就会得到第二个解。'
            '所以 1r6c2 与 2r6c5 里至少有一个为真（唯一解里两个都为真）。'
            '不完整型关心的是这条推理站得住的真正理由：'
            '对调出来的那第二个盘面只需要不跟**给定数**冲突，'
            '而 r5c2、r5c5、r6c2、r6c5 四格的行、列、宫里都没有给定的 5 或 6，'
            '退路一直是通的。'
            '所以对局中即使某一步已经把某个角上的一个底数删掉、'
            '让类型 1–4 的认形条件不再满足，'
            '这个矩形依旧致命，1r6c2 与 2r6c5 至少一个为真的结论照样成立。'
            '这就是「不完整」放宽的那一格：认形看给定数，不看候选表当下剩下什么。',
        caveats: '静态教学盘只存得下给定数算出来的候选，存不下「这个候选是第几步删掉的」，'
            '所以图上画的是四角完整的样子。'
            '实战里放宽认形之后，一定要把每个角的行、列、宫翻一遍确认底数没被给定数挡住，'
            '否则很容易把一个本来就不致命的矩形当成致命结构。',
        rank: 352,
        examplePuzzle:
            '040000000081200000000587010000030001209401700007000000005006002030800500000090004',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [4, 1],
            [4, 4],
            [5, 1],
            [5, 4],
          ],
          nodes: const [
            [4, 1, 5],
            [4, 1, 6],
            [4, 4, 5],
            [4, 4, 6],
            [5, 1, 5],
            [5, 1, 6],
            [5, 4, 5],
            [5, 4, 6],
          ],
          keys: const [
            [5, 1, 1],
            [5, 4, 2],
          ],
          weakLinks: const [
            [4, 1, 4, 4, 5],
            [5, 1, 5, 4, 6],
            [4, 1, 5, 1, 6],
            [4, 4, 5, 4, 5],
          ],
        ),
        legend: structureLegend,
        structure: const TeachingStructure(
          family: TeachingFamily.uniqueRect,
          baseDigits: {5, 6},
          cells: [
            CellRef(4, 1),
            CellRef(4, 4),
            CellRef(5, 1),
            CellRef(5, 4),
          ],
          extras: [CandidateRef(5, 1, 1), CandidateRef(5, 4, 2)],
          boxSpan: 2,
        ),
      ),
      TechniqueInfo(
        id: 'avoidable_rect',
        name: '可规避矩形',
        summary: '矩形里已填的角必须是玩家填的，不能是给定数。',
        definition: '可规避矩形（Avoidable Rectangle）的几何和唯一矩形完全一样：两行两列四个角，'
            '落在两个宫里，底数是同一对 `{a,b}`。不同的是这里有角已经填上了数字，'
            '而这个数字必须是玩家自己推出来填的，不能是题目给定数。'
            '玩家填进去的数是从唯一解推出来的，把两行整块对调仍然只跟给定数打交道，'
            '所以第二个解照样造得出来，结构仍然致命；'
            '给定数就不一样了——它本身就把对调堵死，对调造不出第二个解，也就谈不上致命结构。',
        howToSpot: '扫矩形时把已填的角一起算进来，再用 `isInitial` 过一遍：'
            '四个角里只要有一个是题目给定数，这个矩形就不能用。',
        walkthrough: '本例的矩形是 r7c3、r7c6、r8c3、r8c6，四角落在左下宫和中下宫两个宫里，'
            '底数对是 `{5,6}`。教学盘上四个角都还空着，'
            'r7c3、r7c6 只剩 `{5,6}`，r8c3 多出 4、r8c6 多出 2。'
            '唯一解里 r7c3 填 5——注意这个 5 在题目里并不是给定数，'
            '所以对局中它一定是你自己推出来填进去的。'
            '填完的那一刻这个矩形就成了可规避矩形：'
            '剩下三个角要是再凑成 `{5,6}` 的另一种排法，两行整块对调就会造出第二个解，'
            '所以 4r8c3 与 2r8c6 里至少有一个为真。'
            '反过来说，如果 r7c3 的 5 是题目印上去的给定数，这一招就不能用。',
        caveats: '判断的关键全在「这个角是谁填的」。'
            '静态教学盘存不下走子记录，只能像这里一样先确认四个角在题目里都不是给定数、'
            '再指出唯一解会让哪个角落上底数；'
            '实战里盘面重开或读档后如果丢了 `isInitial`，就不能再报可规避矩形。',
        rank: 353,
        examplePuzzle:
            '040903200500060300003007410008000000000050000307008005090340102100000009002000800',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [6, 2],
            [6, 5],
            [7, 2],
            [7, 5],
          ],
          nodes: const [
            [6, 2, 5],
            [6, 2, 6],
            [6, 5, 5],
            [6, 5, 6],
            [7, 2, 5],
            [7, 2, 6],
            [7, 5, 5],
            [7, 5, 6],
          ],
          keys: const [
            [7, 2, 4],
            [7, 5, 2],
          ],
          weakLinks: const [
            [6, 2, 6, 5, 5],
            [7, 2, 7, 5, 6],
            [6, 2, 7, 2, 6],
            [6, 5, 7, 5, 5],
          ],
        ),
        legend: structureLegend,
        structure: const TeachingStructure(
          family: TeachingFamily.avoidableRect,
          baseDigits: {5, 6},
          cells: [
            CellRef(6, 2),
            CellRef(6, 5),
            CellRef(7, 2),
            CellRef(7, 5),
          ],
          extras: [CandidateRef(7, 2, 4), CandidateRef(7, 5, 2)],
          filledCorner: CellRef(6, 2),
          filledDigit: 5,
          boxSpan: 2,
        ),
      ),
      TechniqueInfo(
        id: 'hidden_ur',
        name: '隐性唯一矩形',
        summary: '靠两条底数强链把对角格逼回底数，删另一个底数。',
        definition: '隐性唯一矩形（Hidden Unique Rectangle）说的是同一个两行两列四角矩形，'
            '但只有对角那一格干净地剩下底数对，其余角还挂着别的候选。'
            '认它要反过来数「底数还能落在哪」：'
            '如果底数 b 在带额外候选那一格所在的行、列里都只剩矩形上的两个位置，'
            '那 b 就成了两条强链，把这一格逼得只能在底数里选，'
            '于是这一格上的另一个底数 a 可以删——'
            '否则 a 一旦落下，四角就凑成 `{a,b}` 的死结。'
            '有的资料把它叫类型 6。它和锁定唯一矩形（唯一矩形 4）不是一回事：'
            '锁定型锁的是结构所在的一条线，隐性型靠的是对角格上的两条强链。',
        howToSpot: '别只盯候选恰好两个的格子，改成按底数扫两行两列的落点：'
            '找那种「只有对角一格干净、而某个底数在另一格的行列里都只剩两个位置」的矩形。',
        walkthrough: '本例的矩形是 r1c2、r1c6、r2c2、r2c6，落在左上宫和中上宫，'
            '底数对是 `{5,9}`。r1c6、r2c2、r2c6 都干净地只剩 `{5,9}`，'
            '只有 r1c2 挂着一个 3，成了 `{3,5,9}`。'
            '现在数 5 的落点：r1 上 5 只能在 r1c2 和 r1c6，c2 上 5 只能在 r1c2 和 r2c2，'
            '两条都是强链。假设 9r1c2 为真，r1c6 与 r2c2 就都只能是 5，'
            'r2c6 只剩 9，四角正好凑成 `{5,9}` 的一种排法，整块对调就有第二个解。'
            '所以 9r1c2 为假，可以删掉——r1c2 只剩 `{3,5}`。',
        caveats: '两条强链都要按当前候选现算，'
            '而且对角那一格必须干净地只剩底数对，少了这个前提推理就断了。',
        rank: 452,
        examplePuzzle:
            '008000604002360000000841503246007900010050000070403000009000000500000000004592800',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [0, 1],
            [0, 5],
            [1, 1],
            [1, 5],
          ],
          targets: const [
            [0, 1],
          ],
          nodes: const [
            [0, 1, 5],
            [0, 1, 9],
            [0, 5, 5],
            [0, 5, 9],
            [1, 1, 5],
            [1, 1, 9],
            [1, 5, 5],
            [1, 5, 9],
          ],
          keys: const [
            [0, 1, 3],
          ],
          strongLinks: const [
            [0, 1, 0, 5, 5],
            [0, 1, 1, 1, 5],
          ],
          weakLinks: const [
            [1, 1, 1, 5, 9],
            [0, 5, 1, 5, 9],
          ],
        ),
        legend: [...structureLegend, targetLegendItem],
        structure: const TeachingStructure(
          family: TeachingFamily.uniqueRect,
          claim: TeachingClaim.hiddenRect,
          baseDigits: {5, 9},
          cells: [
            CellRef(0, 1),
            CellRef(0, 5),
            CellRef(1, 1),
            CellRef(1, 5),
          ],
          extras: [CandidateRef(0, 1, 3)],
          lockDigit: 5,
          lockHouses: [0, 10],
          boxSpan: 2,
          conclusionFalse: [CandidateRef(0, 1, 9)],
        ),
      ),
      TechniqueInfo(
        id: 'bdp',
        name: '探长',
        summary: '宫内直角三格加两截延伸，七格三数的致命形。',
        definition: '探长（Borescoper\'s Deadly Pattern，BDP，也写作三数／四数探长）'
            '把唯一矩形的四角换成一个直角框架：'
            '在一个宫里按两行两列取三格组成直角，'
            '直角占的那两行再伸到宫外同一列上各取一格，'
            '直角占的那两列也伸到宫外同一行上各取一格，一共七格，横跨三个宫，'
            '七格都只含同一组三个底数（四数探长是四个数）。'
            '这样数下来，恰好有一行、一列、一宫各占三格，另有两行两列两宫各占两格；'
            '这批格子里的底数可以整组换一种排法而盘外毫无变化，所以是致命结构。'
            '用法完全照搬唯一矩形 1–4：只多一个候选就填它，'
            '同一个数字多在两格就删共同可见处，底数成强链就删另一个底数。',
        howToSpot: '先在一个宫里找候选很少的三格直角，'
            '再顺着直角的两行、两列各往宫外找一格，'
            '看这七格的候选并集是不是只有三个（或四个）数字。',
        walkthrough: '本例的七格是右下宫里的直角 r7c8、r7c7、r9c8，'
            '加上顺着 r7、r9 伸到 c3 的 r7c3、r9c3，'
            '以及顺着 c8、c7 伸到 r2 的 r2c8、r2c7，横跨右下宫、左下宫、中上宫三个宫。'
            '七格的底数都是 `{2,8,9}`：占三格的是 r7、c8 和右下宫，'
            '占两格的是 r9、r2、c7、c3、左下宫、中上宫。'
            '七格里只有 r2c7 多出一个 6，其余六格都只剩 `{2,8,9}`。'
            '要是 6r2c7 为假，这七格就只剩三个底数，整组能换一种排法而盘外看不出差别，'
            '题目就有两个解。所以 6r2c7 必须为真，r2c7 填 6——这正是探长的类型 1 用法。',
        caveats: '探长的几何比矩形松，容易和 XY-Wing、W-Wing 混在一起。'
            '认形时要把「一行一列一宫各占三格、另有两行两列两宫各占两格」逐条数一遍，'
            '数不对就不是探长，整组对调也走不通。',
        rank: 601,
        examplePuzzle:
            '000000153004700000950000000005006009086059000000300570070600001010000360030000004',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [6, 7],
            [6, 6],
            [8, 7],
            [6, 2],
            [8, 2],
            [1, 7],
          ],
          targets: const [
            [1, 6],
          ],
          nodes: const [
            [6, 7, 2],
            [6, 7, 8],
            [6, 7, 9],
            [6, 6, 2],
            [6, 6, 8],
            [6, 6, 9],
            [8, 7, 2],
            [8, 7, 8],
            [8, 7, 9],
            [6, 2, 2],
            [6, 2, 8],
            [6, 2, 9],
            [8, 2, 2],
            [8, 2, 8],
            [8, 2, 9],
            [1, 7, 2],
            [1, 7, 8],
            [1, 7, 9],
            [1, 6, 2],
            [1, 6, 8],
            [1, 6, 9],
          ],
          keys: const [
            [1, 6, 6],
          ],
          weakLinks: const [
            [6, 7, 6, 6, 9],
            [6, 7, 8, 7, 2],
            [6, 7, 6, 2, 8],
            [8, 7, 8, 2, 9],
            [1, 7, 1, 6, 9],
          ],
        ),
        legend: [...structureLegend, targetLegendItem],
        structure: const TeachingStructure(
          family: TeachingFamily.borescoper,
          claim: TeachingClaim.type1,
          baseDigits: {2, 8, 9},
          cells: [
            CellRef(6, 7),
            CellRef(6, 6),
            CellRef(8, 7),
            CellRef(6, 2),
            CellRef(8, 2),
            CellRef(1, 7),
            CellRef(1, 6),
          ],
          extras: [CandidateRef(1, 6, 6)],
          conclusionTrue: [CandidateRef(1, 6, 6)],
        ),
      ),
      TechniqueInfo(
        id: 'qdp',
        name: '淑芬',
        summary: '两条整线加线外同宫两格，线外那格必须跳出底数。',
        definition: '淑芬（Qiu\'s Deadly Pattern，QDP，也叫邱少）是唯一结构系里最难认的几何。'
            '它的结构是：同一个大行里两条整行 L1、L2 上的全部空格，'
            '外加线外的两格 C1、C2。C1、C2 要同宫、要同排（横放），'
            '而且既不在 L1、L2 上，也不在这两条线所在的大行里；'
            '竖放时把行换成列，说法一样。'
            '底数取 2 到 4 个：C1、C2 各自看得见的线上空格并起来是四个交点格，'
            '它们一定同处一个宫 B，而每个底数在 B 里只能落在这几个交点格上。'
            '这些条件凑齐之后，一旦 C1、C2 都只填底数，'
            '两条线上的数字就能换一种排法而所有区域用掉的数字分毫不变，题目会有第二个解。'
            '所以只要 C1、C2 里只有一格带着底数以外的候选，那一格就必须跳出底数——'
            '这是淑芬的类型 1，另外还有类型 3、类型 4 以及锁定、外延、双淑芬等变形。',
        howToSpot: '先挑同一个大行里的两条行，看它们的空格是不是够少、'
            '再找线外同宫同排的两格，检查这两格的候选是不是只有两到四个底数；'
            '最后数底数在交点宫里的落点，必须只剩那四个交点格。',
        walkthrough: '本例的两条线是 r1、r2，线外两格是 r7c4 与 r7c5：同在中下宫、同在 r7 这一行，'
            '既不在两条线上，也不在这两条线所在的大行里。'
            '交点格是 r1c4、r1c5、r2c4、r2c5，四格同处中上宫，'
            '候选都是 `{1,2,3,8}`，而 1、2、3、8 在中上宫里也只能落在这四格上——'
            '底数就是 `{1,2,3,8}`。'
            'r7c4 干净地只剩 `{1,2,3,8}`，r7c5 是 `{1,2,3,5,8}`，多出一个 5。'
            '假设 5r7c5 为假，r7c4 与 r7c5 就都只填底数，'
            '这时 r1、r2 两条线连同这两格可以换一种排法：'
            '每一行、每一列、每一宫用掉的数字完全一样，盘外一点变化都没有，题目就有两个解。'
            '所以 5r7c5 必须为真，r7c5 上的 1、2、3、8 全部可删。',
        caveats: '淑芬的七条特征必须一条条数齐，尤其是「底数在交点宫里只能落在交点格上」——'
            '漏掉这一条，两条线就换不成另一种排法，结论也就不成立。'
            '这个结构在实战里极其罕见，四数型大约万里挑一，三数型更少。',
        rank: 700,
        examplePuzzle:
            '050004060000009005000670123001508200006002010407000500004000007000060000800090600',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [6, 3],
            [6, 4],
          ],
          cover: const [
            [0, 3],
            [0, 4],
            [1, 3],
            [1, 4],
          ],
          targets: const [
            [6, 4],
          ],
          nodes: const [
            [6, 3, 1],
            [6, 3, 2],
            [6, 3, 3],
            [6, 3, 8],
            [6, 4, 1],
            [6, 4, 2],
            [6, 4, 3],
            [6, 4, 8],
            [0, 3, 1],
            [0, 3, 2],
            [0, 3, 3],
            [0, 3, 8],
            [0, 4, 1],
            [0, 4, 2],
            [0, 4, 3],
            [0, 4, 8],
            [1, 3, 1],
            [1, 3, 2],
            [1, 3, 3],
            [1, 3, 8],
            [1, 4, 1],
            [1, 4, 2],
            [1, 4, 3],
            [1, 4, 8],
          ],
          keys: const [
            [6, 4, 5],
          ],
          weakLinks: const [
            [0, 3, 0, 4, 1],
            [1, 3, 1, 4, 2],
            [0, 3, 1, 3, 3],
            [0, 4, 1, 4, 8],
            [6, 3, 6, 4, 1],
          ],
        ),
        legend: [
          ...structureLegend,
          const TechniqueLegendItem(color: TeachingColors.cover, label: '交点格'),
          targetLegendItem,
        ],
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.qiu,
          claim: TeachingClaim.qiuType1,
          baseDigits: {1, 2, 3, 8},
          cells: [
            CellRef(6, 3),
            CellRef(6, 4),
          ],
          freeCells: [
            CellRef(0, 0),
            CellRef(0, 2),
            CellRef(0, 3),
            CellRef(0, 4),
            CellRef(0, 6),
            CellRef(0, 8),
            CellRef(1, 0),
            CellRef(1, 1),
            CellRef(1, 2),
            CellRef(1, 3),
            CellRef(1, 4),
            CellRef(1, 6),
            CellRef(1, 7),
          ],
          extras: [CandidateRef(6, 4, 5)],
          conclusionFalse: [
            CandidateRef(6, 4, 1),
            CandidateRef(6, 4, 2),
            CandidateRef(6, 4, 3),
            CandidateRef(6, 4, 8),
          ],
        ),
      ),
    ];
