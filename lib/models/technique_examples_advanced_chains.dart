import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_catalog.dart';
import 'technique_examples_teaching_support.dart';
import 'technique_structure.dart';

const _deadLoopLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '圈上格'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '守卫格'),
  TechniqueLegendItem(color: TeachingColors.elimCell, label: '结论落点'),
  TechniqueLegendItem(color: TeachingColors.node, label: '圈上候选'),
  TechniqueLegendItem(color: TeachingColors.end, label: '守卫候选'),
];

const _dynamicLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '假设推出来的格'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '动态强链的两端'),
  TechniqueLegendItem(color: TeachingColors.elimCell, label: '被假设的那一格'),
  TechniqueLegendItem(color: TeachingColors.node, label: '动态强链候选'),
  TechniqueLegendItem(color: TeachingColors.end, label: '被否掉的假设'),
];

/// 链一侧还没有独立报法的两条：死环、动态 AIC。
///
/// 两个盘面都是随机完整解挖出来的唯一解题目。动态 AIC 那一条还多过一道筛子：
/// 盘面先被唯余摒除推到停，拿推停的局面当教学盘。
/// 这样教学页画出来的候选就是推理用的候选，「这个数字在这个区域里有几个落点」
/// 读者自己数得出来，也不会有现成的基础招式抢在假设前面。
///
/// 两条的结构声明都写进了 [TechniqueInfo.structure]，由
/// `teaching_structure_test` 拿盘面独立重算后逐条对齐：死环核对奇数圈几何、
/// 守卫穷尽与删除；动态 AIC 则要先证明那条强链静态时不存在，
/// 再复核假设之后它确实收成两格、两端各自矛盾。
/// 动态 AIC 的可行性仍是「否」——完整做出来就是分类强制网，
/// 这里只作教学，不进提示搜索顺序。
List<TechniqueInfo> advancedChainTechniqueExamples() => [
      TechniqueInfo(
        id: 'dead_loop',
        name: '死环',
        summary: '同数字的奇数圈，全强链走不通，守卫里必有一真。',
        definition: '死环（Broken Wing / 全强链奇数圈）针对同一个数字：'
            '取奇数个格子首尾相连成一圈，相邻两格同属一个区域，各条边的区域互不相同。'
            '每条边所在的区域里，除了圈上那两格，往往还留着别的落点，'
            '这些落点叫守卫。'
            '先把全部守卫假设为假：那么每条边的区域里这个数字就只剩圈上两格，'
            '每条边都成了真强链——「两端恰好一真一假」。'
            '沿圈走要真假交替，可奇数圈绕回起点时奇偶对不上，矛盾。'
            '所以守卫不可能全假，至少有一个为真；'
            '于是凡是同时看得见全部守卫的位置，都放不下这个数字。'
            '它和 Nice Loop 不是一回事：Nice Loop 是强弱交替的偶环，'
            '死环是「差一点全是强链」的奇环，结论落在守卫上而不是圈上。',
        howToSpot: '锁定一个数字，找奇数个格子连成的圈，各条边的区域要互不相同、'
            '而且每个区域只许占圈上两格；'
            '再把每条边所在区域里圈外的同名候选数清楚，那些就是守卫。'
            '守卫越少越好用——同时看得见它们全部的位置就是删除落点。',
        walkthrough: '本例观察数字 9。圈是 r4c4 → r4c8（同在 r4）→ r7c8（同在 c8）'
            '→ r7c6（同在 r7）→ r5c6（同在 c6）→ 回到 r4c4（同在中中宫），'
            '五条边、五个区域各不相同，每个区域里也只占了圈上两格，是个合格的奇数圈。\n'
            '数守卫：r4 上除 r4c4、r4c8 之外还有 9r4c7；'
            '中中宫里除 r4c4、r5c6 之外还有 9r5c5；'
            'r7 上除 r7c6、r7c8 之外还有 9r7c7。'
            'c8 与 c6 上的 9 恰好只有圈上那两格，不出守卫。'
            '所以守卫一共三个：r4c7、r5c5、r7c7。\n'
            '假设这三个都为假，五条边就全是真强链，9 沿圈真假交替，'
            '绕一圈回到起点必然自相矛盾。所以三个守卫里至少有一个是真的。'
            'r5c7 同时看得见这三格——它和 r4c7、r7c7 同在 c7，'
            '又和 r5c5 同在 r5——所以 9r5c7 可以删。'
            '（顺带说一句：这个盘面的答案里 r4c7 正是 9。）',
        caveats: '圈长必须是奇数，各条边的区域必须互不相同，'
            '而且每条边的区域里只许有它自己那两个圈上格——'
            '挤进第三个圈上格，「守卫全假之后只剩两格」就不成立，整套推理跟着塌掉。'
            '守卫还必须数得一个不漏：漏掉一个，「同时看得见全部守卫」的范围就会算大，'
            '删出错的候选。'
            '另外结论只是「守卫里至少一个为真」，不是「某个守卫一定为真」，'
            '也不是「圈上的候选可以删」。',
        rank: 651,
        examplePuzzle:
            '003000009800003000004008067570031000000600053039000700000840005010005070900017000',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [3, 3],
            [3, 7],
            [6, 7],
            [6, 5],
            [4, 5],
          ],
          cover: const [
            [3, 6],
            [4, 4],
            [6, 6],
          ],
          targets: const [
            [4, 6],
          ],
          nodes: const [
            [3, 3, 9],
            [3, 7, 9],
            [6, 7, 9],
            [6, 5, 9],
            [4, 5, 9],
          ],
          keys: const [
            [3, 6, 9],
            [4, 4, 9],
            [6, 6, 9],
          ],
          // 圈上的边故意不画成强链：正因为守卫还在，这五条边里必有一条不够强。
          weakLinks: const [
            [3, 3, 3, 7, 9],
            [3, 7, 6, 7, 9],
            [6, 7, 6, 5, 9],
            [6, 5, 4, 5, 9],
            [4, 5, 3, 3, 9],
          ],
        ),
        legend: _deadLoopLegend,
        structure: const TeachingStructure(
          family: TeachingFamily.guardedOddCycle,
          claim: TeachingClaim.elimination,
          fishDigit: 9,
          cells: [
            CellRef(3, 3),
            CellRef(3, 7),
            CellRef(6, 7),
            CellRef(6, 5),
            CellRef(4, 5),
          ],
          // 按边的顺序：r4、c8、r7、c6、中中宫。
          lockHouses: [3, 16, 6, 14, 22],
          guards: [
            CandidateRef(3, 6, 9),
            CandidateRef(4, 4, 9),
            CandidateRef(6, 6, 9),
          ],
          conclusionFalse: [CandidateRef(4, 6, 9)],
        ),
      ),
      TechniqueInfo(
        id: 'dynamic_aic',
        name: '动态 AIC',
        summary: '假设之后新长出来的强弱链也能接着走。',
        definition: '动态 AIC 放宽了普通交替推理链的一条规矩：'
            '普通 AIC 只能用盘面当前就存在的强链和弱链，'
            '动态 AIC 允许先假设某个候选成立，把这个假设的后果填进去，'
            '再用「填进去之后新长出来的」强弱关系继续接链。'
            '好处是链能走得更远，坏处是每往前一步都要重算一遍盘面，'
            '而且没法穷尽。完整做出来其实就是分类强制网，'
            '因此只作教学说明，不纳入提示。',
        howToSpot: '普通 AIC 走到断头时，把手上那个候选先当真填进去，'
            '顺着唯余摒除推几格，再看有没有哪个区域里某个数字刚好收成了两个落点——'
            '那就是一条新长出来的强链，接上它继续走。'
            '关键是要能说清「这条强链假设之前没有」，否则只是漏看了一条静态强链。',
        walkthrough: '这张盘面上唯余、摒除都已经用尽。假设 8r1c7 为真，看它能不能站得住。\n'
            '先看静态的盘面，观察 r5 上的 4：落点是 r5c4、r5c7、r5c8 三格。'
            '三个落点连不成强链，普通 AIC 到这里就没有可用的下一节了；'
            '把唯余摒除推到底也一样，4 在 r5 上仍是三个落点。\n'
            '现在把假设填进去，一路只用唯余和摒除：'
            'r1c7=8 → r1c8=4（r1 里的 4 只剩这一格）→ r1c9=1 → r7c7=1 → r4c8=1。'
            '要紧的是第二格：r1c8=4 把 c8 上的 4 清了，'
            '4r5c8 跟着没了，于是 4 在 r5 上只剩 r5c4 与 r5c7 两格——'
            '这条强链是刚刚长出来的，静态时并不存在。\n'
            '沿这条新强链分成两种情况：'
            '4r5c4 为真 → r5c2=5 → r6c2=3 → r4c2=8 → r4c4=5，矛盾；'
            '4r5c7 为真 → r9c7=3 → r9c8=2 → r2c8=6，也矛盾。'
            '强链的两端都走不通，说明这条强链本身立不住，'
            '也就是说造出它的那个假设是错的：8r1c7 可以删。'
            '（答案里 r1c7 填的是 4。）\n'
            '值得比一比：不借这条动态强链，光凭唯余摒除一路盲推，'
            '要填到第十二格才撞出矛盾。动态强链把它压到了「五格 + 两种情况各不到五格」，'
            '这就是它换来的东西。',
        caveats: '动态 AIC 最容易糊掉的地方是「这条强链本来就在」：'
            '不先把唯余摒除推到底确认它静态时不成立，'
            '整页就只是给一条普通强链换了个说法。'
            '每假设一步都要重算盘面，链越长越容易记错状态；'
            '而且分支一多就没法穷尽——完整做出来其实就是分类强制网，'
            '所以可行性判成「否」，只作教学，不进提示搜索顺序。',
        rank: 851,
        examplePuzzle:
            '725060000194875003368142005407036000201090000906010500642050080813024056579681004',
        exampleMarkup: schematicMarkup(
          // 假设之后被唯余摒除逼出来的那几格，r1c8 是关键的一格。
          pattern: const [
            [0, 7],
            [0, 8],
            [6, 6],
            [3, 7],
          ],
          cover: const [
            [4, 3],
            [4, 6],
          ],
          targets: const [
            [0, 6],
          ],
          nodes: const [
            [4, 3, 4],
            [4, 6, 4],
            [0, 7, 4],
          ],
          keys: const [
            [0, 6, 8],
            [4, 7, 4],
          ],
          // 假设之后 4 在 r5 上只剩这两格，这一段正是那条动态强链。
          weakLinks: const [
            [4, 3, 4, 6, 4],
          ],
        ),
        legend: _dynamicLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.dynamicChain,
          claim: TeachingClaim.elimination,
          replayBudget: 5,
          assumption: DynamicAssumption(
            assume: CandidateRef(0, 6, 8),
            linkDigit: 4,
            linkHouse: 4,
            linkCells: [CellRef(4, 3), CellRef(4, 6)],
            staticSpots: 3,
          ),
          conclusionFalse: [CandidateRef(0, 6, 8)],
        ),
      ),
    ];
