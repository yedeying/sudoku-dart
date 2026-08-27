import 'board_markup.dart';
import 'technique_catalog.dart';
import 'technique_examples_teaching_support.dart';
import 'technique_structure.dart';

/// BUG Type 2/3/4 与 BUG+n 的教学盘面。
///
/// 双值死盘不是「每个空格都只剩两个候选」就算数，还要满足奇偶条件：
/// 每个区域里每个未填数字恰好出现两次。只有两条同时成立，
/// 「这样的局面解的个数是偶数」才成立，也才轮得到「题目唯一解，所以不可能是死盘」
/// 这个反证。四个盘面都是先构造再用 `bugParityViolations` 逐条验过的：
/// 把结构声明里那几个多余候选拿掉之后，剩下的确实是一个完整的双值死盘。
///
/// 引擎实现了 BUG+1 与 Type 2、Type 4；Type 3 和 BUG+n 还没有独立报法，
/// 那两条的示意图只标死盘、例外和结论涉及的格子，不画红色删除标记；
/// 但每条写在正文里的删除都用盘面的唯一解核对过。
List<TechniqueInfo> bugTechniqueExamples() => [
      TechniqueInfo(
        id: 'bug_type2',
        name: 'BUG Type 2',
        summary: '两个例外格多出同一个数字，删共同可见处。',
        definition: 'BUG（Bivalue Universal Grave，双值死盘）指这样一个局面：每个空格恰好剩两个候选，'
            '并且每个区域里每个未填数字恰好出现两次。满足这两条的局面解的个数一定是偶数，'
            '和「题目保证唯一解」直接冲突。Type 2 说的是盘面差一点就是死盘：'
            '只有两个例外格比双值多出同一个数字 c。这两格不可能都把 c 去掉，'
            '否则整盘退回死盘，所以 c 至少在其中一格为真，同时看得见这两格的位置上 c 可以删。',
        howToSpot: '先按奇偶条件确认全盘几乎就是死盘，再数例外格：'
            '正好两个、而且多出来的是同一个数字，就走 Type 2。',
        walkthrough:
            '本例 14 个空格里有 12 个是双值格，例外是 r2c5（`{2,4,9}`）和 r3c5（`{2,7,9}`）。'
            '两格的底数分别是 `{4,9}` 和 `{7,9}`，各自多出同一个 2。'
            '把这两个 2 拿掉，剩下的盘面每个区域里每个未填数字都恰好出现两次，'
            '是一个货真价实的死盘，解的个数会是偶数。所以 2r2c5、2r3c5 至少一个为真，'
            '同时看得见这两格的位置——c5 上的 r6c5、r8c5，以及中上宫里的 r2c4、r3c6——都能删 2。',
        caveats: '认死盘要连奇偶条件一起查，只看「都是双值格」会把不是死盘的局面当成死盘；'
            '双值格的候选可以各不相同，不必是同一对数字。',
        rank: 355,
        examplePuzzle:
            '847516239350008167061300854614983572078065301530701608193854726485600913726139485',
        exampleMarkup: schematicMarkup(
          cover: const [
            [1, 2],
            [2, 0],
            [4, 0],
            [4, 3],
            [4, 7],
            [5, 2],
            [5, 7],
            [7, 5],
          ],
          targets: const [
            [1, 3],
            [2, 5],
            [5, 4],
            [7, 4],
          ],
          pattern: const [
            [1, 4],
            [2, 4],
          ],
          nodes: const [
            [1, 4, 4],
            [1, 4, 9],
            [2, 4, 7],
            [2, 4, 9],
          ],
          keys: const [
            [1, 4, 2],
            [2, 4, 2],
          ],
          weakLinks: const [
            [1, 4, 2, 4, 2],
          ],
        ),
        legend: graveLegend,
        structure: const TeachingStructure(
          family: TeachingFamily.bivalueGrave,
          claim: TeachingClaim.graveType2,
          extras: [CandidateRef(1, 4, 2), CandidateRef(2, 4, 2)],
          conclusionFalse: [
            CandidateRef(1, 3, 2),
            CandidateRef(2, 5, 2),
            CandidateRef(5, 4, 2),
            CandidateRef(7, 4, 2),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'bug_type4',
        name: 'BUG Type 4',
        summary: '例外格所在区域底数成强链，删另一底数。',
        definition: 'BUG Type 4 对应唯一矩形 Type 4（锁定型）：盘面差一点就是双值死盘，'
            '两个例外格落在同一个区域里，而它们共有的某个底数在这个区域里只剩这两格，'
            '也就是形成了强链。这个底数一定落在两个例外格之一，'
            '而另一格就只能去填自己多出来的那个候选，'
            '于是每个例外格都只剩「共有底数」和「自己多出来的候选」两种可能，'
            '各自的另一个底数就可以删。判定顺序是先按奇偶条件扫死盘，再在例外处套锁定。',
        howToSpot: '确认奇偶条件成立、只差两个例外格之后，'
            '看这两格共同所在的行/列/宫里，哪个共有底数被压到只剩这两格。',
        walkthrough: '本例 19 个空格里有 17 个是双值格，例外是 r4c5 和 r4c6，两格候选都是 `{2,5,8}`：'
            'r4c5 的底数是 `{5,8}`、多出一个 2，r4c6 的底数是 `{2,8}`、多出一个 5。'
            '把这两个多余候选拿掉，剩下的盘面满足完整的死盘奇偶条件，所以 2r4c5、5r4c6 至少一个为真。'
            '再看 r4：这一行的空格是 r4c1、r4c5、r4c6、r4c8，而 8 只出现在 r4c5 和 r4c6，'
            '是一条强链。若 8 落在 r4c5，则 r4c5 不是 2，只好由 r4c6 填 5；'
            '若 8 落在 r4c6，则 r4c6 不是 5，只好由 r4c5 填 2。'
            '两种情形下 r4c5 都只能是 8 或 2、r4c6 都只能是 8 或 5，'
            '所以 5r4c5 和 2r4c6 可以删。',
        caveats: '强链要按当前候选现算，前面删过候选没刷新就容易把不成立的强链当真；'
            '而且必须先确认整盘真的只差这两个例外格，死盘没认准后面全部作废。',
        rank: 356,
        examplePuzzle:
            '921370608867290031050816972039600107180907063576143289710560394045709816690401725',
        exampleMarkup: schematicMarkup(
          cover: const [
            [0, 5],
            [0, 7],
            [1, 5],
            [1, 6],
            [2, 0],
            [2, 2],
            [3, 0],
            [3, 7],
            [4, 2],
            [4, 4],
            [4, 6],
            [6, 2],
            [6, 5],
            [7, 0],
            [7, 4],
            [8, 2],
            [8, 4],
          ],
          pattern: const [
            [3, 4],
            [3, 5],
          ],
          nodes: const [
            [3, 4, 8],
            [3, 5, 8],
          ],
          keys: const [
            [3, 4, 2],
            [3, 5, 5],
          ],
          strongLinks: const [
            [3, 4, 3, 5, 8],
          ],
        ),
        legend: graveLegend,
        structure: const TeachingStructure(
          family: TeachingFamily.bivalueGrave,
          claim: TeachingClaim.graveType4,
          extras: [CandidateRef(3, 4, 2), CandidateRef(3, 5, 5)],
          lockDigit: 8,
          lockHouses: [3],
          conclusionFalse: [
            CandidateRef(3, 4, 5),
            CandidateRef(3, 5, 2),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'bug_type3',
        name: 'BUG Type 3',
        summary: '例外格的多余数字与同区域配数组，须走虚拟格。',
        definition: 'BUG Type 3 对应唯一矩形 Type 3：盘面差一点就是双值死盘，'
            '两个例外格落在同一个区域里，各自多出一个不同的额外候选。'
            '因为这两个额外候选至少有一个为真，可以把它们并成一个「虚拟格」，'
            '虚拟格的候选就是那两个额外数字；再拿虚拟格和同区域里候选正好是这两个数的格子'
            '配成数对，按数组规则删除。虚拟格背后是完整性约束，'
            '不能把它拆开当普通裸对按裸对直接删除。这一型比 Type 2、4 都重。',
        howToSpot: '确认死盘的奇偶条件之后，把两个例外格多出来的候选并成一格，'
            '再在它们共同所在的行/列/宫里找能和它配成数组的格子。',
        walkthrough: '本例 20 个空格里有 18 个是双值格，例外是 r5c8（`{1,2,9}`，底数 `{1,9}`，多出 2）'
            '和 r8c8（`{3,7,9}`，底数 `{7,9}`，多出 3），两格都在 c8 上。'
            '拿掉这两个多余候选，剩下的盘面满足完整的死盘奇偶条件，'
            '所以 2r5c8、3r8c8 至少一个为真——把它们并成一个候选为 `{2,3}` 的虚拟格。'
            'c8 上的 r2c8 恰好是 `{2,3}`，虚拟格和它在 c8 里凑成数对，'
            '把 2 和 3 都占满了，于是 c8 上其余格子的这两个数可以删：2r6c8、3r7c8。',
        caveats: '虚拟格只能整体参与数组，绝不能把两个额外候选拆开当裸对使用；'
            '例外格多出的候选凑不出数组时这一型就用不上，得换类型或接链。',
        rank: 503,
        examplePuzzle:
            '709485160046009508185263947418927356063804700907036804094608201802041600671392485',
        exampleMarkup: schematicMarkup(
          cover: const [
            [0, 1],
            [0, 8],
            [1, 0],
            [1, 3],
            [1, 4],
            [1, 7],
            [4, 0],
            [4, 4],
            [4, 8],
            [5, 1],
            [5, 3],
            [6, 0],
            [6, 4],
            [7, 1],
            [7, 3],
            [7, 8],
          ],
          targets: const [
            [5, 7],
            [6, 7],
          ],
          pattern: const [
            [4, 7],
            [7, 7],
          ],
          nodes: const [
            [4, 7, 1],
            [4, 7, 9],
            [7, 7, 7],
            [7, 7, 9],
            [1, 7, 2],
            [1, 7, 3],
          ],
          keys: const [
            [4, 7, 2],
            [7, 7, 3],
          ],
          weakLinks: const [
            [4, 7, 1, 7, 2],
            [7, 7, 1, 7, 3],
          ],
        ),
        legend: graveLegend,
        structure: const TeachingStructure(
          family: TeachingFamily.bivalueGrave,
          claim: TeachingClaim.graveType3,
          extras: [CandidateRef(4, 7, 2), CandidateRef(7, 7, 3)],
          lockHouses: [16],
          subsetCells: [CellRef(1, 7)],
          subsetDigits: {2, 3},
          conclusionFalse: [
            CandidateRef(5, 7, 2),
            CandidateRef(6, 7, 3),
          ],
        ),
      ),
      TechniqueInfo(
        id: 'bug_plus_n',
        name: 'BUG+n',
        summary: 'n 个例外撑开双值死盘，真数不能同时为假。',
        definition: 'BUG+n 只数例外的个数，不规定怎么用：盘面差 n 个多余候选就满足双值死盘的'
            '全部条件——每个空格恰好两个候选、每个区域里每个未填数字恰好出现两次。'
            '因为死盘的解数是偶数、而题目保证唯一解，这 n 个多出来的候选不可能同时为假，'
            '至少有一个是真数。这本身只是一条约束，'
            '不过当这 n 个多余候选恰好是同一个数字时，它就退化成一个成组的强约束：'
            '同时看得见这 n 格的位置上，那个数字可以删。BUG+1 是最简单的特例，'
            '那时候唯一的多余候选直接就是答案。',
        howToSpot: '数全盘空格的候选个数，再按区域核对奇偶：'
            '绝大多数格子是两个候选、只有少数几个更多，把这些例外和多出来的候选一起圈出来。',
        walkthrough: '本例 19 个空格里有 16 个是双值格，例外是 r4c6（`{5,6,9}`）、r8c4（`{5,8,9}`）'
            '和 r9c6（`{5,6,9}`），三格的底数分别是 `{5,6}`、`{5,8}`、`{5,6}`，'
            '多出来的都是 9，所以这是 BUG+3。把这三个 9 拿掉，'
            '剩下的盘面满足完整的死盘奇偶条件，于是 9r4c6、9r8c4、9r9c6 不可能同时为假。'
            '三格多出来的又都是 9，那么 9 至少落在这三格之一；'
            'r7c6 同时看得见这三格（和 r4c6、r9c6 共 c6，和 r8c4 共中下宫），所以 9r7c6 可以删。',
        caveats: '+n 只是个计数，不要把 +2、+3 当成独立技巧名；'
            '多余候选不是同一个数字时，「不能同时为假」推不出任何一格的删除，'
            '只能当成约束接进链里。',
        rank: 504,
        examplePuzzle:
            '726050431895341276143672500207100043401023760369487125634710052012034607078200314',
        exampleMarkup: schematicMarkup(
          cover: const [
            [0, 3],
            [0, 5],
            [2, 7],
            [2, 8],
            [3, 1],
            [3, 4],
            [3, 6],
            [4, 1],
            [4, 3],
            [4, 8],
            [6, 6],
            [7, 0],
            [7, 7],
            [8, 0],
            [8, 4],
          ],
          targets: const [
            [6, 5],
          ],
          pattern: const [
            [3, 5],
            [7, 3],
            [8, 5],
          ],
          nodes: const [
            [3, 5, 5],
            [3, 5, 6],
            [7, 3, 5],
            [7, 3, 8],
            [8, 5, 5],
            [8, 5, 6],
          ],
          keys: const [
            [3, 5, 9],
            [7, 3, 9],
            [8, 5, 9],
          ],
          weakLinks: const [
            [3, 5, 6, 5, 9],
            [8, 5, 6, 5, 9],
          ],
        ),
        legend: graveLegend,
        teachingOnly: true,
        structure: const TeachingStructure(
          family: TeachingFamily.bivalueGrave,
          claim: TeachingClaim.gravePlusN,
          extras: [
            CandidateRef(3, 5, 9),
            CandidateRef(7, 3, 9),
            CandidateRef(8, 5, 9),
          ],
          conclusionFalse: [CandidateRef(6, 5, 9)],
        ),
      ),
    ];
