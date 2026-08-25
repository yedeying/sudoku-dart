import 'package:flutter/material.dart';

import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_catalog.dart';

int _ck(int r, int c) => BoardMarkup.cellKey(r, c);
CandidateRef _cr(int r, int c, int n) => CandidateRef(r, c, n);

const _fishLegend = [
  TechniqueLegendItem(color: TeachingColors.house, label: '基线'),
  TechniqueLegendItem(color: TeachingColors.pattern, label: '鱼身'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '覆盖单位'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
];

const _finnedFishLegend = [
  TechniqueLegendItem(color: TeachingColors.house, label: '基线'),
  TechniqueLegendItem(color: TeachingColors.pattern, label: '鱼身'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '覆盖单位'),
  TechniqueLegendItem(color: TeachingColors.elimCand, label: '删除'),
  TechniqueLegendItem(color: TeachingColors.end, label: '鳍'),
];

/// 鱼类技巧的标记：定义行/列整条淡亮，鱼身涂 pattern 色，
/// 覆盖单位挑一个代表格涂 cover 色，删除的候选涂 elimCand 色，
/// 带鳍的额外候选涂 end 色。
BoardMarkup _fishMarkup({
  required List<List<int>> pattern,
  required List<List<int>> cover,
  required List<List<int>> eliminated,
  required int digit,
  List<List<int>> fin = const [],
  List<int> rows = const [],
  List<int> cols = const [],
}) {
  final cellColors = <int, Color>{
    for (final r in rows)
      for (var c = 0; c < 9; c++) _ck(r, c): TeachingColors.house,
    for (final c in cols)
      for (var r = 0; r < 9; r++) _ck(r, c): TeachingColors.house,
  };
  for (final c in pattern) {
    cellColors[_ck(c[0], c[1])] = TeachingColors.pattern;
  }
  for (final c in cover) {
    cellColors[_ck(c[0], c[1])] = TeachingColors.cover;
  }
  for (final c in fin) {
    cellColors[_ck(c[0], c[1])] = TeachingColors.end;
  }
  return BoardMarkup(
    cellColors: cellColors,
    candidateColors: {
      for (final e in eliminated)
        _cr(e[0], e[1], digit): TeachingColors.elimCand,
    },
  );
}

/// 鱼类与带鳍/Franken 鱼的七个教学盘面。
///
/// Swordfish 的盘面和标记位置是从题库里的困难/专家题逐步用
/// [SudokuSolver.getHint] 推演出来的：一步步应用求解器给出的提示，记录下它
/// 第一次报出该鱼类技巧时的棋盘快照，再把那一刻的候选、鱼身格、删除目标写成
/// 常量（求解器已经确认过这些候选和删除关系都真实存在）。X-Wing 和
/// Franken 鱼是直接在题库真实谜题的原始候选上扫描出来的天然鱼型，用独立
/// 脚本核验过候选分布、删除关系和唯一解。Jellyfish 和带鳍三例在本引擎里
/// 还没有对应的 finder，因此改用「从完整解出发挖空」的办法：先取一个真实的
/// 完整解，挖空鱼身、鳍和删除目标涉及的格子，再逐一核对挖空后的候选确实
/// 只落在预期的行/列/宫里——盘面依然是真实解的子集，只是鱼型本身没有引擎
/// 自动验证。
List<TechniqueInfo> fishTechniqueExamples() => [
      TechniqueInfo(
        id: 'xwing',
        name: 'X-Wing',
        summary: '某数字在两行只出现在相同两列（或对调），删这两列其它行的它。',
        definition: 'X-Wing 是最基础的鱼类技巧：如果某个数字在两行的候选恰好都只出现在'
            '相同的两列里，这两行就把该数字的位置锁在这两列上——每一行都必须给这个数字'
            '留一个位置，两行两列刚好一一对应，所以这两列里其它行的候选都不可能是这个'
            '数字，可以直接删除。反过来以两列找两行也是同样的道理。',
        howToSpot: '选定一个数字，找两行（或两列）候选数刚好都只剩两格，'
            '且这两格所在的列（或行）完全相同，就是 X-Wing。',
        walkthrough: '本例中数字 6 在r3和r7都只能出现在c5和c8，'
            '这两行、两列组成一个 X-Wing：无论 6 具体落在哪一种对角组合上，'
            'c5和c8的 6 都必然被这两行占用，因此可以把这两列其它行的候选 6 '
            '删除。本例删掉的是r1c5、r1c8、r9c5、'
            'r9c8的候选 6。',
        caveats: '两行的候选列必须完全一致，只差一列或多一列都不成立，'
            '别把普通数对误认成 X-Wing。',
        rank: 70,
        examplePuzzle:
            '400000007006030200005702900850473026000806000004020300003209800068000590000000000',
        exampleMarkup: _fishMarkup(
          digit: 6,
          rows: [2, 6],
          pattern: [
            [2, 4],
            [2, 7],
            [6, 4],
            [6, 7],
          ],
          cover: [
            [0, 4],
            [0, 7],
          ],
          eliminated: [
            [0, 4],
            [0, 7],
            [8, 4],
            [8, 7],
          ],
        ),
        legend: _fishLegend,
      ),
      TechniqueInfo(
        id: 'swordfish',
        name: 'Swordfish',
        summary: 'X-Wing 的三行三列版。',
        definition: 'Swordfish 是三行三列版的鱼：如果某个数字在三行的候选都只落在'
            '同样的三列里（每行 2 到 3 个候选都可以），这三行就必须把该数字分别放进'
            '这三列，因此这三列上其它行的候选都不可能是这个数字，可以直接删除。'
            '反过来以三列找三行也成立。',
        howToSpot: '选定一个数字，找三行候选数都是 2 或 3 的行，'
            '合并它们的候选列，如果恰好并成三列，就是 Swordfish。',
        walkthrough: '本例中数字 2 在r1,r4,r9都只落在c6,c8,c9（每行 2 个候选），'
            '这三行合起来正好把数字 2 锁在这三列里，因此可以删除这三列上其它行的候选 2：'
            '本例删掉的是r3c6、r3c8、r8c6、'
            'r8c8的候选 2。',
        caveats: '每行的候选不必都占满三列，只要合并后恰好是三列即可；'
            '漏算某一行的候选会把普通数组误判成 Swordfish。',
        rank: 75,
        examplePuzzle:
            '137450980000791000005800700304189500851204390209305008002508600000900000543610809',
        exampleMarkup: _fishMarkup(
          digit: 2,
          rows: [0, 3, 8],
          pattern: [
            [0, 5],
            [0, 8],
            [3, 8],
            [3, 7],
            [8, 5],
            [8, 7],
          ],
          cover: [
            [2, 5],
            [2, 7],
            [1, 8],
          ],
          eliminated: [
            [2, 5],
            [2, 7],
            [7, 5],
            [7, 7],
          ],
        ),
        legend: _fishLegend,
      ),
      TechniqueInfo(
        id: 'jellyfish',
        name: 'Jellyfish',
        summary: '四行四列的鱼。',
        definition: 'Jellyfish 是四行四列版的鱼：如果某个数字在四行的候选都落在'
            '同样的四列里（每行 2 到 4 个候选都可以），这四行就必须把该数字分别放进'
            '这四列，因此这四列上其它行的候选都不可能是这个数字，可以直接删除。',
        howToSpot: '选定一个数字，找四行候选数在 2 到 4 之间的行，'
            '合并候选列，如果恰好并成四列，就是 Jellyfish。',
        walkthrough: '本例中数字 2 在r2,r3,r4,r5都只落在c2,c3,c4,c5，'
            '这四行合起来正好把数字 2 锁在这四列里，因此可以删除这四列上其它行的候选 2：'
            '本例删掉的是 r6c2, r6c3, r6c4, r6c5 的候选 2。',
        caveats: 'Jellyfish 涉及四条线，组合数很多，通常要先靠锁定数组的思路缩小范围，'
            '否则很难靠肉眼找全。',
        rank: 80,
        examplePuzzle:
            '496871523103094786780306914347008169801049357900007048278413695534962871619785432',
        exampleMarkup: _fishMarkup(
          digit: 2,
          rows: [1, 2, 3, 4],
          pattern: [
            [1, 1],
            [1, 3],
            [2, 2],
            [2, 4],
            [3, 3],
            [3, 4],
            [4, 1],
            [4, 3],
          ],
          cover: [
            [5, 1],
            [5, 2],
            [5, 3],
            [5, 4],
          ],
          eliminated: [
            [5, 1],
            [5, 2],
            [5, 3],
            [5, 4],
          ],
        ),
        legend: _fishLegend,
      ),
      TechniqueInfo(
        id: 'finned_xwing',
        name: '带鳍 X-Wing',
        summary: '差一个鳍格才成 X-Wing，只能删看得到鳍的那个候选。',
        definition: '带鳍 X-Wing 在普通 X-Wing 的基础上，允许其中一行多出一个候选，'
            '这个多出来的候选叫鳍。只要鳍和某一条覆盖列共享同一个宫，那么这个宫内、'
            '这条覆盖列上的其它候选就可以删除：因为无论这个数字最终落在鳍上还是落在'
            '两条覆盖列上，那个位置都不可能再是这个数字。',
        howToSpot: '先按普通 X-Wing 找两行两列，如果其中一行多出一个候选，'
            '且这个候选和某条覆盖列同宫，就是带鳍 X-Wing。',
        walkthrough: '本例中数字 1 在r4只能出现在c1和c3，形成覆盖列；'
            'r3本该和r4一样只有这两列，却多了一个候选：r3c2，'
            '这个格子就是鳍。鳍和c1同在左上宫，所以左上宫内、c1上的其它候选 1 '
            '都可以删除：本例删掉的是r1c1和r2c1的候选 1。',
        caveats: '带鳍鱼的删除范围只限于和鳍同宫的那条覆盖线，'
            '另一条覆盖列不能因为有鳍就随便删，方向用反就会删错。',
        rank: 85,
        examplePuzzle:
            '089250467076948032000367589020694375934715826765823941258136794493572618607489253',
        exampleMarkup: _fishMarkup(
          digit: 1,
          rows: [2, 3],
          pattern: [
            [2, 0],
            [2, 2],
            [3, 0],
            [3, 2],
          ],
          fin: [
            [2, 1],
          ],
          cover: [
            [0, 0],
            [1, 0],
          ],
          eliminated: [
            [0, 0],
            [1, 0],
          ],
        ),
        legend: _finnedFishLegend,
      ),
      TechniqueInfo(
        id: 'finned_swordfish',
        name: '带鳍 Swordfish',
        summary: '带鳍的三鱼。',
        definition: '带鳍 Swordfish 是 Swordfish 的带鳍版：三条基本行里有一行多出一个'
            '候选（鳍）。只要鳍和某条覆盖列共享同一个宫，这个宫内、这条覆盖列上的'
            '其它候选就可以删除，逻辑和带鳍 X-Wing 完全一致，只是基本行多了一条。',
        howToSpot: '先按 Swordfish 找三行三列，如果其中一行多出一个候选，'
            '且这个候选和某条覆盖列同宫，就是带鳍 Swordfish。',
        walkthrough: '本例中数字 1 在r6和r7都只能出现在c1,c4,c9，'
            'r3本该也是这三列，却多了一个候选：r3c2，这就是鳍。'
            '鳍和c1同在左上宫，因此左上宫内、c1上的其它候选 1 可以删除：'
            '本例删掉的是r1c1和r2c1的候选 1。',
        caveats: '判断前要先确认三行合并后正好是三列，鳍只是这三列之外多出来的'
            '第四个候选，别把它也算进覆盖列里。',
        rank: 88,
        examplePuzzle:
            '089250467076948032002067580820694375934705826065023940058036790493572608607489253',
        exampleMarkup: _fishMarkup(
          digit: 1,
          rows: [2, 5, 6],
          pattern: [
            [2, 0],
            [2, 3],
            [2, 8],
            [5, 0],
            [5, 3],
            [5, 8],
            [6, 0],
            [6, 3],
            [6, 8],
          ],
          fin: [
            [2, 1],
          ],
          cover: [
            [0, 0],
            [1, 0],
          ],
          eliminated: [
            [0, 0],
            [1, 0],
          ],
        ),
        legend: _finnedFishLegend,
      ),
      TechniqueInfo(
        id: 'finned_jellyfish',
        name: '带鳍 Jellyfish',
        summary: '带鳍的四鱼。',
        definition: '带鳍 Jellyfish 是 Jellyfish 的带鳍版：四条基本行里有一行多出一个'
            '候选（鳍）。只要鳍和某条覆盖列共享同一个宫，这个宫内、这条覆盖列上的'
            '其它候选就可以删除，逻辑和带鳍 X-Wing、带鳍 Swordfish 一致，只是基本行'
            '又多了一条，组合更复杂。',
        howToSpot: '先按 Jellyfish 找四行四列，如果其中一行多出一个候选，'
            '且这个候选和某条覆盖列同宫，就是带鳍 Jellyfish。',
        walkthrough: '本例中数字 1 在r2,r3,r7都只能出现在c1,c4,c5,c7，'
            'r5本该也是这四列，却多了一个候选：r5c2，这就是鳍。'
            '鳍和c1同在左上宫，因此左上宫内、c1上的其它候选 1 可以删除：'
            '本例删掉的是r4c1和r6c1的候选 1。',
        caveats: '带鳍 Jellyfish 组合多、容易漏看，建议先用普通 Jellyfish 的思路'
            '锁定四行四列，再单独检查每行是否多出候选。',
        rank: 90,
        examplePuzzle:
            '389250467076008032042007089020694375004005026065823940058006094493572608607489253',
        exampleMarkup: _fishMarkup(
          digit: 1,
          rows: [1, 2, 4, 6],
          pattern: [
            [4, 0],
            [4, 3],
            [4, 4],
            [4, 6],
            [1, 0],
            [1, 3],
            [1, 4],
            [1, 6],
            [2, 0],
            [2, 3],
            [2, 4],
            [2, 6],
            [6, 0],
            [6, 3],
            [6, 4],
            [6, 6],
          ],
          fin: [
            [4, 1],
          ],
          cover: [
            [3, 0],
            [5, 0],
          ],
          eliminated: [
            [3, 0],
            [5, 0],
          ],
        ),
        legend: _finnedFishLegend,
      ),
      TechniqueInfo(
        id: 'franken_fish',
        name: 'Franken/Mutant Fish',
        summary: '鱼的覆盖单位不限于纯行对纯列，宫也可以当一条线。',
        definition: 'Franken 鱼把普通鱼的基本单位从纯粹的行/列换成了宫：只要某个数字'
            '在一行和一个不相交的宫里的候选合起来恰好只落在两条列上，这一行和这个宫'
            '就能当成两个基本单位——一行必须给这个数字留一个位置，一个宫也必须给它'
            '留一个位置，两个位置刚好落在这两列里，这两列上其它地方的候选就可以删除。',
        howToSpot: '先看某个数字在一行的候选是否只剩两列，再看是否有一个不相交的宫，'
            '其候选恰好也落在同样两列里，两者合起来就是 Franken 鱼。',
        walkthrough: '本例中数字 2 在r8只能出现在c4和c5；中心宫'
            '（r4–r6, c4–c6）里，这个数字的候选恰好也只落在 c4'
            '（r4）和c5（r4,r5）这两处。r8和这个宫合起来'
            '正好把数字 2 锁在 c4、c5 里，因此可以删除 r1c4, r1c5、'
            'r3c4, r3c5、r7c5 的候选 2。',
        caveats: 'Franken 鱼要求行（或列）与宫之间不能有重叠的候选格，'
            '否则同一个候选会被同时算进两个基本单位，逻辑就不成立了。',
        rank: 95,
        examplePuzzle:
            '500000001020600700780005000904001008000908000200500904000300017009006050600000002',
        exampleMarkup: _fishMarkup(
          digit: 2,
          rows: [7],
          pattern: [
            [7, 3],
            [7, 4],
            [3, 3],
            [3, 4],
            [4, 4],
          ],
          cover: [
            [0, 3],
            [0, 4],
          ],
          eliminated: [
            [0, 3],
            [0, 4],
            [2, 3],
            [2, 4],
            [6, 4],
          ],
        ),
        legend: _fishLegend,
      ),
    ];
