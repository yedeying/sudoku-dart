import 'board_markup.dart';
import 'technique_catalog.dart';
import 'technique_examples_teaching_support.dart';
import 'technique_structure.dart';

/// 「强制」系列的教学盘面：强制唯一矩形、强制扩展矩形、强制唯一环。
///
/// 强制的意思是拿致命结构的多余候选当分支：结构不可能只填底数，
/// 所以「哪个多余候选为真」就是一份穷尽的分类清单；
/// 每支只沿唯一后果（某格只剩一个候选、某数字在某区域只剩一个位置）往下推，
/// 各支都推得出来的结论才能落笔。
/// 它和「待定」系列的区别在于——待定把多余候选当链节点接着走，
/// 强制是分情况穷举再取交集。
///
/// 三个盘面都是按几何反过来造的唯一解题目，而且是照着「页面上这张盘」挑的：
/// * 每支假设都从页面画出来的候选起步，不许先替读者把唯余摒除推一遍；
/// * 每支只许往下填 `replayBudget` 格，正文把这几步逐格抄了下来；
/// * 不加假设、光靠唯余摒除盲推同样多格，页面上写的结论一条都拿不到。
/// 这三条由 `forcingViolations` 逐条复核，盘面本身也挑的是唯余摒除很快就卡住的，
/// 免得读者顺手填几个单元就换了张盘。
List<TechniqueInfo> forcingPatternTechniqueExamples() => [
      TechniqueInfo(
        id: 'forcing_ur',
        name: '强制唯一矩形',
        summary: '每个多余候选各成一支假设，取各支共同的删除。',
        definition: '强制唯一矩形（Forcing Unique Rectangle）以唯一矩形的多余候选为分岔点：'
            '四角落在两行两列两个宫里、都含同一对底数时，四角不可能都只填底数，'
            '所以「多余候选里哪一个为真」构成一份穷尽的分类清单。'
            '把每个多余候选各当一支假设，只沿唯一后果往下推，'
            '凡是每一种情况都推得出来的删除，就可以落笔。'
            '它和待定唯一矩形不是一回事——待定是把多余候选当成一个链节点接着走，'
            '强制是分情况穷举再取交集，所以力度更大，但覆盖的盘面也更宽。',
        howToSpot: '先确认四角同宫成对、底数一致的矩形，'
            '再把四角上的每个多余候选各列成一支假设，看各支能不能推到同一个结论。',
        walkthrough: '本例的矩形是 r4c3、r4c7、r6c3、r6c7，落在左中宫和右中宫，'
            '底数对是 `{4,6}`。r4c3 已经干净地只剩 `{4,6}`，'
            '多余候选一共三个：2r4c7、3r6c3、1r6c7。'
            '四角不可能都只剩 4、6——那样两行整块对调就有第二个解，'
            '所以这三个候选里必有一个为真，三支假设正好穷尽所有情况。'
            '情况一假设 2r4c7：r4c7=2 → r5c2=2（左中宫摒除）→ r5c9=3（r5 摒除）'
            '→ r7c9=1（唯余）→ r2c8=1（r2 摒除）→ r6c7=1（r6 摒除）。'
            '情况二假设 3r6c3：r6c3=3 → r5c9=3（右中宫摒除）→ r7c9=1（唯余）'
            '→ r2c8=1（r2 摒除）→ r6c7=1（r6 摒除）→ r7c7=5（唯余）。'
            '情况三假设 1r6c7：这一种情况开门就是 r6c7=1。'
            '三支都落到同一句话上——r6c7 只能填 1。'
            '于是 1 在 r6 和 c7 上别处都待不住：r6c9 从 `{1,3,4,6}` 缩到 `{3,4,6}`，'
            'r7c7 本来是 `{1,5}`，删掉 1 就只剩 5，顺手也填出来了。',
        caveats: '分支必须穷尽——多余候选漏列一个，剩下的交集就不能代表全部情况；'
            '每支只能沿唯一后果推，不能顺手带上别的假设。'
            '还要看住两头：某一支要是一填就矛盾，那个候选直接删掉更省事，'
            '用不着绕一圈；结论要是不用假设、光靠唯余摒除就掉下来了，'
            '这一页就白讲了。',
        rank: 752,
        examplePuzzle:
            '369001000000069300018000000080130095701000080000200070002706040005004008000000009',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [3, 2],
            [3, 6],
            [5, 2],
            [5, 6],
          ],
          targets: const [
            [5, 8],
            [6, 6],
          ],
          nodes: const [
            [3, 2, 4],
            [3, 2, 6],
            [3, 6, 4],
            [3, 6, 6],
            [5, 2, 4],
            [5, 2, 6],
            [5, 6, 4],
            [5, 6, 6],
          ],
          keys: const [
            [3, 6, 2],
            [5, 2, 3],
            [5, 6, 1],
          ],
          weakLinks: const [
            [3, 2, 3, 6, 4],
            [5, 2, 5, 6, 6],
            [3, 2, 5, 2, 6],
            [3, 6, 5, 6, 4],
          ],
        ),
        legend: [...structureLegend, targetLegendItem],
        teachingOnly: false,
        structure: const TeachingStructure(
          family: TeachingFamily.uniqueRect,
          claim: TeachingClaim.forcing,
          baseDigits: {4, 6},
          cells: [
            CellRef(3, 2),
            CellRef(3, 6),
            CellRef(5, 2),
            CellRef(5, 6),
          ],
          extras: [
            CandidateRef(3, 6, 2),
            CandidateRef(5, 2, 3),
            CandidateRef(5, 6, 1),
          ],
          boxSpan: 2,
          replayBudget: 6,
          conclusionTrue: [CandidateRef(5, 6, 1)],
          conclusionFalse: [
            CandidateRef(5, 8, 1),
            CandidateRef(6, 6, 1),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'forcing_er',
        name: '强制扩展矩形',
        summary: '六格结构的每个多余候选各成一支，取各支共同的删除。',
        definition: '强制扩展矩形（Forcing Extended Rectangle）把分支的对象换成六格扩展矩形：'
            '两条同向的线各三格、落在两个宫里、六格都含同一组三个底数。'
            '六格不可能都只填底数，所以多余候选同样构成一份穷尽的分类清单，'
            '每个多余候选各成一支假设，各支只沿唯一后果往下推，取共同的删除。'
            '几何比四角矩形多两格，多余候选往往也更多，工程量更大；'
            '但判定逻辑和强制唯一矩形完全一致。',
        howToSpot: '先按扩展矩形认六格几何，再把每个多余候选各列成一支假设，'
            '看各支是不是都推到同一个结论。',
        walkthrough: '本例的六格是 c5 上的 r4c5、r5c5、r6c5 和 c9 上的 r4c9、r5c9、r6c9，'
            '落在中中宫和右中宫两个宫里，六格都含底数 `{2,5,8}`。'
            'r5c5、r6c5、r5c9 干净地只剩 `{2,5,8}`，多余候选有三个：'
            '1r4c9、3r6c9、4r4c5。'
            '六格若只剩三个底数，两条线上的 2、5、8 就能整块换一种排法，'
            '所以这三个候选里必有一个为真。'
            '情况一假设 1r4c9：r4c9=1 → r7c8=1（c8 摒除）→ r9c3=1（c3 摒除）'
            '→ r8c4=1（c4 摒除）→ r2c5=1（c5 摒除）→ r2c6=6（r2 摒除）。'
            '情况二假设 3r6c9：r6c9=3 → r9c7=3（右下宫摒除）→ r9c9=2（r9 摒除）'
            '→ r7c9=6（c9 摒除）。'
            '情况三假设 4r4c5：r4c5=4 → r7c4=4（r7 摒除）→ r8c4=1（c4 摒除）'
            '→ r2c5=1（c5 摒除）→ r2c6=6（r2 摒除）→ r7c3=9（r7 摒除）'
            '→ r9c3=1（c3 摒除）→ r7c2=5（r7 摒除）。'
            '情况一和情况三都把 1 钉在 r9c3 上，情况二干脆把 r9c9 填成了 2——'
            '三种情况下 r9c9 都不可能是 1，'
            '所以 1r9c9 可以删：r9c9 从 `{1,2,3,6,7,8}` 缩到 `{2,3,6,7,8}`。',
        caveats: '六格几何要先坐实，两条线上每一格都得含全部三个底数；'
            '多余候选比四角矩形多，漏列一个交集就不成立。'
            '这一页的三支分别走了 6、4、8 格，都在声明的上限之内；'
            '页面这张盘面上唯余摒除只走五格就卡住了，所以这个删除确实得靠分支才拿得到。',
        rank: 780,
        examplePuzzle:
            '006090100000800004100700689030007000090301460410600700300002000264000950000500040',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [3, 4],
            [4, 4],
            [5, 4],
            [3, 8],
            [4, 8],
            [5, 8],
          ],
          targets: const [
            [8, 8],
          ],
          nodes: const [
            [3, 4, 2],
            [3, 4, 5],
            [3, 4, 8],
            [4, 4, 2],
            [4, 4, 5],
            [4, 4, 8],
            [5, 4, 2],
            [5, 4, 5],
            [5, 4, 8],
            [3, 8, 2],
            [3, 8, 5],
            [3, 8, 8],
            [4, 8, 2],
            [4, 8, 5],
            [4, 8, 8],
            [5, 8, 2],
            [5, 8, 5],
            [5, 8, 8],
          ],
          keys: const [
            [3, 8, 1],
            [5, 8, 3],
            [3, 4, 4],
          ],
          weakLinks: const [
            [3, 4, 3, 8, 2],
            [4, 4, 4, 8, 5],
            [5, 4, 5, 8, 8],
            [3, 8, 4, 8, 8],
            [3, 4, 4, 4, 5],
          ],
        ),
        legend: [...structureLegend, targetLegendItem],
        teachingOnly: false,
        structure: const TeachingStructure(
          family: TeachingFamily.extendedRect,
          claim: TeachingClaim.forcing,
          baseDigits: {2, 5, 8},
          cells: [
            CellRef(3, 4),
            CellRef(4, 4),
            CellRef(5, 4),
            CellRef(3, 8),
            CellRef(4, 8),
            CellRef(5, 8),
          ],
          extras: [
            CandidateRef(3, 8, 1),
            CandidateRef(5, 8, 3),
            CandidateRef(3, 4, 4),
          ],
          boxSpan: 2,
          replayBudget: 8,
          conclusionFalse: [
            CandidateRef(8, 8, 1),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'forcing_ul',
        name: '强制唯一环',
        summary: '偶环上的每个多余候选各成一支，取各支共同的删除。',
        definition: '强制唯一环（Forcing Unique Loop）把分支的对象换成偶环：'
            '环上相邻两格同行或同列，每一条用到的行、列、宫都正好占环上两格，'
            '两个底数可以沿环交替对调。环不可能整条只填底数，'
            '所以环上的多余候选构成一份穷尽的分类清单，'
            '每个多余候选各成一支假设，各支只沿唯一后果往下推，取共同的删除。'
            '它依赖先把偶环搜出来，所以实现上要先有唯一环的几何扫描，再套一层分支求交。',
        howToSpot: '先搜出六格及以上的偶环，再把环上每个多余候选各列成一支假设，'
            '看各支能不能推到同一个删除或填数。',
        walkthrough: '本例的环是 r3c3 → r3c9 → r1c9 → r1c6 → r2c6 → r2c3 → 回到 r3c3，'
            '六格都含底数对 `{4,5}`：r1、r2、r3 各占两格，c3、c6、c9 各占两格，'
            '左上宫、中上宫、右上宫也各占两格。'
            'r3c9、r1c6、r2c3 干净地只剩 `{4,5}`，多余候选有三个：'
            '3r3c3、8r1c9、9r2c6。'
            '环若整条只剩 4、5，沿环交替对调就有第二个解，所以这三个候选必有一个为真。'
            '情况一假设 3r3c3：r3c3=3 → r3c2=7（唯余）→ r2c2=2（唯余）'
            '→ r7c1=2（r7 摒除）→ r5c1=1（c1 摒除）→ r8c8=2（r8 摒除）。'
            '情况二假设 8r1c9：r1c9=8 → r2c5=8（中上宫摒除）→ r3c5=1（c5 摒除）'
            '→ r2c2=2（r2 摒除）→ r3c2=7（c2 摒除）→ r3c3=3（r3 摒除）。'
            '情况三假设 9r2c6：r2c6=9 → r1c6=4（c6 摒除）→ r5c6=5（c6 摒除）'
            '→ r8c1=4（c1 摒除）→ r1c1=5（c1 摒除）→ r7c1=2（c1 摒除）。'
            '三支走的是三条不同的路，可是 2 最后都落到 r2c2 或 r7c1 上'
            '（情况三干脆把 r1c1 填成了 5）。这两格都同时看得见 r1c1 和 r7c2，'
            '所以 2r1c1 与 2r7c2 三支都删得掉：'
            'r1c1 从 `{2,4,5}` 缩到 `{4,5}`，r7c2 从 `{1,2,6,8}` 缩到 `{1,6,8}`。',
        caveats: '偶环的区域条件要逐条核对：每一条用到的行、列、宫都必须恰好占两格；'
            '分支越多越容易漏，漏一支就等于把一个方向的推理当成了全部。'
            '这一页的三支各走六格，读者照着抄一遍就能复现；'
            '要是某支得推上几十格才收口，那已经不是教学例子了。',
        rank: 781,
        examplePuzzle:
            '091000630600300000800006200000001000042000000057008001000053047000107006700062009',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [2, 2],
            [2, 8],
            [0, 8],
            [0, 5],
            [1, 5],
            [1, 2],
          ],
          targets: const [
            [0, 0],
            [6, 1],
          ],
          nodes: const [
            [2, 2, 4],
            [2, 2, 5],
            [2, 8, 4],
            [2, 8, 5],
            [0, 8, 4],
            [0, 8, 5],
            [0, 5, 4],
            [0, 5, 5],
            [1, 5, 4],
            [1, 5, 5],
            [1, 2, 4],
            [1, 2, 5],
          ],
          keys: const [
            [2, 2, 3],
            [0, 8, 8],
            [1, 5, 9],
          ],
          weakLinks: const [
            [2, 2, 2, 8, 4],
            [2, 8, 0, 8, 5],
            [0, 8, 0, 5, 4],
            [0, 5, 1, 5, 5],
            [1, 5, 1, 2, 4],
            [1, 2, 2, 2, 5],
          ],
        ),
        legend: [...structureLegend, targetLegendItem],
        teachingOnly: false,
        structure: const TeachingStructure(
          family: TeachingFamily.uniqueLoop,
          claim: TeachingClaim.forcing,
          baseDigits: {4, 5},
          cells: [
            CellRef(2, 2),
            CellRef(2, 8),
            CellRef(0, 8),
            CellRef(0, 5),
            CellRef(1, 5),
            CellRef(1, 2),
          ],
          extras: [
            CandidateRef(2, 2, 3),
            CandidateRef(0, 8, 8),
            CandidateRef(1, 5, 9),
          ],
          replayBudget: 6,
          conclusionFalse: [
            CandidateRef(0, 0, 2),
            CandidateRef(6, 1, 2),
          ],
        ),
      ),
    ];
