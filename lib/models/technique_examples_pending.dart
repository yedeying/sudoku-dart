import 'board_markup.dart';
import 'technique_catalog.dart';
import 'technique_examples_teaching_support.dart';
import 'technique_structure.dart';

/// 「待定」系列的教学盘面：待定唯一矩形、待定 BUG、待定扩展矩形、待定唯一环。
///
/// 待定的意思是结构还差一步才成立，多出来的那个候选不当场删或填，
/// 而是当成交替推理链上的一个节点接进链里去用。四个盘面都是随机完整解挖出来的
/// 唯一解题目，几何用脚本筛过；这四条引擎都还没有独立报法，
/// 所以示意图只标结构和入链的多余候选，不标删除。
List<TechniqueInfo> pendingTechniqueExamples() => [
      TechniqueInfo(
        id: 'pending_ur',
        name: '待定唯一矩形',
        summary: '差一步成唯一矩形，多余候选当链节点。',
        definition: '待定唯一矩形（Almost Unique Rectangle）说的是矩形几何已经摆在那里，'
            '但还差一步才构成能直接下结论的唯一矩形：几个角上多出来的候选把致命形挡住了。'
            '完整的唯一矩形当场就能删或填，待定的做法不同——'
            '致命矩形不成立意味着这些多余候选里至少有一个为真，'
            '把它们的「至少一个为真」当成一条强链关系，'
            '像普通链节点一样接进交替推理链，再靠链的两端收口。'
            '多余候选恰好两个时最好用：写成 A = B 就是标准的强链。',
        howToSpot: '先找四角同宫成对、底数一致的矩形，再数清楚挡路的多余候选；'
            '正好两个而且不构成类型 2 时，把这两个候选当成链上的一个强链往外接。',
        walkthrough: '本例的矩形是 r2c8、r2c9、r7c8、r7c9，落在右上宫和右下宫，'
            '底数对是 `{2,8}`，r2c8（`{2,8}`）和 r7c9（`{2,8}`）已经干净。'
            '挡路的多余候选只有两个：r2c9 的 9 和 r7c8 的 5。'
            '如果这两个都为假，四角就只剩 2、8，两种对调都合法，解不唯一——'
            '所以 9r2c9 与 5r7c8 至少有一个为真，可以写成强链 9r2c9 = 5r7c8。'
            '这两个候选数字不同、两格又互不相见，'
            '类型 2、类型 4 那种当场删除都用不上，只能停在链节点上：'
            '本页只交出这条强链，删除留给接上它的那条交替推理链去收口。',
        caveats: '待定结构必须先有确凿的矩形几何，多余候选还要数清楚一个不漏；'
            '如果两个多余候选是同一个数字又互相看得见，那就是能直接删的类型 2，'
            '不该停在链节点上。',
        rank: 703,
        examplePuzzle:
            '006009001000034600008000537300498005600500703000300000071000000000000196000005004',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [1, 7],
            [1, 8],
            [6, 7],
            [6, 8],
          ],
          nodes: const [
            [1, 7, 2],
            [1, 7, 8],
            [1, 8, 2],
            [1, 8, 8],
            [6, 7, 2],
            [6, 7, 8],
            [6, 8, 2],
            [6, 8, 8],
          ],
          keys: const [
            [1, 8, 9],
            [6, 7, 5],
          ],
          weakLinks: const [
            [1, 7, 1, 8, 2],
            [6, 7, 6, 8, 8],
            [1, 7, 6, 7, 8],
            [1, 8, 6, 8, 2],
          ],
        ),
        legend: chainNodeLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.uniqueRect,
          claim: TeachingClaim.chainNode,
          baseDigits: {2, 8},
          cells: [
            CellRef(1, 7),
            CellRef(1, 8),
            CellRef(6, 7),
            CellRef(6, 8),
          ],
          extras: [CandidateRef(1, 8, 9), CandidateRef(6, 7, 5)],
          boxSpan: 2,
        ),
      ),
      TechniqueInfo(
        id: 'pending_bug',
        name: '待定 BUG',
        summary: '差一步成双值死盘，多余候选当链节点。',
        definition: '待定 BUG（Almost Bivalue Universal Grave）和待定唯一矩形同一路数，'
            '只是对象换成了整张盘：全盘空格差一点就都只剩两个候选，'
            '几个例外格多出来的候选正是挡住死盘的东西。'
            '因为纯双值死盘解不唯一，这些多余候选不可能同时为假，'
            '于是它们的「至少一个为真」可以当成一个链节点接进交替推理链，'
            '而不是像 BUG+1 那样当场填数。',
        howToSpot: '数全盘空格的候选个数，找出少数几个超过两个的例外格，'
            '把它们多出来的候选当成一组链节点往外接。',
        walkthrough: '本例 20 个空格里有 18 个是双值格，例外是 r7c1（`{2,3,7}`，底数 `{2,3}`，多出 7）'
            '和 r9c4（`{2,3,7}`，底数 `{3,7}`，多出 2）。'
            '把这两个多余候选拿掉，剩下的盘面满足完整的死盘奇偶条件——'
            '每格恰好两个候选、每个房屋里每个未填数字恰好出现两次——'
            '所以 7r7c1 与 2r9c4 不可能同时为假。'
            '两格互不相见，直接的类型 2、4 都用不上，只能把这条约束当链节点：'
            '假设 r8c4 填 2，那么 r9c4 不能是 2（同 c4），于是 7r7c1 必须为真；'
            '可是 r7c1 与 r8c1 同在 c1 与左下宫，r8c1（`{2,7}`）就只能填 2，'
            '和 r8c4 的 2 撞在 r8 上。所以 2r8c4 为假，r8c4 只能填 7。',
        caveats: '例外格必须数清楚，一个都不能漏，奇偶条件也要逐个房屋核对；'
            '而且这只是「不能同时为假」，别误当成某一个一定为真。',
        rank: 704,
        examplePuzzle:
            '629071045480965010015402609971603504832154796546097031060549108054018963198006450',
        exampleMarkup: schematicMarkup(
          cover: const [
            [0, 3],
            [0, 6],
            [1, 2],
            [1, 6],
            [1, 8],
            [2, 0],
            [2, 4],
            [2, 7],
            [3, 4],
            [3, 7],
            [5, 3],
            [5, 6],
            [6, 2],
            [6, 7],
            [7, 0],
            [8, 4],
            [8, 8],
          ],
          targets: const [
            [7, 3],
          ],
          pattern: const [
            [6, 0],
            [8, 3],
          ],
          nodes: const [
            [6, 0, 2],
            [6, 0, 3],
            [8, 3, 3],
            [8, 3, 7],
            [7, 0, 2],
            [7, 0, 7],
            [7, 3, 2],
            [7, 3, 7],
          ],
          keys: const [
            [6, 0, 7],
            [8, 3, 2],
          ],
          weakLinks: const [
            [6, 0, 7, 0, 7],
            [8, 3, 7, 3, 2],
            [7, 0, 7, 3, 2],
          ],
        ),
        legend: graveLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.bivalueGrave,
          claim: TeachingClaim.graveChainNode,
          extras: [CandidateRef(6, 0, 7), CandidateRef(8, 3, 2)],
          conclusionFalse: [CandidateRef(7, 3, 2)],
          replayBudget: 4,
        ),
      ),
      TechniqueInfo(
        id: 'pending_er',
        name: '待定扩展矩形',
        summary: '差一步成扩展矩形，多余候选当链节点。',
        definition: '待定扩展矩形（Almost Extended Rectangle）先要有六格扩展矩形的几何：'
            '两条线各三格、落在两个宫里、底数集合完全相同。'
            '差一步的意思是某几格多出来的候选把致命形挡住了。'
            '这时不当场删，而是把「多余候选为真」和「六格致命形成立」这两条出路'
            '当成一个强链关系，接进交替推理链继续走。'
            '它比待定唯一矩形多两格，所以几何检查更重，链上的用法完全一样。',
        howToSpot: '先按扩展矩形认六格几何，再挑出挡住致命形的那一两个多余候选，'
            '把它们当链节点往外接。',
        walkthrough: '本例的六格是 r3 上的 r3c7、r3c8、r3c9 和 r9 上的 r9c7、r9c8、r9c9，'
            '落在右上宫和右下宫这两个宫里，六格都含底数 `{2,5,7}`。'
            '挡住致命形的额外候选恰好两个：r3c8 多出一个 3，r9c9 多出一个 8。'
            '如果这两个候选同时为假，六格就只剩 `{2,5,7}`，两条线上的底数可以整块对调，'
            '题目会有第二个解。所以 3r3c8 与 8r9c9 不可能同时为假。'
            '这两格不同行、不同列、不同宫，谁也管不到谁，'
            '所以这里得不出任何一格的删除，只能把 3r3c8 = 8r9c9 这条关系'
            '当成一个成组节点接进交替推理链，等链的另一端来收口。',
        caveats: '六格几何必须先坐实，尤其是每一格都要含全部三个底数；'
            '而且待定结构本身只给出一条「不能同时为假」的关系，'
            '不接链就什么也删不掉，别把它当成一步棋。',
        rank: 720,
        examplePuzzle:
            '000900841540302600910400000700000309360700080059004000205080104800200963090000000',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [2, 6],
            [2, 7],
            [2, 8],
            [8, 6],
            [8, 7],
            [8, 8],
          ],
          nodes: const [
            [2, 6, 2],
            [2, 6, 5],
            [2, 6, 7],
            [2, 7, 2],
            [2, 7, 5],
            [2, 7, 7],
            [2, 8, 2],
            [2, 8, 5],
            [2, 8, 7],
            [8, 6, 2],
            [8, 6, 5],
            [8, 6, 7],
            [8, 7, 2],
            [8, 7, 5],
            [8, 7, 7],
            [8, 8, 2],
            [8, 8, 5],
            [8, 8, 7],
          ],
          keys: const [
            [2, 7, 3],
            [8, 8, 8],
          ],
          weakLinks: const [
            [2, 6, 8, 6, 2],
            [2, 7, 8, 7, 5],
            [2, 8, 8, 8, 7],
          ],
        ),
        legend: chainNodeLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.extendedRect,
          claim: TeachingClaim.chainNode,
          baseDigits: {2, 5, 7},
          cells: [
            CellRef(2, 6),
            CellRef(2, 7),
            CellRef(2, 8),
            CellRef(8, 6),
            CellRef(8, 7),
            CellRef(8, 8),
          ],
          extras: [CandidateRef(2, 7, 3), CandidateRef(8, 8, 8)],
          boxSpan: 2,
        ),
      ),
      TechniqueInfo(
        id: 'pending_ul',
        name: '待定唯一环',
        summary: '差一步成唯一环，多余候选当链节点。',
        definition: '待定唯一环（Almost Unique Loop）先要有偶环几何：'
            '环上相邻两格同行或同列，每一行、每一列、每一宫都正好占环上两格，'
            '两个底数可以沿环交替对调。差一步的意思是环上某些格子多出来的候选'
            '挡住了这次对调。这些多余候选不可能同时为假，'
            '所以可以整体当成一个链节点接进交替推理链，而不是直接删或填。',
        howToSpot: '先搜出六格及以上的偶环，再看环上多出来的候选：'
            '只要它们不落在同一个房屋里，就只能整体当成一个链节点。',
        walkthrough: '本例的环是 r7c2 → r7c4 → r8c4 → r8c9 → r9c9 → r9c2 → 回到 r7c2，'
            '六格都含底数对 `{7,8}`，r7、r8、r9 各占两格，c2、c4、c9 各占两格，'
            '左下、中下、右下三个宫也各占两格。'
            '挡住对调的额外候选恰好两个：r7c2 多出一个 3，r9c9 多出一个 4。'
            '这两个候选不可能同时为假，否则环上只剩 `{7,8}`，交替对调会造出第二个解。'
            '但 r7c2 与 r9c9 互不相见，直接删不了任何东西，'
            '只能把 3r7c2 = 4r9c9 当成一个成组节点接进 AIC，靠链的另一端收口。',
        caveats: '环上每个房屋必须恰好占两格；'
            '而且待定唯一环只提供一条「不能同时为假」的关系，'
            '两个多余候选落在不同房屋时，不接链就删不出任何候选。',
        rank: 721,
        examplePuzzle:
            '000000005150920746760305000300506900920400070000002000006054209492031060501069300',
        exampleMarkup: schematicMarkup(
          pattern: const [
            [6, 1],
            [6, 3],
            [7, 3],
            [7, 8],
            [8, 8],
            [8, 1],
          ],
          nodes: const [
            [6, 1, 7],
            [6, 1, 8],
            [6, 3, 7],
            [6, 3, 8],
            [7, 3, 7],
            [7, 3, 8],
            [7, 8, 7],
            [7, 8, 8],
            [8, 8, 7],
            [8, 8, 8],
            [8, 1, 7],
            [8, 1, 8],
          ],
          keys: const [
            [6, 1, 3],
            [8, 8, 4],
          ],
          weakLinks: const [
            [6, 1, 6, 3, 7],
            [6, 3, 7, 3, 8],
            [7, 3, 7, 8, 7],
            [7, 8, 8, 8, 8],
            [8, 8, 8, 1, 7],
            [8, 1, 6, 1, 8],
          ],
        ),
        legend: chainNodeLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.uniqueLoop,
          claim: TeachingClaim.chainNode,
          baseDigits: {7, 8},
          cells: [
            CellRef(6, 1),
            CellRef(6, 3),
            CellRef(7, 3),
            CellRef(7, 8),
            CellRef(8, 8),
            CellRef(8, 1),
          ],
          extras: [CandidateRef(6, 1, 3), CandidateRef(8, 8, 4)],
        ),
      ),
    ];
